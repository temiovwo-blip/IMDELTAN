-- Synthetic users, private removal event notices and current privacy filtering.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c))v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c))v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.gn_a',a::text,false);PERFORM set_config('test.gn_b',b::text,false);PERFORM set_config('test.gn_c',c::text,false);
 IF has_function_privilege('anon','public.list_own_group_removal_notifications(timestamptz,uuid)','EXECUTE') OR has_table_privilege('authenticated','app_private.group_member_removal_events','SELECT') THEN RAISE EXCEPTION 'Unsafe notice access';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_a'),false);SELECT set_config('test.gn_g',public.create_group_in_own_lga('Notice group','')::text,false);
RESET ROLE;INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES(current_setting('test.gn_g')::uuid,current_setting('test.gn_b')::uuid,'member','active');
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_a'),false);SELECT public.remove_own_private_group_member(current_setting('test.gn_g')::uuid,current_setting('test.gn_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_b'),false);
DO $test$ BEGIN IF (SELECT count(*) FROM public.list_own_group_removal_notifications())<>1 OR NOT EXISTS(SELECT 1 FROM public.list_own_group_removal_notifications() WHERE group_name='Notice group' AND read_at IS NULL) THEN RAISE EXCEPTION 'Missing own notice';END IF;
 BEGIN PERFORM * FROM public.list_own_group_removal_notifications(now(),null);RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;END $test$;
SELECT set_config('test.gn_n',(SELECT id::text FROM public.list_own_group_removal_notifications()),false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_c'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_group_removal_notifications()) THEN RAISE EXCEPTION 'Notice leaked';END IF;
 BEGIN PERFORM public.mark_own_group_removal_notification_read(current_setting('test.gn_n')::uuid);RAISE EXCEPTION 'Other user read';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.dismiss_own_in_app_notification(current_setting('test.gn_n')::uuid);RAISE EXCEPTION 'Other user dismissed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_b'),false);SELECT public.mark_own_group_removal_notification_read(current_setting('test.gn_n')::uuid);SELECT public.mark_own_group_removal_notification_read(current_setting('test.gn_n')::uuid);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_group_removal_notifications() WHERE id=current_setting('test.gn_n')::uuid AND read_at IS NOT NULL) THEN RAISE EXCEPTION 'Read marker missing';END IF;END $test$;
SELECT public.block_user(current_setting('test.gn_a')::uuid);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_group_removal_notifications() WHERE id=current_setting('test.gn_n')::uuid AND group_name IS NULL) THEN RAISE EXCEPTION 'Blocked group name leaked';END IF;END $test$;
SELECT public.unblock_user(current_setting('test.gn_a')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_a'),false);SELECT public.archive_own_group(current_setting('test.gn_g')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_b'),false);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_group_removal_notifications() WHERE id=current_setting('test.gn_n')::uuid AND group_name IS NULL) THEN RAISE EXCEPTION 'Archived group name leaked';END IF;END $test$;
SELECT public.dismiss_own_in_app_notification(current_setting('test.gn_n')::uuid);RESET ROLE;
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.community_group_memberships WHERE group_id=current_setting('test.gn_g')::uuid AND user_id=current_setting('test.gn_b')::uuid AND status='removed') OR (SELECT count(*) FROM app_private.group_member_removal_events WHERE group_id=current_setting('test.gn_g')::uuid AND recipient_id=current_setting('test.gn_b')::uuid)<>1 THEN RAISE EXCEPTION 'Dismiss changed membership or evidence';END IF;
END $test$;
-- Synthetic equal timestamps exercise keyset paging through 31 notices.
DO $test$ DECLARE e uuid;i int;BEGIN FOR i IN 1..31 LOOP INSERT INTO app_private.group_member_removal_events(group_id,recipient_id) VALUES(current_setting('test.gn_g')::uuid,current_setting('test.gn_b')::uuid) RETURNING id INTO e;INSERT INTO public.notifications(recipient_id,event_type,reference_type,reference_id,created_at) VALUES(current_setting('test.gn_b')::uuid,'group_membership_removed','group_member_removal',e,'2020-01-01T00:00:00Z');END LOOP;END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gn_b'),false);
DO $test$ DECLARE t timestamptz;i uuid;n1 int;n2 int;total int;BEGIN
 SELECT count(*) INTO n1 FROM public.list_own_group_removal_notifications();SELECT created_at,id INTO t,i FROM public.list_own_group_removal_notifications() ORDER BY created_at,id LIMIT 1;
 SELECT count(*) INTO n2 FROM public.list_own_group_removal_notifications(t,i);
 SELECT count(DISTINCT id) INTO total FROM (SELECT id FROM public.list_own_group_removal_notifications() UNION ALL SELECT id FROM public.list_own_group_removal_notifications(t,i)) p;
 IF n1<>30 OR n2<>1 OR total<>31 THEN RAISE EXCEPTION 'Pagination wrong %,%,%',n1,n2,total;END IF;
END $test$;RESET ROLE;
