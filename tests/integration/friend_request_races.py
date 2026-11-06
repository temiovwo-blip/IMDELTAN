"""Run only against the isolated test DB. Simulates overlapping block/request transactions.

Two real DB sessions contend on ordered profile locks. PostgreSQL advisory locks
are used only as a test barrier; they do not control the application behavior.
"""
import subprocess
import time
import uuid


def sql(command):
    return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],
                          check=True,capture_output=True,text=True).stdout.strip()


def background(command):
    return subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],
                            stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)


def wait_for_barrier(key):
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        if sql(f'SELECT pg_try_advisory_lock({key})')=='f':
            return
        time.sleep(0.05)
    raise RuntimeError('Timed out waiting for transaction test barrier')


def wait_for_lock(label):
    deadline=time.monotonic()+3
    while time.monotonic()<deadline:
        if sql(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')")=='t':
            return
        time.sleep(0.05)
    raise RuntimeError('Second session did not visibly wait on a database lock')


def finish(process):
    out,err=process.communicate(timeout=15)
    if process.returncode:
        raise RuntimeError(f'Database worker failed: {err}\n{out}')


a,b=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""
INSERT INTO auth.users(id) VALUES ('{a}'),('{b}');
INSERT INTO public.profiles(user_id,account_state) VALUES ('{a}','active'),('{b}','active');
INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
  VALUES ('{a}','eligible','test','test',now()),('{b}','eligible','test','test',now());
INSERT INTO public.user_privacy_settings(user_id,contact_permission) VALUES ('{a}','members'),('{b}','members');
INSERT INTO public.policy_acceptances(user_id,policy_version_id)
  SELECT u.id,p.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid)) u(id)
  CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
""")


def tx(user, action, barrier=None):
    suffix=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(4);' if barrier else ''
    return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{user}',true); {action}; {suffix} COMMIT;"


def check_block_and_no_pending():
    result=sql(f"SELECT (EXISTS(SELECT 1 FROM public.user_blocks WHERE blocker_id='{b}' AND blocked_id='{a}'))::int || ':' || (SELECT count(*) FROM public.friend_requests WHERE status='pending' AND ((sender_id='{a}' AND recipient_id='{b}') OR (sender_id='{b}' AND recipient_id='{a}')))::text;")
    if result!='1:0': raise AssertionError('Block and pending request invariant failed: '+result)

# A block holds both profile locks; the concurrent request must wait and do nothing.
first=background(tx(b,f"SELECT public.block_user('{a}')",71304201))
try:
    wait_for_barrier(71304201)
    second=background("SET application_name='imdeltan_request_wait'; "+tx(a,f"SELECT public.send_friend_request('{b}')"))
    wait_for_lock('imdeltan_request_wait')
    finish(first);finish(second);check_block_and_no_pending()
finally:
    if first.poll() is None: first.kill();first.communicate()

# A request holds the locks first; the later block must cancel the request.
sql(tx(b,f"SELECT public.unblock_user('{a}')"))
first=background(tx(a,f"SELECT public.send_friend_request('{b}')",71304202))
try:
    wait_for_barrier(71304202)
    second=background("SET application_name='imdeltan_block_wait'; "+tx(b,f"SELECT public.block_user('{a}')"))
    wait_for_lock('imdeltan_block_wait')
    finish(first);finish(second);check_block_and_no_pending()
finally:
    if first.poll() is None: first.kill();first.communicate()

print('PASS: both block/request transaction orderings preserve the invariant')
