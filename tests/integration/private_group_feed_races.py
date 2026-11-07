"""Disposable DB: group post vs owner block/archiving or member leave."""
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
 if (p.returncode==0)!=success or (not success and 'Action not permitted' not in err):raise RuntimeError('Unexpected worker outcome: '+out+' '+err)
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
a,b=str(uuid.uuid4()),str(uuid.uuid4());sql(f"""INSERT INTO auth.users(id) VALUES('{a}'),('{b}');INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES('{a}','public','members'),('{b}','public','members');INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES('{a}','eligible','test','test',now()),('{b}','eligible','test','test',now());INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES('{a}'::uuid),('{b}'::uuid)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;""")
for idx,kind in enumerate(('block','archive','leave')):
 for first_is_safety in (True,False):
  group=sql(tx(a,f"SELECT public.create_group_in_own_lga('Race group {idx}','')")).splitlines()[-1]
  # Synthetic membership is equivalent to accepted invitation; test in isolated DB.
  sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{group}','{b}','member','active')")
  post=f"SELECT public.create_private_group_text_post('{group}','Race post')"
  safety=(f"SELECT public.block_user('{b}')" if kind=='block' else f"SELECT public.archive_own_group('{group}')" if kind=='archive' else f"SELECT public.leave_joined_group('{group}')")
  safety_user=b if kind=='leave' else a;barrier=71309000+idx*2+(not first_is_safety)
  if first_is_safety:race(tx(safety_user,safety,barrier),tx(b,post),barrier,f'group_safety_first_{idx}',False)
  else:race(tx(b,post,barrier),tx(safety_user,safety),barrier,f'group_post_first_{idx}',True)
  expected='0' if first_is_safety else '1'
  if sql(f"SELECT count(*) FROM public.private_group_text_posts WHERE group_id='{group}'")!=expected:raise AssertionError('Incorrect group post result')
  check=bg(tx(b,f"SELECT * FROM public.list_private_group_text_posts('{group}')"));finish(check,False)
  if kind=='block':sql(tx(a,f"SELECT public.unblock_user('{b}')"))
print('PASS: private group post vs block, archive and leave lock orderings')
