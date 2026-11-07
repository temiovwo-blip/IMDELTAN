DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(c);INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.edit_a',a::text,false);PERFORM set_config('test.edit_b',b::text,false);PERFORM set_config('test.edit_c',c::text,false);
 IF has_function_privilege('anon','public.edit_own_lga_text_post(uuid,text)','EXECUTE') OR has_function_privilege('anon','public.edit_own_private_group_text_post(uuid,text)','EXECUTE') OR has_table_privilege('authenticated','public.lga_text_posts','UPDATE') THEN RAISE EXCEPTION 'Unsafe edit privileges';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.edit_a'),false);
SELECT set_config('test.edit_lga',public.create_lga_text_post('Original LGA')::text,false);
SELECT set_config('test.edit_group',public.create_group_in_own_lga('Edit group','')::text,false);
SELECT set_config('test.edit_gp',public.create_private_group_text_post(current_setting('test.edit_group')::uuid,'Original group')::text,false);
SELECT public.invite_to_own_group(current_setting('test.edit_group')::uuid,current_setting('test.edit_b')::uuid);
DO $test$ BEGIN
 BEGIN PERFORM public.edit_own_lga_text_post(current_setting('test.edit_lga')::uuid,'  ');RAISE EXCEPTION 'Blank edit accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.edit_own_private_group_text_post(current_setting('test.edit_gp')::uuid,repeat('x',5001));RAISE EXCEPTION 'Long edit accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT public.edit_own_lga_text_post(current_setting('test.edit_lga')::uuid,' Edited LGA ');
SELECT public.edit_own_private_group_text_post(current_setting('test.edit_gp')::uuid,' Edited group ');
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.edit_lga')::uuid AND body='Edited LGA' AND edited_at IS NOT NULL) THEN RAISE EXCEPTION 'LGA edit or marker missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.edit_group')::uuid) WHERE id=current_setting('test.edit_gp')::uuid AND body='Edited group' AND edited_at IS NOT NULL) THEN RAISE EXCEPTION 'Group edit or marker missing';END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.edit_b'),false);
SELECT public.respond_to_group_invitation((SELECT id FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.edit_group')::uuid),true);
SELECT public.save_visible_lga_text_post(current_setting('test.edit_lga')::uuid);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts() WHERE id=current_setting('test.edit_lga')::uuid AND edited_at IS NOT NULL) THEN RAISE EXCEPTION 'Saved edit marker missing';END IF;
 BEGIN PERFORM public.edit_own_lga_text_post(current_setting('test.edit_lga')::uuid,'Other');RAISE EXCEPTION 'Other user edit';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.edit_own_private_group_text_post(current_setting('test.edit_gp')::uuid,'Other');RAISE EXCEPTION 'Other group edit';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.report_lga_text_post(current_setting('test.edit_lga')::uuid,'Concern');
SELECT public.report_private_group_text_post(current_setting('test.edit_gp')::uuid,'Concern');
SELECT set_config('request.jwt.claim.sub',current_setting('test.edit_a'),false);
DO $test$ BEGIN
 BEGIN PERFORM public.edit_own_lga_text_post(current_setting('test.edit_lga')::uuid,'Alter evidence');RAISE EXCEPTION 'Reported LGA post edited';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.edit_own_private_group_text_post(current_setting('test.edit_gp')::uuid,'Alter evidence');RAISE EXCEPTION 'Reported group post edited';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
RESET ROLE;
