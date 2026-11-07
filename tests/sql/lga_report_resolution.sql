-- Disposable PostgreSQL, synthetic identities and JWT claims only.
DO $test$ DECLARE author uuid:=gen_random_uuid();a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();mod_user uuid:=gen_random_uuid();rid uuid;l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(author),(a),(b),(mod_user);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(author,'active',l),(a,'active',l),(b,'active',l),(mod_user,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(author,'public','members'),(a,'public','members'),(b,'public','members'),(mod_user,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(author),(a),(b),(mod_user)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(author),(a),(b),(mod_user)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 SELECT id INTO rid FROM public.admin_roles WHERE role_key='moderator';INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(mod_user,rid);
 PERFORM set_config('test.resolve_author',author::text,false);PERFORM set_config('test.resolve_a',a::text,false);PERFORM set_config('test.resolve_b',b::text,false);PERFORM set_config('test.resolve_mod',mod_user::text,false);
 IF has_function_privilege('anon','public.review_lga_content_report(uuid,text,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous review';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.resolve_author'),false);
SELECT set_config('test.resolve_post',public.create_lga_text_post('Synthetic post')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.resolve_a'),false);
SELECT set_config('test.resolve_r1',public.report_lga_text_post(current_setting('test.resolve_post')::uuid,'First concern')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.resolve_b'),false);
SELECT set_config('test.resolve_r2',public.report_lga_text_post(current_setting('test.resolve_post')::uuid,'Second concern')::text,false);
DO $test$ BEGIN BEGIN PERFORM public.review_lga_content_report(current_setting('test.resolve_r2')::uuid,'closed','not moderator');RAISE EXCEPTION 'Unauthorized review';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.resolve_mod'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',false);
DO $test$ BEGIN BEGIN PERFORM public.review_lga_content_report(current_setting('test.resolve_r2')::uuid,'closed','without MFA');RAISE EXCEPTION 'Review without MFA';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
SELECT public.remove_reported_lga_text_post(current_setting('test.resolve_r1')::uuid,'First decision');
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_lga_post_reports_for_review() WHERE report_id=current_setting('test.resolve_r2')::uuid AND post_status='removed') THEN RAISE EXCEPTION 'Second report unavailable';END IF;END $test$;
SELECT public.review_lga_content_report(current_setting('test.resolve_r2')::uuid,'reviewing','Review in progress');
SELECT public.review_lga_content_report(current_setting('test.resolve_r2')::uuid,'closed','Already removed');
DO $test$ BEGIN BEGIN PERFORM public.review_lga_content_report(current_setting('test.resolve_r2')::uuid,'closed','again');RAISE EXCEPTION 'Closed report changed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
DO $test$ BEGIN
 IF (SELECT count(*) FROM public.moderation_records WHERE report_id=current_setting('test.resolve_r2')::uuid AND action IN ('lga_report_reviewing','lga_report_closed'))<>2 THEN RAISE EXCEPTION 'Review records missing';END IF;
 IF (SELECT count(*) FROM public.audit_logs WHERE target_type='user_report' AND target_id=current_setting('test.resolve_r2') AND action IN ('lga_report_reviewing','lga_report_closed'))<>2 THEN RAISE EXCEPTION 'Audit records missing';END IF;
END $test$;
