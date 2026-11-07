"""Disposable DB: LGA report vs author deletion in both transaction orders."""
import subprocess,time,uuid

def sql(q):return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],check=True,capture_output=True,text=True).stdout.strip()
def bg(q):return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',q],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def wait(q,want):
 end=time.monotonic()+10
 while time.monotonic()<end:
  if sql(q)==want:return
  time.sleep(.05)
 raise RuntimeError('Timed out waiting for lock')
def finish(p,success=True):
 out,err=p.communicate(timeout=15)
 if (p.returncode==0)!=success or (not success and 'Action not permitted' not in err):raise RuntimeError('Unexpected outcome: '+out+' '+err)
def tx(u,action,barrier=None):
 pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
 return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{u}',true); {action}; {pause} COMMIT;"
def race(first,second,barrier,label,second_success):
 p=bg(first);q=None
 try:
  wait(f'SELECT pg_try_advisory_lock({barrier})','f');q=bg(f"SET application_name='{label}'; "+second);wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')",'t');finish(p);finish(q,second_success)
 finally:
  for x in(p,q):
   if x and x.poll() is None:x.kill();x.communicate()
a,b=(str(uuid.uuid4()) for _ in range(2));sql(f"""INSERT INTO auth.users(id) VALUES('{a}'),('{b}');INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id);INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id);INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;""")
root=sql(tx(a,"SELECT public.create_lga_text_post('Comment parent')")).splitlines()[-1]
for idx,kind in enumerate(('post','comment')):
 for delete_first in (True,False):
  body=f'Evidence {idx} {int(delete_first)}';item=sql(tx(a,f"SELECT public.create_lga_text_post('{body}')" if kind=='post' else f"SELECT public.create_lga_post_comment('{root}','{body}')")).splitlines()[-1]
  delete=f"SELECT public.delete_own_lga_text_post('{item}')" if kind=='post' else f"SELECT public.delete_own_lga_post_comment('{item}')";report=f"SELECT public.report_lga_text_post('{item}','Concern')" if kind=='post' else f"SELECT public.report_lga_post_comment('{item}','Concern')";table='lga_text_posts' if kind=='post' else 'lga_post_comments';column='reported_lga_post_id' if kind=='post' else 'reported_lga_comment_id';barrier=71311000+idx*2+(not delete_first)
  if delete_first:race(tx(a,delete,barrier),tx(b,report),barrier,f'lga_delete_first_{idx}',False)
  else:race(tx(b,report,barrier),tx(a,delete),barrier,f'lga_report_first_{idx}',True)
  if delete_first:
   if sql(f"SELECT body FROM public.{table} WHERE id='{item}'")!='[deleted]':raise AssertionError('Unreported item not redacted')
  elif sql(f"SELECT count(*) FROM public.user_reports r JOIN public.{table} t ON t.id=r.{column} WHERE t.id='{item}' AND t.body='{body}' AND t.status='deleted'")!='1':raise AssertionError('Report evidence lost')
print('PASS: LGA post/comment report-delete lock orderings')
