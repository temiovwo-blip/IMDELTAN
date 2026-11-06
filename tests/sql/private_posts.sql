-- Disposable PostgreSQL integration test. This file creates synthetic data.
-- Execute only against the ephemeral test database, never against production.
DO $test$
DECLARE a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); pending uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id) VALUES (a),(b),(pending);
  INSERT INTO public.profiles(user_id,account_state) VALUES (a,'active'),(b,'active'),(pending,'pending');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
    VALUES (a,'eligible','test','test',now()),(b,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id)
    SELECT users.id,pv.id FROM (VALUES (a),(b)) AS users(id)
      CROSS JOIN public.policy_versions pv
      WHERE pv.mandatory AND pv.published_at <= now() AND pv.retired_at IS NULL;
  PERFORM set_config('test.private_a',a::text,false);
  PERFORM set_config('test.private_b',b::text,false);
  PERFORM set_config('test.private_pending',pending::text,false);
  IF has_function_privilege('anon','public.create_own_private_text_post(text)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous private post creation allowed';
  END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.private_a'),false);
SELECT set_config('test.private_a_post',public.create_own_private_text_post(' A private test ' )::text,false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(id) INTO n FROM public.posts WHERE id=current_setting('test.private_a_post')::uuid AND body='A private test';
  IF n<>1 THEN RAISE EXCEPTION 'Own private post not visible'; END IF;
  BEGIN
    PERFORM public.create_own_private_text_post('  ');
    RAISE EXCEPTION 'Empty post accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    INSERT INTO public.posts(author_id,body,audience) VALUES (current_setting('test.private_a')::uuid,'forged','public');
    RAISE EXCEPTION 'Direct public post insertion allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.private_b'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(id) INTO n FROM public.posts WHERE id=current_setting('test.private_a_post')::uuid;
  IF n<>0 THEN RAISE EXCEPTION 'Private post visible to another user'; END IF;
END $test$;
SELECT set_config('test.private_b_post',public.create_own_private_text_post('B private test')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.private_a'),false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(id) INTO n FROM public.posts WHERE id=current_setting('test.private_b_post')::uuid;
  IF n<>0 THEN RAISE EXCEPTION 'Second private post visible to another user'; END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.private_pending'),false);
DO $test$ BEGIN
  BEGIN
    PERFORM public.create_own_private_text_post('Not yet');
    RAISE EXCEPTION 'Pending user created a post';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
