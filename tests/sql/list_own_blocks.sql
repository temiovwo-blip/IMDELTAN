-- Disposable database only; simulated identity and synthetic users.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid(); BEGIN
  INSERT INTO auth.users(id) VALUES(a),(b),(c),(pending);
  INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(c,'active'),(pending,'pending');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
    VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now()),(c,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id)
    SELECT u.id,p.id FROM (VALUES(a),(b),(c)) u(id) CROSS JOIN public.policy_versions p
    WHERE p.mandatory AND p.published_at <= now() AND p.retired_at IS NULL;
  INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(a,b),(b,c);
  PERFORM set_config('test.list_a',a::text,false); PERFORM set_config('test.list_b',b::text,false);
  PERFORM set_config('test.list_c',c::text,false); PERFORM set_config('test.list_pending',pending::text,false);
  IF has_function_privilege('anon','public.list_own_blocks(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous block list access'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.list_a'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.list_own_blocks() WHERE blocked_id=current_setting('test.list_b')::uuid;
  IF n<>1 THEN RAISE EXCEPTION 'Own block missing'; END IF;
  SELECT count(*) INTO n FROM public.list_own_blocks();
  IF n<>1 THEN RAISE EXCEPTION 'Another user block exposed'; END IF;
  SELECT count(*) INTO n FROM public.list_own_blocks(current_setting('test.list_b')::uuid);
  IF n<>0 THEN RAISE EXCEPTION 'Cursor did not exclude previous item'; END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.list_b'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.list_own_blocks() WHERE blocked_id=current_setting('test.list_c')::uuid;
  IF n<>1 THEN RAISE EXCEPTION 'Second user block missing'; END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.list_pending'),false);
DO $test$ BEGIN
  BEGIN PERFORM * FROM public.list_own_blocks(); RAISE EXCEPTION 'Pending user could read blocks';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
-- Exercise the page boundary without inserting real profiles or real identities.
DO $test$ DECLARE target uuid; BEGIN
  FOR i IN 1..55 LOOP
    target:=gen_random_uuid(); INSERT INTO auth.users(id) VALUES(target);
    INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(current_setting('test.list_a')::uuid,target);
  END LOOP;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.list_a'),false);
DO $test$ DECLARE n integer; cursor_id uuid; BEGIN
  SELECT count(*), max(blocked_id::text)::uuid INTO n,cursor_id FROM public.list_own_blocks();
  IF n<>50 THEN RAISE EXCEPTION 'First page size incorrect'; END IF;
  SELECT count(*) INTO n FROM public.list_own_blocks(cursor_id);
  IF n<>6 THEN RAISE EXCEPTION 'Second page incorrect'; END IF;
END $test$;
RESET ROLE;
