"""Disposable DB only: verify message/block ordering with real lock waits."""
import subprocess, time, uuid

def sql(command):
    return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],check=True,capture_output=True,text=True).stdout.strip()
def background(command):
    return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def wait(query,expected,timeout=10):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if sql(query)==expected:return
        time.sleep(.05)
    raise RuntimeError('Timed out waiting for lock/barrier')
def finish(proc,expected_success=True):
    out,err=proc.communicate(timeout=15)
    if (proc.returncode==0)!=expected_success:raise RuntimeError('Unexpected worker outcome: '+err+' '+out)
    if not expected_success and 'Action not permitted' not in err:raise RuntimeError('Unexpected rejection: '+err)
def tx(user,action,barrier=None):
    pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
    return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{user}',true); {action}; {pause} COMMIT;"

a,b=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""INSERT INTO auth.users(id) VALUES ('{a}'),('{b}');
INSERT INTO public.profiles(user_id,account_state) VALUES ('{a}','active'),('{b}','active');
INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES ('{a}','friends','friends'),('{b}','friends','friends');
INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES ('{a}','eligible','test','test',now()),('{b}','eligible','test','test',now());
INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
INSERT INTO public.friendships(user_low,user_high) VALUES (least('{a}'::uuid,'{b}'::uuid),greatest('{a}'::uuid,'{b}'::uuid));""")
cid=sql(tx(a,f"SELECT public.start_friend_conversation('{b}')")).splitlines()[-1]
# Block obtains pair locks first; sender waits then must be denied.
first=background(tx(b,f"SELECT public.block_user('{a}')",71304301));second=None
try:
    wait('SELECT pg_try_advisory_lock(71304301)','f')
    second=background("SET application_name='imdeltan_dm_wait'; "+tx(a,f"SELECT public.send_friend_message('{cid}','blocked first')"))
    wait("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='imdeltan_dm_wait' AND wait_event_type='Lock')",'t')
    finish(first);finish(second,False)
    if sql(f"SELECT count(*) FROM public.messages WHERE conversation_id='{cid}'")!='0':raise AssertionError('Message was sent after a block')
finally:
    for p in (first,second):
        if p and p.poll() is None:p.kill();p.communicate()
# Restore synthetic friendship, send first, then block: previously committed
# message remains stored but subsequent reads must be denied.
sql(tx(b,f"SELECT public.unblock_user('{a}')"))
sql(f"INSERT INTO public.friendships(user_low,user_high) VALUES(least('{a}'::uuid,'{b}'::uuid),greatest('{a}'::uuid,'{b}'::uuid))")
first=background(tx(a,f"SELECT public.send_friend_message('{cid}','sent first')",71304302));second=None
try:
    wait('SELECT pg_try_advisory_lock(71304302)','f')
    second=background("SET application_name='imdeltan_dm_block_wait'; "+tx(b,f"SELECT public.block_user('{a}')"))
    wait("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='imdeltan_dm_block_wait' AND wait_event_type='Lock')",'t')
    finish(first);finish(second)
    if sql(f"SELECT count(*) FROM public.messages WHERE conversation_id='{cid}'")!='1':raise AssertionError('First message unexpectedly lost')
    check=background(tx(a,f"SELECT * FROM public.list_friend_messages('{cid}')"));finish(check,False)
finally:
    for p in (first,second):
        if p and p.poll() is None:p.kill();p.communicate()
print('PASS: both message/block lock orderings')
