"""Disposable PostgreSQL only: simultaneous comment/like and post-author block."""
import subprocess,time,uuid

def sql(command):
    return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],check=True,capture_output=True,text=True).stdout.strip()
def bg(command):return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def wait(query,expected):
    end=time.monotonic()+10
    while time.monotonic()<end:
        if sql(query)==expected:return
        time.sleep(.05)
    raise RuntimeError('Timed out waiting for lock/barrier')
def finish(p,success=True):
    out,err=p.communicate(timeout=15)
    if (p.returncode==0)!=success or (not success and 'Action not permitted' not in err):raise RuntimeError('Unexpected outcome: '+out+' '+err)
def tx(user,action,barrier=None):
    pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
    return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{user}',true); {action}; {pause} COMMIT;"

a,b=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""INSERT INTO auth.users(id) VALUES ('{a}'),('{b}');
INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';
INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES ('{a}','public','members'),('{b}','public','members');
INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES ('{a}','eligible','test','test',now()),('{b}','eligible','test','test',now());
INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;""")
post=sql(tx(a,"SELECT public.create_lga_text_post('Race test')")).splitlines()[-1]
for idx,kind in enumerate(('comment','like')):
    action=(f"SELECT public.create_lga_post_comment('{post}','Race test')" if kind=='comment' else f"SELECT public.set_lga_post_like('{post}',true)")
    table='lga_post_comments' if kind=='comment' else 'lga_post_likes'
    sql(f"DELETE FROM public.{table} WHERE post_id='{post}'")
    barrier=71305000+idx*2
    first=bg(tx(a,f"SELECT public.block_user('{b}')",barrier));second=None
    try:
        wait(f'SELECT pg_try_advisory_lock({barrier})','f')
        second=bg(f"SET application_name='interaction_wait_{idx}'; "+tx(b,action))
        wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='interaction_wait_{idx}' AND wait_event_type='Lock')",'t')
        finish(first);finish(second,False)
        if sql(f"SELECT count(*) FROM public.{table} WHERE post_id='{post}'")!='0':raise AssertionError('Interaction committed after block')
    finally:
        for p in (first,second):
            if p and p.poll() is None:p.kill();p.communicate()
    sql(tx(a,f"SELECT public.unblock_user('{b}')"))
    first=bg(tx(b,action,barrier+1));second=None
    try:
        wait(f'SELECT pg_try_advisory_lock({barrier+1})','f')
        second=bg(f"SET application_name='interaction_block_wait_{idx}'; "+tx(a,f"SELECT public.block_user('{b}')"))
        wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='interaction_block_wait_{idx}' AND wait_event_type='Lock')",'t')
        finish(first);finish(second)
        if sql(f"SELECT count(*) FROM public.{table} WHERE post_id='{post}'")!='1':raise AssertionError('Committed interaction missing')
        check=bg(tx(b,f"SELECT * FROM public.list_lga_post_comments('{post}')"));finish(check,False)
    finally:
        for p in (first,second):
            if p and p.poll() is None:p.kill();p.communicate()
    sql(tx(a,f"SELECT public.unblock_user('{b}')"))
print('PASS: comment/block and like/block lock orderings')
