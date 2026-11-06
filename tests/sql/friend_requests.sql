-- Disposable PostgreSQL only; synthetic users and simulated claims.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(pending);
 INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(c,'active'),(pending,'pending');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
 VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now()),(c,'eligible','test','test',now());
 INSERT INTO public.user_privacy_settings(user_id,contact_permission) VALUES(a,'members'),(b,'members'),(c,'nobody');
 INSERT INTO public.policy_acceptances(user_id,policy_version_id)
 SELECT u.id,p.id FROM (VALUES(a),(b),(c)) u(id) CROSS JOIN public.policy_versions p
 WHERE p.mandatory AND p.published_at <= now() AND p.retired_at IS NULL;
 PERFORM set_config('test.fr_a',a::text,false); PERFORM set_config('test.fr_b',b::text,false);
 PERFORM set_config('test.fr_c',c::text,false); PERFORM set_config('test.fr_pending',pending::text,false);
 IF has_function_privilege('anon','public.send_friend_request(uuid)','EXECUTE') OR has_function_privilege('anon','public.respond_friend_request(uuid,boolean)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous access'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_a'),false);
SELECT public.send_friend_request(current_setting('test.fr_b')::uuid);
SELECT public.send_friend_request(current_setting('test.fr_b')::uuid);
SELECT public.send_friend_request(current_setting('test.fr_c')::uuid);
RESET ROLE;
DO $test$ DECLARE n integer; r uuid; BEGIN
 SELECT count(*),min(id::text)::uuid INTO n,r FROM public.friend_requests WHERE sender_id=current_setting('test.fr_a')::uuid AND status='pending';
 IF n<>1 THEN RAISE EXCEPTION 'Duplicate request or privacy not enforced'; END IF;
 PERFORM set_config('test.fr_id',r::text,false);
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_c'),false);
DO $test$ BEGIN BEGIN PERFORM public.respond_friend_request(current_setting('test.fr_id')::uuid,true); RAISE EXCEPTION 'Third-party acceptance allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_pending'),false);
DO $test$ BEGIN BEGIN PERFORM public.send_friend_request(current_setting('test.fr_b')::uuid); RAISE EXCEPTION 'Pending account sent request'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_b'),false);
SELECT public.respond_friend_request(current_setting('test.fr_id')::uuid,true);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.friendships WHERE user_low=least(current_setting('test.fr_a')::uuid,current_setting('test.fr_b')::uuid) AND user_high=greatest(current_setting('test.fr_a')::uuid,current_setting('test.fr_b')::uuid)) THEN RAISE EXCEPTION 'Friendship missing'; END IF; END $test$;
SET ROLE authenticated;
SELECT public.block_user(current_setting('test.fr_a')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_a'),false);
SELECT public.send_friend_request(current_setting('test.fr_b')::uuid);
RESET ROLE;
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.friendships WHERE user_low=least(current_setting('test.fr_a')::uuid,current_setting('test.fr_b')::uuid) AND user_high=greatest(current_setting('test.fr_a')::uuid,current_setting('test.fr_b')::uuid)) THEN RAISE EXCEPTION 'Block did not sever friendship'; END IF;
 IF EXISTS(SELECT 1 FROM public.friend_requests WHERE sender_id=current_setting('test.fr_a')::uuid AND recipient_id=current_setting('test.fr_b')::uuid AND status='pending') THEN RAISE EXCEPTION 'Request allowed while blocked'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_b'),false);
SELECT public.unblock_user(current_setting('test.fr_a')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_a'),false);
SELECT public.send_friend_request(current_setting('test.fr_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_b'),false);
SELECT public.block_user(current_setting('test.fr_a')::uuid);
RESET ROLE;
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.friend_requests WHERE sender_id=current_setting('test.fr_a')::uuid AND recipient_id=current_setting('test.fr_b')::uuid AND status='pending') THEN RAISE EXCEPTION 'Block did not cancel pending request'; END IF;
END $test$;
SET ROLE authenticated;
SELECT public.unblock_user(current_setting('test.fr_a')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_a'),false);
SELECT public.send_friend_request(current_setting('test.fr_b')::uuid);
DO $test$ BEGIN
 BEGIN INSERT INTO public.friendships(user_low,user_high) VALUES(least(current_setting('test.fr_a')::uuid,current_setting('test.fr_c')::uuid),greatest(current_setting('test.fr_a')::uuid,current_setting('test.fr_c')::uuid)); RAISE EXCEPTION 'Direct friendship forging allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
UPDATE public.user_privacy_settings SET contact_permission='nobody' WHERE user_id=current_setting('test.fr_b')::uuid;
SELECT set_config('test.fr_newid',(SELECT id::text FROM public.friend_requests WHERE sender_id=current_setting('test.fr_a')::uuid AND recipient_id=current_setting('test.fr_b')::uuid AND status='pending'),false);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fr_b'),false);
DO $test$ BEGIN BEGIN PERFORM public.respond_friend_request(current_setting('test.fr_newid')::uuid,true); RAISE EXCEPTION 'Acceptance ignored changed privacy'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $test$;
SELECT public.respond_friend_request(current_setting('test.fr_newid')::uuid,false);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.friend_requests WHERE id=current_setting('test.fr_newid')::uuid AND status='declined' AND resolved_at IS NOT NULL) THEN RAISE EXCEPTION 'Decline missing'; END IF; END $test$;
