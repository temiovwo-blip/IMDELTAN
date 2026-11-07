DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();m uuid:=gen_random_uuid();l uuid;rid uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(m);
 INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT v.id,'active',l FROM (VALUES(a),(b),(m)) v(id);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(m)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(m)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(m)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 SELECT id INTO rid FROM public.admin_roles WHERE role_key='moderator';INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(m,rid);
 PERFORM set_config('test.le_a',a::text,false);PERFORM set_config('test.le_b',b::text,false);PERFORM set_config('test.le_m',m::text,false);
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.le_a'),false);
SELECT set_config('test.le_post',public.create_lga_text_post('Reported post evidence')::text,false);
SELECT set_config('test.le_plain',public.create_lga_text_post('Unreported post')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.le_b'),false);
SELECT set_config('test.le_postreport',public.report_lga_text_post(current_setting('test.le_post')::uuid,'Concern')::text,false);
SELECT set_config('test.le_comment',public.create_lga_post_comment(current_setting('test.le_post')::uuid,'Reported comment evidence')::text,false);
SELECT set_config('test.le_plaincomment',public.create_lga_post_comment(current_setting('test.le_post')::uuid,'Unreported comment')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.le_a'),false);
SELECT set_config('test.le_commentreport',public.report_lga_post_comment(current_setting('test.le_comment')::uuid,'Concern')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.le_b'),false);
SELECT public.delete_own_lga_post_comment(current_setting('test.le_comment')::uuid);
SELECT public.delete_own_lga_post_comment(current_setting('test.le_plaincomment')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.le_a'),false);
SELECT public.delete_own_lga_text_post(current_setting('test.le_post')::uuid);
SELECT public.delete_own_lga_text_post(current_setting('test.le_plain')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.le_post')::uuid) THEN RAISE EXCEPTION 'Deleted post visible';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.le_m'),false);SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_post_reports_for_review() WHERE report_id=current_setting('test.le_postreport')::uuid AND post_body='Reported post evidence' AND post_status='deleted') THEN RAISE EXCEPTION 'Post evidence missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_comment_reports_for_review() WHERE report_id=current_setting('test.le_commentreport')::uuid AND comment_body='Reported comment evidence' AND comment_status='deleted') THEN RAISE EXCEPTION 'Comment evidence missing';END IF;
END $test$;
RESET ROLE;
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.lga_text_posts WHERE id=current_setting('test.le_plain')::uuid AND body='[deleted]' AND status='deleted') THEN RAISE EXCEPTION 'Unreported post not redacted';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lga_post_comments WHERE id=current_setting('test.le_plaincomment')::uuid AND body='[deleted]' AND status='deleted') THEN RAISE EXCEPTION 'Unreported comment not redacted';END IF;
END $test$;
