-- Disposable PostgreSQL only; synthetic identities and simulated authentication.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid(); missing_lga uuid:=gen_random_uuid(); uvwie uuid; okpe uuid; BEGIN
 SELECT id INTO uvwie FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 SELECT id INTO okpe FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(pending),(missing_lga);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',uvwie),(b,'active',okpe),(pending,'pending',uvwie),(missing_lga,'active',null);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES
   (a,'eligible','test','test',now()),(b,'eligible','test','test',now()),(missing_lga,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES(a),(b),(missing_lga)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.group_a',a::text,false);PERFORM set_config('test.group_b',b::text,false);
 PERFORM set_config('test.group_pending',pending::text,false);PERFORM set_config('test.group_no_lga',missing_lga::text,false);
 IF has_function_privilege('anon','public.create_group_in_own_lga(text,text)','EXECUTE') OR has_function_privilege('anon','public.list_own_created_groups(timestamptz,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous group RPC access'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.group_a'),false);
SELECT set_config('test.group_id',public.create_group_in_own_lga('  Community football  ',' Local matches ')::text,false);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_created_groups() WHERE id=current_setting('test.group_id')::uuid AND name='Community football' AND description='Local matches' AND lga_name='Uvwie';
 IF n<>1 THEN RAISE EXCEPTION 'Owner cannot read own group'; END IF;
 BEGIN PERFORM public.create_group_in_own_lga(' ','test');RAISE EXCEPTION 'Empty group name accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN INSERT INTO public.community_group_memberships(group_id,user_id,role) VALUES(current_setting('test.group_id')::uuid,current_setting('test.group_b')::uuid,'owner');RAISE EXCEPTION 'Direct group insert allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM * FROM public.list_own_created_groups(now(),null);RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.group_b'),false);
DO $test$ DECLARE n int; BEGIN SELECT count(*) INTO n FROM public.list_own_created_groups();IF n<>0 THEN RAISE EXCEPTION 'Private group exposed to other account';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.group_pending'),false);
DO $test$ BEGIN BEGIN PERFORM public.create_group_in_own_lga('Forbidden','');RAISE EXCEPTION 'Pending group creation';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.group_no_lga'),false);
DO $test$ BEGIN BEGIN PERFORM public.create_group_in_own_lga('Forbidden','');RAISE EXCEPTION 'Group creation without LGA';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.community_groups g JOIN public.community_group_memberships m ON m.group_id=g.id
 WHERE g.id=current_setting('test.group_id')::uuid AND g.visibility='private' AND m.user_id=current_setting('test.group_a')::uuid AND m.role='owner' AND m.status='active';
 IF n<>1 THEN RAISE EXCEPTION 'Group owner/private invariant failed';END IF;
END $test$;
