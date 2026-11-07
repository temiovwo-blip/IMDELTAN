"""Disposable PostgreSQL only: report/block and comment/moderation races."""
import subprocess,time,uuid

def sql(command):return subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-qAt','-c',command],check=True,capture_output=True,text=True).stdout.strip()
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
def tx(user,action,barrier=None,mfa=False):
    pause=f'SELECT pg_advisory_lock({barrier}); SELECT pg_sleep(3);' if barrier else ''
    claims="SELECT set_config('request.jwt.claims','{\"aal\":\"aal2\"}',true);" if mfa else ''
    return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{user}',true); {claims} {action}; {pause} COMMIT;"
def race(first_tx,second_tx,barrier,label,second_success):
    first=bg(first_tx);second=None
    try:
        wait(f'SELECT pg_try_advisory_lock({barrier})','f')
        second=bg(f"SET application_name='{label}'; "+second_tx)
        wait(f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{label}' AND wait_event_type='Lock')",'t')
        finish(first);finish(second,second_success)
    finally:
        for p in (first,second):
            if p and p.poll() is None:p.kill();p.communicate()

a,b,c,m=(str(uuid.uuid4()) for _ in range(4))
sql(f"""INSERT INTO auth.users(id) VALUES ('{a}'),('{b}'),('{c}'),('{m}');
INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{m}'::uuid)) v(id) CROSS JOIN public.lgas l WHERE l.state_name='Delta' AND l.name='Uvwie';
INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES ('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{m}'::uuid)) v(id);
INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES ('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{m}'::uuid)) v(id);
INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES ('{a}'::uuid),('{b}'::uuid),('{c}'::uuid),('{m}'::uuid)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
INSERT INTO public.admin_role_assignments(user_id,role_id) SELECT '{m}',id FROM public.admin_roles WHERE role_key='moderator';""")
post=sql(tx(b,"SELECT public.create_lga_text_post('Race post')")).splitlines()[-1]
comment=sql(tx(b,f"SELECT public.create_lga_post_comment('{post}','Race comment')")).splitlines()[-1]
for idx,kind in enumerate(('post','comment')):
    action=(f"SELECT public.report_lga_text_post('{post}','Concern')" if kind=='post' else f"SELECT public.report_lga_post_comment('{comment}','Concern')")
    target='reported_lga_post_id' if kind=='post' else 'reported_lga_comment_id'; target_id=post if kind=='post' else comment
    barrier=71306000+idx*2
    race(tx(b,f"SELECT public.block_user('{a}')",barrier),tx(a,action),barrier,f'report_block_first_{idx}',False)
    if sql(f"SELECT count(*) FROM public.user_reports WHERE reporter_id='{a}' AND {target}='{target_id}'")!='0':raise AssertionError('Report committed after block')
    sql(tx(b,f"SELECT public.unblock_user('{a}')"))
    race(tx(a,action,barrier+1),tx(b,f"SELECT public.block_user('{a}')"),barrier+1,f'report_first_{idx}',True)
    if sql(f"SELECT count(*) FROM public.user_reports WHERE reporter_id='{a}' AND {target}='{target_id}'")!='1':raise AssertionError('Committed report lost')
    sql(tx(b,f"SELECT public.unblock_user('{a}')"))
# A moderator removes the comment first; a concurrent report must fail.
seed=sql(tx(c,f"SELECT public.report_lga_post_comment('{comment}','Moderator seed')")).splitlines()[-1]
# Use a fresh reporter to avoid duplicate report suppression.
d=str(uuid.uuid4())
sql(f"""INSERT INTO auth.users(id) VALUES ('{d}');INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT '{d}','active',id FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES ('{d}','public','members');INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES ('{d}','eligible','test','test',now());INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT '{d}',id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;""")
race(tx(m,f"SELECT public.remove_reported_lga_post_comment('{seed}','Remove')",71306004,True),tx(d,f"SELECT public.report_lga_post_comment('{comment}','Late report')"),71306004,'comment_remove_first',False)
if sql(f"SELECT count(*) FROM public.user_reports WHERE reporter_id='{d}' AND reported_lga_comment_id='{comment}'")!='0':raise AssertionError('Report after removal')
# New comment: report first, removal second. The second report remains reviewable.
comment2=sql(tx(b,f"SELECT public.create_lga_post_comment('{post}','Race comment two')")).splitlines()[-1]
seed2=sql(tx(c,f"SELECT public.report_lga_post_comment('{comment2}','Moderator seed')")).splitlines()[-1]
race(tx(d,f"SELECT public.report_lga_post_comment('{comment2}','First report')",71306005),tx(m,f"SELECT public.remove_reported_lga_post_comment('{seed2}','Remove')",mfa=True),71306005,'comment_report_first',True)
if sql(f"SELECT count(*) FROM public.user_reports r JOIN public.lga_post_comments c ON c.id=r.reported_lga_comment_id WHERE r.reporter_id='{d}' AND c.id='{comment2}' AND c.status='removed' AND r.status='open'")!='1':raise AssertionError('Pending report not retained')
# Post removal and comment creation must serialize on the post row.
post2=sql(tx(b,"SELECT public.create_lga_text_post('Removal race post')")).splitlines()[-1]
post_report=sql(tx(c,f"SELECT public.report_lga_text_post('{post2}','Seed')")).splitlines()[-1]
race(tx(m,f"SELECT public.remove_reported_lga_text_post('{post_report}','Remove')",71306006,True),tx(a,f"SELECT public.create_lga_post_comment('{post2}','Too late')"),71306006,'post_remove_first',False)
if sql(f"SELECT count(*) FROM public.lga_post_comments WHERE post_id='{post2}'")!='0':raise AssertionError('Comment after post removal')
post3=sql(tx(b,"SELECT public.create_lga_text_post('Second removal race post')")).splitlines()[-1]
post_report2=sql(tx(c,f"SELECT public.report_lga_text_post('{post3}','Seed')")).splitlines()[-1]
race(tx(a,f"SELECT public.create_lga_post_comment('{post3}','First comment')",71306007),tx(m,f"SELECT public.remove_reported_lga_text_post('{post_report2}','Remove')",mfa=True),71306007,'comment_create_first',True)
if sql(f"SELECT count(*) FROM public.lga_post_comments c JOIN public.lga_text_posts p ON p.id=c.post_id WHERE c.post_id='{post3}' AND p.status='removed'")!='1':raise AssertionError('First comment not retained with hidden post')
check=bg(tx(a,f"SELECT * FROM public.list_lga_post_comments('{post3}')"));finish(check,False)
print('PASS: report/block, comment/report-removal and post-removal/comment lock orderings')
