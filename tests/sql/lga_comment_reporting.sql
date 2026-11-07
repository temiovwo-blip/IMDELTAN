-- Simulated accounts and JWTs only; disposable database.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();mod_user uuid:=gen_random_uuid();rid uuid;l uuid;l2 uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO l2 FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(mod_user);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l2),(mod_user,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'public','members'),(mod_user,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(mod_user)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(mod_user)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 SELECT id INTO rid FROM public.admin_roles WHERE role_key='moderator';INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(mod_user,rid);
 PERFORM set_config('test.lgac_a',a::text,false);PERFORM set_config('test.lgac_b',b::text,false);PERFORM set_config('test.lgac_c',c::text,false);PERFORM set_config('test.lgac_mod',mod_user::text,false);
 IF has_function_privilege('anon','public.report_lga_post_comment(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous comment reporting';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_a'),false);
SELECT set_config('test.lgac_post',public.create_lga_text_post('Synthetic post')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_b'),false);
SELECT set_config('test.lgac_comment',public.create_lga_post_comment(current_setting('test.lgac_post')::uuid,'Synthetic comment')::text,false);
DO $test$ BEGIN BEGIN PERFORM public.report_lga_post_comment(current_setting('test.lgac_comment')::uuid,'self');RAISE EXCEPTION 'Self report accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_c'),false);
DO $test$ BEGIN BEGIN PERFORM public.report_lga_post_comment(current_setting('test.lgac_comment')::uuid,'other lga');RAISE EXCEPTION 'Cross-LGA report accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_a'),false);
SELECT set_config('test.lgac_report',public.report_lga_post_comment(current_setting('test.lgac_comment')::uuid,'Synthetic concern')::text,false);
DO $test$ BEGIN
 IF public.report_lga_post_comment(current_setting('test.lgac_comment')::uuid,'duplicate') IS NOT NULL THEN RAISE EXCEPTION 'Duplicate created';END IF;
 BEGIN PERFORM * FROM public.list_lga_comment_reports_for_review();RAISE EXCEPTION 'Non-admin saw reports';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_mod'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',false);
DO $test$ BEGIN BEGIN PERFORM public.remove_reported_lga_post_comment(current_setting('test.lgac_report')::uuid,'reason');RAISE EXCEPTION 'No MFA';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_comment_reports_for_review() WHERE report_id=current_setting('test.lgac_report')::uuid AND comment_body='Synthetic comment') THEN RAISE EXCEPTION 'Comment report missing';END IF;
 IF EXISTS(SELECT 1 FROM public.list_reports_for_review() WHERE id=current_setting('test.lgac_report')::uuid) OR EXISTS(SELECT 1 FROM public.list_lga_post_reports_for_review() WHERE report_id=current_setting('test.lgac_report')::uuid) THEN RAISE EXCEPTION 'Wrong review queue';END IF;
 BEGIN PERFORM public.review_user_report(current_setting('test.lgac_report')::uuid,'closed','wrong queue');RAISE EXCEPTION 'Wrong review action';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.remove_reported_lga_post_comment(current_setting('test.lgac_report')::uuid,'Synthetic moderation decision');
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgac_a'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_post_comments(current_setting('test.lgac_post')::uuid) WHERE id=current_setting('test.lgac_comment')::uuid) THEN RAISE EXCEPTION 'Removed comment visible';END IF;END $test$;
RESET ROLE;
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.moderation_records WHERE report_id=current_setting('test.lgac_report')::uuid AND action='lga_comment_removed') THEN RAISE EXCEPTION 'Missing moderation record';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.audit_logs WHERE action='lga_comment_removed' AND target_id=current_setting('test.lgac_comment')) THEN RAISE EXCEPTION 'Missing audit';END IF;
END $test$;
