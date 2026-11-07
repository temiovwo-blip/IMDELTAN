"""Disposable PostgreSQL only: report/hide with real transaction lock waits."""
import subprocess,time,uuid

def sql(q):return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],check=True,capture_output=True,text=True).stdout.strip()
def bg(q):return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def wait(q,want):
 end=time.monotonic()+10
 while time.monotonic()<end:
  if sql(q)==want:return
  time.sleep(.05)
 raise RuntimeError('Timeout waiting for lock')
def finish(p):
 out,err=p.communicate(timeout=15)
 if p.returncode:raise RuntimeError('Worker failed: '+out+' '+err)
def tx(user,action,barrier=None):
 pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
 return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{user}',true); {action}; {pause} COMMIT;"
def race(first,second,barrier,label):
 p=bg(first);q=None
 try:
  wait(f'SELECT pg_try_advisory_lock({barrier})','f');q=bg(f"SET application_name='{label}'; "+second)
  wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')",'t');finish(p);finish(q)
 finally:
  for proc in(p,q):
   if proc and proc.poll() is None:proc.kill();proc.communicate()

a,b=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""INSERT INTO auth.users(id) VALUES('{a}'),('{b}');INSERT INTO public.profiles(user_id,account_state) VALUES('{a}','active'),('{b}','active');
INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES('{a}','friends','members'),('{b}','friends','members');
INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES('{a}','eligible','test','test',now()),('{b}','eligible','test','test',now());
INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES('{a}'::uuid),('{b}'::uuid)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
INSERT INTO public.friendships(user_low,user_high) VALUES(least('{a}'::uuid,'{b}'::uuid),greatest('{a}'::uuid,'{b}'::uuid));""")
cid=sql(tx(a,f"SELECT public.start_friend_conversation('{b}')")).splitlines()[-1]
for idx,hide_first in enumerate((True,False)):
 msg=sql(tx(a,f"SELECT public.send_friend_message('{cid}','retained evidence {idx}')")).splitlines()[-1];barrier=71307000+idx
 hide=f"SELECT public.hide_own_friend_message('{msg}')";report=f"SELECT public.report_received_friend_message('{msg}','Concern')"
 if hide_first:race(tx(a,hide,barrier),tx(b,report),barrier,'hide_before_report')
 else:race(tx(b,report,barrier),tx(a,hide),barrier,'report_before_hide')
 if sql(f"SELECT count(*) FROM public.messages m JOIN public.user_reports r ON r.reported_direct_message_id=m.id WHERE m.id='{msg}' AND m.deleted_at IS NOT NULL AND m.body='retained evidence {idx}' AND r.reporter_id='{b}'")!='1':raise AssertionError('Safety evidence lost')
print('PASS: report/hide both lock orderings retain evidence')
