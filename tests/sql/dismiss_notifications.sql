DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(a),(b),(c);INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.friendships(user_low,user_high) VALUES(least(a,b),greatest(a,b));
 PERFORM set_config('test.dismiss_a',a::text,false);PERFORM set_config('test.dismiss_b',b::text,false);PERFORM set_config('test.dismiss_c',c::text,false);
 IF has_function_privilege('anon','public.dismiss_own_in_app_notification(uuid)','EXECUTE') OR has_table_privilege('authenticated','public.notifications','DELETE') THEN RAISE EXCEPTION 'Unsafe notification deletion privileges';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.dismiss_a'),false);
SELECT set_config('test.dismiss_group',public.create_group_in_own_lga('Test group','')::text,false);
SELECT public.invite_to_own_group(current_setting('test.dismiss_group')::uuid,current_setting('test.dismiss_b')::uuid);
SELECT set_config('test.dismiss_thread',public.start_friend_conversation(current_setting('test.dismiss_b')::uuid)::text,false);
SELECT set_config('test.dismiss_msg',public.send_friend_message(current_setting('test.dismiss_thread')::uuid,'Test message')::text,false);
-- C is not a friend, so an ordinary request creates the third notice type.
SELECT public.send_friend_request(current_setting('test.dismiss_c')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.dismiss_b'),false);
SELECT set_config('test.dismiss_gnotice',(SELECT id::text FROM public.list_own_group_invitation_notifications()),false);
SELECT set_config('test.dismiss_mnotice',(SELECT id::text FROM public.list_own_direct_message_notifications()),false);
DO $test$ BEGIN
 BEGIN PERFORM public.dismiss_own_in_app_notification(null);RAISE EXCEPTION 'Null accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_gnotice')::uuid);
 PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_mnotice')::uuid);
 IF EXISTS(SELECT 1 FROM public.list_own_group_invitation_notifications()) OR EXISTS(SELECT 1 FROM public.list_own_direct_message_notifications()) THEN RAISE EXCEPTION 'Dismissed notice visible';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.dismiss_group')::uuid) OR NOT EXISTS(SELECT 1 FROM public.list_friend_messages(current_setting('test.dismiss_thread')::uuid) WHERE id=current_setting('test.dismiss_msg')::uuid) THEN RAISE EXCEPTION 'Underlying item removed';END IF;
 BEGIN PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_mnotice')::uuid);RAISE EXCEPTION 'Repeated dismissal accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dismiss_c'),false);
SELECT set_config('test.dismiss_fnotice',(SELECT id::text FROM public.list_own_friend_request_notifications()),false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.dismiss_b'),false);
DO $test$ BEGIN BEGIN PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_fnotice')::uuid);RAISE EXCEPTION 'Other recipient dismissal';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dismiss_c'),false);
SELECT public.dismiss_own_in_app_notification(current_setting('test.dismiss_fnotice')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_friend_request_notifications()) OR NOT EXISTS(SELECT 1 FROM public.list_own_friend_requests_display() WHERE direction='received') THEN RAISE EXCEPTION 'Request lost or notice remains';END IF;END $test$;
RESET ROLE;
-- Gate denies suspension even for a notification that still exists.
INSERT INTO public.notifications(recipient_id,event_type,reference_type,reference_id) VALUES(current_setting('test.dismiss_c')::uuid,'unrelated','opaque',gen_random_uuid());
SELECT set_config('test.dismiss_other',(SELECT id::text FROM public.notifications WHERE recipient_id=current_setting('test.dismiss_c')::uuid AND event_type='unrelated'),false);
SET ROLE authenticated;
DO $test$ BEGIN BEGIN PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_other')::uuid);RAISE EXCEPTION 'Unknown type dismissed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
INSERT INTO public.notifications(recipient_id,event_type,reference_type,reference_id) VALUES(current_setting('test.dismiss_c')::uuid,'friend_request_received','friend_request',gen_random_uuid());
SELECT set_config('test.dismiss_suspended',(SELECT id::text FROM public.notifications WHERE recipient_id=current_setting('test.dismiss_c')::uuid AND event_type='friend_request_received' ORDER BY created_at DESC LIMIT 1),false);
UPDATE public.profiles SET account_state='suspended' WHERE user_id=current_setting('test.dismiss_c')::uuid;
SET ROLE authenticated;
DO $test$ BEGIN BEGIN PERFORM public.dismiss_own_in_app_notification(current_setting('test.dismiss_suspended')::uuid);RAISE EXCEPTION 'Suspended dismissal';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
