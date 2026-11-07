DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();m uuid:=gen_random_uuid();rid uuid; BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(m);
 INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(c,'active'),(m,'active');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'friends','members' FROM (VALUES(a),(b),(c),(m)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(m)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(m)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.friendships(user_low,user_high) VALUES(least(a,b),greatest(a,b));SELECT id INTO rid FROM public.admin_roles WHERE role_key='moderator';INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(m,rid);
 PERFORM set_config('test.dmr_a',a::text,false);PERFORM set_config('test.dmr_b',b::text,false);PERFORM set_config('test.dmr_c',c::text,false);PERFORM set_config('test.dmr_m',m::text,false);
 IF has_function_privilege('anon','public.list_direct_message_reports_for_review()','EXECUTE') THEN RAISE EXCEPTION 'Anonymous moderation access';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dmr_a'),false);
SELECT set_config('test.dmr_conversation',public.start_friend_conversation(current_setting('test.dmr_b')::uuid)::text,false);
SELECT set_config('test.dmr_message',public.send_friend_message(current_setting('test.dmr_conversation')::uuid,'Reported synthetic message')::text,false);
SELECT public.send_friend_message(current_setting('test.dmr_conversation')::uuid,'Unreported private context');
DO $test$ BEGIN BEGIN PERFORM public.report_received_friend_message(current_setting('test.dmr_message')::uuid,'own');RAISE EXCEPTION 'Self report accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dmr_c'),false);
DO $test$ BEGIN BEGIN PERFORM public.report_received_friend_message(current_setting('test.dmr_message')::uuid,'not participant');RAISE EXCEPTION 'Nonparticipant report';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dmr_b'),false);
-- Reporting remains available after a safety block severs the friendship.
SELECT public.block_user(current_setting('test.dmr_a')::uuid);
SELECT set_config('test.dmr_report',public.report_received_friend_message(current_setting('test.dmr_message')::uuid,'Concern')::text,false);
DO $test$ BEGIN
 IF public.report_received_friend_message(current_setting('test.dmr_message')::uuid,'duplicate') IS NOT NULL THEN RAISE EXCEPTION 'Duplicate report';END IF;
 BEGIN PERFORM * FROM public.list_direct_message_reports_for_review();RAISE EXCEPTION 'Ordinary user saw reports';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dmr_m'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_direct_message_reports_for_review();RAISE EXCEPTION 'No MFA access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_direct_message_reports_for_review() WHERE report_id=current_setting('test.dmr_report')::uuid AND message_body='Reported synthetic message') THEN RAISE EXCEPTION 'Reported message absent';END IF;
 IF EXISTS(SELECT 1 FROM public.list_direct_message_reports_for_review() WHERE message_body='Unreported private context') THEN RAISE EXCEPTION 'Unreported message exposed';END IF;
 IF EXISTS(SELECT 1 FROM public.list_reports_for_review() WHERE id=current_setting('test.dmr_report')::uuid) THEN RAISE EXCEPTION 'Wrong queue';END IF;
 BEGIN PERFORM public.review_user_report(current_setting('test.dmr_report')::uuid,'closed','wrong queue');RAISE EXCEPTION 'Wrong action';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.review_direct_message_report(current_setting('test.dmr_report')::uuid,'reviewing','Review started');
SELECT public.review_direct_message_report(current_setting('test.dmr_report')::uuid,'closed','Review finished');
RESET ROLE;
DO $test$ BEGIN
 IF (SELECT count(*) FROM public.moderation_records WHERE report_id=current_setting('test.dmr_report')::uuid AND action IN ('direct_message_report_reviewing','direct_message_report_closed'))<>2 THEN RAISE EXCEPTION 'Moderation record missing';END IF;
END $test$;
