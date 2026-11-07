"""Disposable DB: LGA comment edit vs report and block, both orders."""
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
post=sql(tx(a,"SELECT public.create_lga_text_post('Parent')")).splitlines()[-1]
for idx,kind in enumerate(('report','block')):
 for action_first in (True,False):
  cid=sql(tx(b,f"SELECT public.create_lga_post_comment('{post}','Before edit')")).splitlines()[-1]
  edit=f"SELECT public.edit_own_lga_post_comment('{cid}','After edit')"
  action=f"SELECT public.report_lga_post_comment('{cid}','Concern')" if kind=='report' else f"SELECT public.block_user('{b}')"
  action_user=c if kind=='report' else a;barrier=71318000+idx*2+int(action_first)
  if action_first:race(tx(action_user,action,barrier),tx(b,edit),barrier,f'lga_comment_{kind}_before_edit',False)
  else:race(tx(b,edit,barrier),tx(action_user,action),barrier,f'lga_comment_edit_before_{kind}',True)
  expected='Before edit' if action_first else 'After edit'
  if sql(f"SELECT body FROM public.lga_post_comments WHERE id='{cid}'")!=expected:raise AssertionError('Wrong edit/evidence')
  if kind=='report' and sql(f"SELECT count(*) FROM public.user_reports WHERE reported_lga_comment_id='{cid}'")!='1':raise AssertionError('Report lost')
  if kind=='block':sql(tx(a,f"SELECT public.unblock_user('{b}')"))
print('PASS: LGA comment edit vs report and block lock orderings')
