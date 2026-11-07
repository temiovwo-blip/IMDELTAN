"""Disposable DB: owner removal against member posting, leaving and blocking, both orders."""
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
for idx,kind in enumerate(('post','leave','block')):
 for remove_first in (True,False):
  g=sql(tx(a,"SELECT public.create_group_in_own_lga('Removal race','')")).splitlines()[-1];sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{g}','{b}','member','active')")
  remove=f"SELECT public.remove_own_private_group_member('{g}','{b}')";action=f"SELECT public.create_private_group_text_post('{g}','Before removal')" if kind=='post' else f"SELECT public.leave_joined_group('{g}')" if kind=='leave' else f"SELECT public.block_user('{a}')";barrier=71321000+idx*2+int(remove_first)
  if remove_first:race(tx(a,remove,barrier),tx(b,action),barrier,f'group_remove_before_{kind}',kind=='block')
  else:race(tx(b,action,barrier),tx(a,remove),barrier,f'group_{kind}_before_remove',kind=='post')
  expected='left' if kind=='leave' and not remove_first else 'active' if kind=='block' and not remove_first else 'removed'
  if sql(f"SELECT status FROM public.community_group_memberships WHERE group_id='{g}' AND user_id='{b}'")!=expected:raise AssertionError('Membership status incorrect')
  expected_posts='1' if kind=='post' and not remove_first else '0'
  if sql(f"SELECT count(*) FROM public.private_group_text_posts WHERE group_id='{g}'")!=expected_posts:raise AssertionError('Unexpected post')
  expected_audits='1' if expected=='removed' else '0'
  if sql(f"SELECT count(*) FROM public.audit_logs WHERE actor_id='{a}' AND action='group_owner_member_removed' AND target_id='{g}:{b}'")!=expected_audits:raise AssertionError('Wrong audit result')
  if sql(f"SELECT count(*) FROM app_private.group_member_removal_events e JOIN public.notifications n ON n.reference_id=e.id AND n.recipient_id=e.recipient_id WHERE e.group_id='{g}' AND e.recipient_id='{b}' AND n.event_type='group_membership_removed'")!=expected_audits:raise AssertionError('Wrong removal notice result')
  if kind=='block':sql(tx(b,f"SELECT public.unblock_user('{a}')"))
print('PASS: owner removal vs posting, leave and block both orders')
