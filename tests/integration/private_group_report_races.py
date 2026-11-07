"""Disposable DB: group-post reporting vs author deletion and blocking."""
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
a,b,c=(str(uuid.uuid4()) for _ in range(3));sql(f"""INSERT INTO auth.users(id) VALUES('{a}'),('{b}'),('{c}');INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid)) v(id);INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid)) v(id);INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;""")
group=sql(tx(a,"SELECT public.create_group_in_own_lga('Group report race','')")).splitlines()[-1]
sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{group}','{b}','member','active'),('{group}','{c}','member','active')")
for idx,kind in enumerate(('delete','block')):
 for safety_first in (True,False):
  post=sql(tx(b,f"SELECT public.create_private_group_text_post('{group}','Evidence {idx} {int(safety_first)}')")).splitlines()[-1]
  report=f"SELECT public.report_private_group_text_post('{post}','Concern')";safety=f"SELECT public.delete_own_private_group_text_post('{post}')" if kind=='delete' else f"SELECT public.block_user('{c}')";barrier=71310000+idx*2+(not safety_first)
  if safety_first:race(tx(b,safety,barrier),tx(c,report),barrier,f'group_report_safety_first_{idx}',False)
  else:race(tx(c,report,barrier),tx(b,safety),barrier,f'group_report_first_{idx}',True)
  if safety_first:
   if sql(f"SELECT count(*) FROM public.user_reports WHERE reported_private_group_post_id='{post}'")!='0':raise AssertionError('Report after action')
  else:
   if sql(f"SELECT count(*) FROM public.user_reports r JOIN public.private_group_text_posts t ON t.id=r.reported_private_group_post_id WHERE t.id='{post}' AND t.body='Evidence {idx} {int(safety_first)}'")!='1':raise AssertionError('Report evidence lost')
  if kind=='block':sql(tx(b,f"SELECT public.unblock_user('{c}')"))
print('PASS: group report vs author delete and block lock orderings')
