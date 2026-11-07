"""Two-session group comment safety and moderation ordering tests; disposable DB only."""
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
def tx(u,action,barrier=None,moderator=False):
 pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
 claims="SELECT set_config('request.jwt.claims','{\"aal\":\"aal2\"}',true);" if moderator else ''
 return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{u}',true); {claims} {action}; {pause} COMMIT;"
def race(first,second,barrier,label,second_success):
 p=bg(first);q=None
 try:
  wait(f'SELECT pg_try_advisory_lock({barrier})','f');q=bg(f"SET application_name='{label}'; "+second);wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')",'t');finish(p);finish(q,second_success)
 finally:
  for x in(p,q):
   if x and x.poll() is None:x.kill();x.communicate()
a,b,c,mod=(str(uuid.uuid4()) for _ in range(4));sql(f"""INSERT INTO auth.users(id) VALUES('{a}'),('{b}'),('{c}'),('{mod}');
 INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{mod}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{mod}'::uuid)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{mod}'::uuid)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{mod}'::uuid)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.admin_role_assignments(user_id,role_id) SELECT '{mod}',id FROM public.admin_roles WHERE role_key='moderator';""")
def group():
 g=sql(tx(a,"SELECT public.create_group_in_own_lga('Comment ordering group','')")).splitlines()[-1];sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{g}','{b}','member','active'),('{g}','{c}','member','active')");return g
for idx,kind in enumerate(('leave','archive')):
 for safety_first in (True,False):
  g=group();p=sql(tx(a,f"SELECT public.create_private_group_text_post('{g}','Parent')")).splitlines()[-1];create=f"SELECT public.create_private_group_post_comment('{p}','Before safety')";safety=f"SELECT public.leave_joined_group('{g}')" if kind=='leave' else f"SELECT public.archive_own_group('{g}')";actor=b if kind=='leave' else a;barrier=71316000+idx*2+int(safety_first)
  if safety_first:race(tx(actor,safety,barrier),tx(b,create),barrier,f'gc_{kind}_first',False)
  else:race(tx(b,create,barrier),tx(actor,safety),barrier,f'gc_comment_before_{kind}',True)
  if sql(f"SELECT count(*) FROM public.private_group_post_comments WHERE post_id='{p}'")!=str(int(not safety_first)):raise AssertionError('Invalid comment count')
  finish(bg(tx(b,f"SELECT * FROM public.list_private_group_post_comments('{p}')")),False)
g=group();p=sql(tx(a,f"SELECT public.create_private_group_text_post('{g}','Parent')")).splitlines()[-1]
for idx,kind in enumerate(('delete','report')):
 for mod_first in (True,False):
  body=f'Evidence {kind} {int(mod_first)}';cid=sql(tx(b,f"SELECT public.create_private_group_post_comment('{p}','{body}')")).splitlines()[-1];rid=sql(tx(c,f"SELECT public.report_private_group_post_comment('{cid}','First report')")).splitlines()[-1]
  remove=f"SELECT public.remove_reported_private_group_comment('{rid}','Safety decision')";other=f"SELECT public.delete_own_private_group_post_comment('{cid}')" if kind=='delete' else f"SELECT public.report_private_group_post_comment('{cid}','Second report')";actor=b if kind=='delete' else a;barrier=71316004+idx*2+int(mod_first)
  if mod_first:race(tx(mod,remove,barrier,True),tx(actor,other),barrier,f'gc_moderator_first_{kind}',False)
  else:race(tx(actor,other,barrier),tx(mod,remove,moderator=True),barrier,f'gc_{kind}_before_moderator',kind=='report')
  status='deleted' if kind=='delete' and not mod_first else 'removed';actual=sql(f"SELECT status||'|'||body FROM public.private_group_post_comments WHERE id='{cid}'")
  if actual!=status+'|'+body:raise AssertionError('Status/evidence incorrect: '+actual)
  report_status=sql(f"SELECT status FROM public.user_reports WHERE id='{rid}'");expected='open' if status=='deleted' else 'closed'
  if report_status!=expected:raise AssertionError('Report status incorrect')
  expected_records='0' if status=='deleted' else '1'
  if sql(f"SELECT count(*) FROM public.moderation_records WHERE report_id='{rid}' AND action='private_group_comment_removed'")!=expected_records:raise AssertionError('Moderation audit incorrect')
  if kind=='report' and sql(f"SELECT count(*) FROM public.user_reports WHERE reported_private_group_comment_id='{cid}'")!=('1' if mod_first else '2'):raise AssertionError('Second report incorrect')
print('PASS: comment vs leave/archive and moderation vs report/delete both lock orders')
