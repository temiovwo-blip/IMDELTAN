"""Disposable DB: rejoin acceptance against block and archive, both orders."""
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
for idx,kind in enumerate(('block','archive')):
 for safety_first in (True,False):
  g=sql(tx(a,"SELECT public.create_group_in_own_lga('Rejoin race','')")).splitlines()[-1]
  sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{g}','{b}','member','left')")
  sql(tx(a,f"SELECT public.invite_to_own_group('{g}','{b}')"));invite=sql(f"SELECT id FROM public.community_group_invitations WHERE group_id='{g}' AND invitee_id='{b}' AND status='pending'")
  if not invite:raise AssertionError('No rejoin invitation')
  accept=f"SELECT public.respond_to_group_invitation('{invite}',true)";safety=f"SELECT public.block_user('{b}')" if kind=='block' else f"SELECT public.archive_own_group('{g}')";barrier=71320000+idx*2+int(safety_first)
  if safety_first:race(tx(a,safety,barrier),tx(b,accept),barrier,f'rejoin_{kind}_first',False)
  else:race(tx(b,accept,barrier),tx(a,safety),barrier,f'rejoin_before_{kind}',True)
  expected='left' if safety_first else 'active'
  if sql(f"SELECT status FROM public.community_group_memberships WHERE group_id='{g}' AND user_id='{b}'")!=expected:raise AssertionError('Membership invariant broken')
  finish(bg(tx(b,f"SELECT * FROM public.list_private_group_text_posts('{g}')")),False)
  if kind=='block':sql(tx(a,f"SELECT public.unblock_user('{b}')"))
print('PASS: rejoin acceptance versus block/archive both lock orders')
