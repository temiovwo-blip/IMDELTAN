"""Disposable PostgreSQL only: mark-read versus dismissal, both lock orders."""
import subprocess,time,uuid

def sql(q):return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],check=True,capture_output=True,text=True).stdout.strip()
def bg(q):return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def wait(q,want):
 end=time.monotonic()+10
 while time.monotonic()<end:
  if sql(q)==want:return
  time.sleep(.05)
 raise RuntimeError('Lock wait timed out')
def finish(p,success=True):
 out,err=p.communicate(timeout=15)
 if (p.returncode==0)!=success or (not success and 'Action not permitted' not in err):raise RuntimeError('Worker failed: '+out+' '+err)
def tx(u,action,barrier=None):
 pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
 return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{u}',true); {action}; {pause} COMMIT;"
def race(first,second,barrier,label,second_success):
 p=bg(first);q=None
 try:
  wait(f'SELECT pg_try_advisory_lock({barrier})','f');q=bg(f"SET application_name='{label}'; "+second)
  wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')",'t');finish(p);finish(q,second_success)
 finally:
  for x in(p,q):
   if x and x.poll() is None:x.kill();x.communicate()
user=str(uuid.uuid4());sql(f"""INSERT INTO auth.users(id) VALUES('{user}');INSERT INTO public.profiles(user_id,account_state) VALUES('{user}','active');INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES('{user}','public','members');INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES('{user}','eligible','test','test',now());INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT '{user}',id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;""")
for idx,dismiss_first in enumerate((True,False)):
 notice=sql(f"INSERT INTO public.notifications(recipient_id,event_type,reference_type,reference_id) VALUES('{user}','friend_request_received','friend_request',gen_random_uuid()) RETURNING id").splitlines()[0]
 dismiss=f"SELECT public.dismiss_own_in_app_notification('{notice}')";read=f"SELECT public.mark_own_friend_request_notification_read('{notice}')";barrier=71308000+idx
 if dismiss_first:race(tx(user,dismiss,barrier),tx(user,read),barrier,'dismiss_first',False)
 else:race(tx(user,read,barrier),tx(user,dismiss),barrier,'read_first',True)
 if sql(f"SELECT count(*) FROM public.notifications WHERE id='{notice}'")!='0':raise AssertionError('Dismissal lost')
sql(f"UPDATE public.profiles SET lga_id=(SELECT id FROM public.lgas WHERE state_name='Delta' AND name='Uvwie') WHERE user_id='{user}'")
group=sql(tx(user,"SELECT public.create_group_in_own_lga('Notice race','')")).splitlines()[-1]
for idx,dismiss_first in enumerate((True,False)):
 event=sql(f"INSERT INTO app_private.group_member_removal_events(group_id,recipient_id) VALUES('{group}','{user}') RETURNING id").splitlines()[0]
 notice=sql(f"INSERT INTO public.notifications(recipient_id,event_type,reference_type,reference_id) VALUES('{user}','group_membership_removed','group_member_removal','{event}') RETURNING id").splitlines()[0]
 dismiss=f"SELECT public.dismiss_own_in_app_notification('{notice}')";read=f"SELECT public.mark_own_group_removal_notification_read('{notice}')";barrier=71308010+idx
 if dismiss_first:race(tx(user,dismiss,barrier),tx(user,read),barrier,'removal_notice_dismiss_first',False)
 else:race(tx(user,read,barrier),tx(user,dismiss),barrier,'removal_notice_read_first',True)
 if sql(f"SELECT count(*) FROM public.notifications WHERE id='{notice}'")!='0' or sql(f"SELECT count(*) FROM app_private.group_member_removal_events WHERE id='{event}'")!='1':raise AssertionError('Notice or event state wrong')
print('PASS: friend and group-removal notification read/dismiss lock orderings')
