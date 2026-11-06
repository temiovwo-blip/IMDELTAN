-- Only for the disposable PostgreSQL test database; all identities are synthetic.
DO $test$
DECLARE a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); pending uuid := gen_random_uuid(); absent uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id) VALUES(a),(b),(pending);
  INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(pending,'pending');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
    VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id)
    SELECT u.id,p.id FROM (VALUES(a),(b)) AS u(id) CROSS JOIN public.policy_versions p
    WHERE p.mandatory AND p.published_at <= now() AND p.retired_at IS NULL;
  PERFORM set_config('test.block_a',a::text,false);
  PERFORM set_config('test.block_b',b::text,false);
  PERFORM set_config('test.block_pending',pending::text,false);
  PERFORM set_config('test.block_absent',absent::text,false);
  IF has_function_privilege('anon','public.block_user(uuid)','EXECUTE') OR
     has_function_privilege('anon','public.unblock_user(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous block functions allowed';
  END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.block_a'),false);
SELECT public.block_user(current_setting('test.block_b')::uuid);
SELECT public.block_user(current_setting('test.block_b')::uuid); -- idempotent
SELECT public.block_user(current_setting('test.block_absent')::uuid); -- does not disclose existence
DO $test$ BEGIN
  BEGIN
    PERFORM public.block_user(current_setting('test.block_a')::uuid);
    RAISE EXCEPTION 'Self block allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.user_blocks(blocker_id,blocked_id)
      VALUES(current_setting('test.block_b')::uuid,current_setting('test.block_a')::uuid);
    RAISE EXCEPTION 'Direct forged block allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.block_b'),false);
SELECT public.unblock_user(current_setting('test.block_a')::uuid); -- cannot remove A's block
SELECT set_config('request.jwt.claim.sub',current_setting('test.block_pending'),false);
DO $test$ BEGIN
  BEGIN
    PERFORM public.block_user(current_setting('test.block_a')::uuid);
    RAISE EXCEPTION 'Pending user could block';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.user_blocks
    WHERE blocker_id=current_setting('test.block_a')::uuid AND blocked_id=current_setting('test.block_b')::uuid;
  IF n<>1 THEN RAISE EXCEPTION 'Block missing or changed by another user'; END IF;
  SELECT count(*) INTO n FROM public.user_blocks WHERE blocker_id=current_setting('test.block_a')::uuid;
  IF n<>1 THEN RAISE EXCEPTION 'Duplicate or nonexistent target recorded'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.block_a'),false);
SELECT public.unblock_user(current_setting('test.block_b')::uuid);
SELECT public.unblock_user(current_setting('test.block_b')::uuid); -- idempotent
RESET ROLE;
DO $test$ BEGIN
  IF EXISTS (SELECT 1 FROM public.user_blocks WHERE blocker_id=current_setting('test.block_a')::uuid AND blocked_id=current_setting('test.block_b')::uuid) THEN
    RAISE EXCEPTION 'Own unblock did not remove block';
  END IF;
END $test$;
