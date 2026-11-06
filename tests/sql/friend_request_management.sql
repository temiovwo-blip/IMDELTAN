-- Synthetic accounts and simulated auth, disposable database only.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(c,'active');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
 VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now()),(c,'eligible','test','test',now());
 INSERT INTO public.user_privacy_settings(user_id,contact_permission) VALUES(a,'members'),(b,'members'),(c,'members');
 INSERT INTO public.policy_acceptances(user_id,policy_version_id)
 SELECT u.id,p.id FROM (VALUES(a),(b),(c)) u(id) CROSS JOIN public.policy_versions p
 WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.fm_a',a::text,false); PERFORM set_config('test.fm_b',b::text,false); PERFORM set_config('test.fm_c',c::text,false);
 IF has_function_privilege('anon','public.list_own_friend_requests(timestamptz,uuid)','EXECUTE') OR has_function_privilege('anon','public.cancel_own_friend_request(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous access'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fm_a'),false);
SELECT public.send_friend_request(current_setting('test.fm_b')::uuid);
SELECT set_config('test.fm_id',(SELECT id::text FROM public.list_own_friend_requests() LIMIT 1),false);
DO $test$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM public.list_own_friend_requests(); IF n<>1 THEN RAISE EXCEPTION 'Sender list incorrect'; END IF;
 BEGIN PERFORM * FROM public.list_own_friend_requests(now(),null); RAISE EXCEPTION 'Invalid cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fm_c'),false);
DO $test$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM public.list_own_friend_requests(); IF n<>0 THEN RAISE EXCEPTION 'Other request exposed'; END IF;
 BEGIN PERFORM public.cancel_own_friend_request(current_setting('test.fm_id')::uuid); RAISE EXCEPTION 'Third-party cancellation allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fm_b'),false);
DO $test$ DECLARE n integer; BEGIN SELECT count(*) INTO n FROM public.list_own_friend_requests(); IF n<>1 THEN RAISE EXCEPTION 'Recipient list incorrect'; END IF; END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fm_a'),false);
SELECT public.cancel_own_friend_request(current_setting('test.fm_id')::uuid);
DO $test$ DECLARE n integer; BEGIN SELECT count(*) INTO n FROM public.list_own_friend_requests(); IF n<>0 THEN RAISE EXCEPTION 'Cancelled request visible'; END IF; END $test$;
RESET ROLE;
