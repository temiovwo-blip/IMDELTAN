"""Disposable DB: shared edit cap under cross-feature concurrent edits."""
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
 if (p.returncode==0)!=success or (not success and 'Please try again later' not in err):raise RuntimeError('Unexpected outcome: '+out+' '+err)
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
u=str(uuid.uuid4());sql(f"""INSERT INTO auth.users(id) VALUES('{u}');INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT '{u}','active',id FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES('{u}','public','members');INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES('{u}','eligible','test','test',now());INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT '{u}',id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;""")
lga=sql(tx(u,"SELECT public.create_lga_text_post('Original')")).splitlines()[-1]
group=sql(tx(u,"SELECT public.create_group_in_own_lga('Quota race','')")).splitlines()[-1]
post=sql(tx(u,f"SELECT public.create_private_group_text_post('{group}','Parent')")).splitlines()[-1]
comment=sql(tx(u,f"SELECT public.create_private_group_post_comment('{post}','Original comment')")).splitlines()[-1]
for i,first_post in enumerate((True,False)):
 sql(f"DELETE FROM app_private.content_edit_events WHERE user_id='{u}'; INSERT INTO app_private.content_edit_events(user_id) SELECT '{u}' FROM generate_series(1,19)")
 edit_post=f"SELECT public.edit_own_lga_text_post('{lga}','LGA change {i}')"
 edit_comment=f"SELECT public.edit_own_private_group_post_comment('{comment}','Group change {i}')"
 barrier=71319000+i
 if first_post:race(tx(u,edit_post,barrier),tx(u,edit_comment),barrier,'edit_cap_post_first',False)
 else:race(tx(u,edit_comment,barrier),tx(u,edit_post),barrier,'edit_cap_comment_first',False)
 if sql(f"SELECT count(*) FROM app_private.content_edit_events WHERE user_id='{u}'")!='20':raise AssertionError('Shared cap failed')
 expected_post='LGA change 0';expected_comment='Original comment' if first_post else 'Group change 1'
 if sql(f"SELECT body FROM public.lga_text_posts WHERE id='{lga}'")!=expected_post or sql(f"SELECT body FROM public.private_group_post_comments WHERE id='{comment}'")!=expected_comment:raise AssertionError('Incorrect race result')
print('PASS: shared edit rate cap across two sessions and content types')
