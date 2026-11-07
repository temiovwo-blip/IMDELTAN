-- Synthetic local users: author-only comment editing and report evidence.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT id,'active',l FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT id,'public','members' FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.ge_a',a::text,false);PERFORM set_config('test.ge_b',b::text,false);PERFORM set_config('test.ge_c',c::text,false);PERFORM set_config('test.ge_d',d::text,false);
 IF has_function_privilege('anon','public.edit_own_private_group_post_comment(uuid,text)','EXECUTE') OR has_function_privilege('anon','public.list_private_group_post_comments(uuid,timestamptz,uuid)','EXECUTE') OR NOT has_function_privilege('authenticated','public.edit_own_private_group_post_comment(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Wrong ACL';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.ge_a'),false);
SELECT set_config('test.ge_g',public.create_group_in_own_lga('Comment edit','')::text,false);SELECT set_config('test.ge_p',public.create_private_group_text_post(current_setting('test.ge_g')::uuid,'Parent')::text,false);
RESET ROLE;INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES(current_setting('test.ge_g')::uuid,current_setting('test.ge_b')::uuid,'member','active'),(current_setting('test.ge_g')::uuid,current_setting('test.ge_c')::uuid,'member','active');
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.ge_b'),false);
SELECT set_config('test.ge_comment',public.create_private_group_post_comment(current_setting('test.ge_p')::uuid,'Before')::text,false);
SELECT set_config('test.ge_second',public.create_private_group_post_comment(current_setting('test.ge_p')::uuid,'Another')::text,false);
DO $test$ BEGIN
 BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,'   ');RAISE EXCEPTION 'Blank accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,repeat('x',2001));RAISE EXCEPTION 'Oversize accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,' After ');
 IF NOT EXISTS(SELECT 1 FROM public.list_private_group_post_comments(current_setting('test.ge_p')::uuid) WHERE id=current_setting('test.ge_comment')::uuid AND body='After' AND edited_at IS NOT NULL) THEN RAISE EXCEPTION 'Edit or marker missing';END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ge_c'),false);
DO $test$ BEGIN BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,'Other edit');RAISE EXCEPTION 'Other author edit';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('test.ge_report',public.report_private_group_post_comment(current_setting('test.ge_comment')::uuid,'Concern')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.ge_b'),false);
DO $test$ BEGIN BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,'After report');RAISE EXCEPTION 'Reported edit allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;UPDATE public.user_reports SET status='closed' WHERE id=current_setting('test.ge_report')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.ge_b'),false);
DO $test$ BEGIN BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_comment')::uuid,'After closed report');RAISE EXCEPTION 'Closed report edited';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT public.block_user(current_setting('test.ge_a')::uuid);
DO $test$ BEGIN BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_second')::uuid,'Blocked');RAISE EXCEPTION 'Blocked edit';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT public.unblock_user(current_setting('test.ge_a')::uuid);SELECT public.leave_joined_group(current_setting('test.ge_g')::uuid);
DO $test$ BEGIN BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.ge_second')::uuid,'Left');RAISE EXCEPTION 'Former member edit';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.private_group_post_comments WHERE id=current_setting('test.ge_comment')::uuid AND body='After') THEN RAISE EXCEPTION 'Evidence changed';END IF;END $test$;
