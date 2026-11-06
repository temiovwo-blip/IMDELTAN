-- Disposable database only: synthetic identities and simulated auth.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); suspended uuid:=gen_random_uuid(); n int; BEGIN
 SELECT count(*) INTO n FROM public.lga_communities c JOIN public.lgas l ON l.id=c.lga_id WHERE l.state_name='Delta'; IF n<>25 THEN RAISE EXCEPTION 'Expected 25 Delta communities'; END IF;
 INSERT INTO auth.users(id) VALUES(a),(b),(suspended);
 INSERT INTO public.profiles(user_id,account_state) VALUES(a,'pending'),(b,'pending'),(suspended,'suspended');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(a,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT a,id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;
 PERFORM set_config('test.lga_a',a::text,false); PERFORM set_config('test.lga_b',b::text,false); PERFORM set_config('test.lga_suspended',suspended::text,false);
 IF has_function_privilege('anon','public.list_delta_lgas()','EXECUTE') OR has_function_privilege('anon','public.set_own_lga(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous LGA RPC allowed'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_a'),false);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_delta_lgas(); IF n<>25 THEN RAISE EXCEPTION 'LGA list wrong'; END IF;
 SELECT count(*) INTO n FROM public.get_own_lga(); IF n<>0 THEN RAISE EXCEPTION 'Unexpected LGA'; END IF;
 BEGIN PERFORM public.complete_own_onboarding(); RAISE EXCEPTION 'Activation without LGA allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.set_own_lga(gen_random_uuid()); RAISE EXCEPTION 'Invalid LGA allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN INSERT INTO public.community_groups(lga_id,created_by,name) SELECT id,current_setting('test.lga_a')::uuid,'Forged' FROM public.list_delta_lgas() LIMIT 1; RAISE EXCEPTION 'Direct group insert allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT public.set_own_lga((SELECT id FROM public.list_delta_lgas() WHERE name='Uvwie'));
DO $test$ DECLARE n int; BEGIN SELECT count(*) INTO n FROM public.get_own_lga() WHERE name='Uvwie'; IF n<>1 THEN RAISE EXCEPTION 'Own LGA not saved'; END IF; END $test$;
SELECT public.complete_own_onboarding();
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_b'),false);
DO $test$ DECLARE n int; BEGIN SELECT count(*) INTO n FROM public.get_own_lga(); IF n<>0 THEN RAISE EXCEPTION 'Another LGA exposed'; END IF; END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_suspended'),false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_delta_lgas(); RAISE EXCEPTION 'Suspended list allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $test$;
RESET ROLE;
