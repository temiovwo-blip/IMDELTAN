"""Disposable DB: group comment vs block; report vs delete, both orders."""
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
group=sql(tx(a,"SELECT public.create_group_in_own_lga('Comment race','')")).splitlines()[-1];sql(f"INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES('{group}','{b}','member','active')")
post=sql(tx(a,f"SELECT public.create_private_group_text_post('{group}','Post')")).splitlines()[-1];comment=f"SELECT public.create_private_group_post_comment('{post}','Created before block')"
race(tx(a,f"SELECT public.block_user('{b}')",71315000),tx(b,comment),71315000,'group_comment_block_first',False)
if sql(f"SELECT count(*) FROM public.private_group_post_comments WHERE post_id='{post}'")!='0':raise AssertionError('Comment after block')
sql(tx(a,f"SELECT public.unblock_user('{b}')"))
race(tx(b,comment,71315001),tx(a,f"SELECT public.block_user('{b}')"),71315001,'group_comment_first',True)
if sql(f"SELECT count(*) FROM public.private_group_post_comments WHERE post_id='{post}'")!='1':raise AssertionError('Committed comment lost')
sql(tx(a,f"SELECT public.unblock_user('{b}')"))
for idx,delete_first in enumerate((True,False)):
 cid=sql(tx(b,f"SELECT public.create_private_group_post_comment('{post}','Evidence {idx}')")).splitlines()[-1];delete=f"SELECT public.delete_own_private_group_post_comment('{cid}')";report=f"SELECT public.report_private_group_post_comment('{cid}','Concern')";barrier=71315002+idx
 if delete_first:race(tx(b,delete,barrier),tx(a,report),barrier,'group_comment_delete_first',False);expected='[deleted]'
 else:race(tx(a,report,barrier),tx(b,delete),barrier,'group_comment_report_first',True);expected=f'Evidence {idx}'
 if sql(f"SELECT body FROM public.private_group_post_comments WHERE id='{cid}'")!=expected:raise AssertionError('Incorrect safety evidence')
print('PASS: group comment/block and report/delete lock orderings')
