-- Disposable test database only; synthetic identities and simulated auth.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();pending uuid:=gen_random_uuid();l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(a),(b),(pending);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(pending,'pending',l);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES(a),(b)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.gmanage_a',a::text,false);PERFORM set_config('test.gmanage_b',b::text,false);PERFORM set_config('test.gmanage_pending',pending::text,false);
 IF has_function_privilege('anon','public.update_own_group(uuid,text,text)','EXECUTE') OR has_function_privilege('anon','public.archive_own_group(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous group management allowed';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gmanage_a'),false);
SELECT set_config('test.gmanage_id',public.create_group_in_own_lga('Original','Start')::text,false);
SELECT public.update_own_group(current_setting('test.gmanage_id')::uuid,'  New name  ','  Changed  ');
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_created_groups() WHERE id=current_setting('test.gmanage_id')::uuid AND name='New name' AND description='Changed';IF n<>1 THEN RAISE EXCEPTION 'Group update failed';END IF;
 BEGIN PERFORM public.update_own_group(current_setting('test.gmanage_id')::uuid,' ','a');RAISE EXCEPTION 'Empty name accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN UPDATE public.community_groups SET name='Forged' WHERE id=current_setting('test.gmanage_id')::uuid;RAISE EXCEPTION 'Direct update allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gmanage_b'),false);
DO $test$ BEGIN
 BEGIN PERFORM public.update_own_group(current_setting('test.gmanage_id')::uuid,'Forged','');RAISE EXCEPTION 'Other owner edit allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.archive_own_group(current_setting('test.gmanage_id')::uuid);RAISE EXCEPTION 'Other owner archive allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gmanage_pending'),false);
DO $test$ BEGIN BEGIN PERFORM public.archive_own_group(current_setting('test.gmanage_id')::uuid);RAISE EXCEPTION 'Pending account archived group';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gmanage_a'),false);
SELECT public.archive_own_group(current_setting('test.gmanage_id')::uuid);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_created_groups() WHERE id=current_setting('test.gmanage_id')::uuid;IF n<>0 THEN RAISE EXCEPTION 'Archived group visible';END IF;
 BEGIN PERFORM public.update_own_group(current_setting('test.gmanage_id')::uuid,'Changed','');RAISE EXCEPTION 'Archived group editable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.community_groups WHERE id=current_setting('test.gmanage_id')::uuid AND status='archived' AND name='New name') THEN RAISE EXCEPTION 'Archive did not retain group';END IF;END $test$;
