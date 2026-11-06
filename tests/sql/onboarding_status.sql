-- Disposable database only: synthetic users and simulated request identity.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); BEGIN
  INSERT INTO auth.users(id) VALUES(a),(b);
  INSERT INTO public.profiles(user_id,account_state) VALUES(a,'pending'),(b,'suspended');
  INSERT INTO public.user_eligibility(user_id,status) VALUES(a,'pending'),(b,'revoked');
  PERFORM set_config('test.status_a',a::text,false);
  PERFORM set_config('test.status_b',b::text,false);
  IF has_function_privilege('anon','public.get_own_onboarding_status()','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous onboarding status allowed';
  END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.status_a'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.get_own_onboarding_status()
    WHERE account_state='pending' AND eligibility_status='pending' AND NOT policy_complete;
  IF n<>1 THEN RAISE EXCEPTION 'Incorrect first user state'; END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.status_b'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.get_own_onboarding_status()
    WHERE account_state='suspended' AND eligibility_status='revoked' AND NOT policy_complete;
  IF n<>1 THEN RAISE EXCEPTION 'Incorrect second user state'; END IF;
END $test$;
RESET ROLE;
