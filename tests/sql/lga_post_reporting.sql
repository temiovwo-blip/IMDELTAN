-- Synthetic accounts and JWTs; disposable database only.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); mod_user uuid:=gen_random_uuid(); rid uuid; l uuid; l2 uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie'; SELECT id INTO l2 FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(mod_user);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l2),(mod_user,'active',l);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(mod_user)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(mod_user)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 SELECT id INTO rid FROM public.admin_roles WHERE role_key='moderator';
 INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(mod_user,rid);
 PERFORM set_config('test.lga_report_author',a::text,false);PERFORM set_config('test.lga_report_reporter',b::text,false);PERFORM set_config('test.lga_report_other',c::text,false);PERFORM set_config('test.lga_report_mod',mod_user::text,false);
 IF has_function_privilege('anon','public.report_lga_text_post(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous report access';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_report_author'),false);
SELECT set_config('test.lga_report_post',public.create_lga_text_post('Synthetic post for review')::text,false);
DO $test$ BEGIN BEGIN PERFORM public.report_lga_text_post(current_setting('test.lga_report_post')::uuid,'self'); RAISE EXCEPTION 'Self report accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_report_other'),false);
DO $test$ BEGIN BEGIN PERFORM public.report_lga_text_post(current_setting('test.lga_report_post')::uuid,'other lga');RAISE EXCEPTION 'Cross LGA report accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_report_reporter'),false);
SELECT set_config('test.lga_report_id',public.report_lga_text_post(current_setting('test.lga_report_post')::uuid,'Synthetic concern')::text,false);
DO $test$ BEGIN
 IF public.report_lga_text_post(current_setting('test.lga_report_post')::uuid,'duplicate') IS NOT NULL THEN RAISE EXCEPTION 'Duplicate created';END IF;
 BEGIN PERFORM * FROM public.list_lga_post_reports_for_review();RAISE EXCEPTION 'Non-admin saw reports';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_report_mod'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',false);
DO $test$ BEGIN BEGIN PERFORM public.remove_reported_lga_text_post(current_setting('test.lga_report_id')::uuid,'reviewed');RAISE EXCEPTION 'No MFA removal';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_post_reports_for_review() WHERE report_id=current_setting('test.lga_report_id')::uuid AND post_body='Synthetic post for review') THEN RAISE EXCEPTION 'Report absent';END IF;
 IF EXISTS(SELECT 1 FROM public.list_reports_for_review() WHERE id=current_setting('test.lga_report_id')::uuid) THEN RAISE EXCEPTION 'Post report in user queue';END IF;
 BEGIN PERFORM public.review_user_report(current_setting('test.lga_report_id')::uuid,'closed','wrong queue');RAISE EXCEPTION 'Old user review can close LGA report';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.remove_reported_lga_text_post(current_setting('test.lga_report_id')::uuid,'Violates test rule');
SELECT set_config('request.jwt.claim.sub',current_setting('test.lga_report_reporter'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.lga_report_post')::uuid) THEN RAISE EXCEPTION 'Removed post still visible';END IF;END $test$;
RESET ROLE;
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.moderation_records WHERE report_id=current_setting('test.lga_report_id')::uuid AND action='lga_post_removed') THEN RAISE EXCEPTION 'Missing moderation record';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.audit_logs WHERE action='lga_post_removed' AND target_id=current_setting('test.lga_report_post')) THEN RAISE EXCEPTION 'Missing audit record';END IF;
END $test$;
