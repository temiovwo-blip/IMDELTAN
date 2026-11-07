-- Only for disposable PostgreSQL; synthetic users and simulated authentication.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT u.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) u(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES(a),(b),(c)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.joined_a',a::text,false);PERFORM set_config('test.joined_b',b::text,false);PERFORM set_config('test.joined_c',c::text,false);
 IF has_function_privilege('anon','public.list_own_joined_groups(timestamptz,uuid)','EXECUTE') OR has_function_privilege('anon','public.leave_joined_group(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous joined group access';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.joined_a'),false);
SELECT set_config('test.joined_group',public.create_group_in_own_lga('My group','A description')::text,false);
SELECT public.invite_to_own_group(current_setting('test.joined_group')::uuid,current_setting('test.joined_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.joined_b'),false);
SELECT set_config('test.joined_invite',(SELECT id::text FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.joined_group')::uuid),false);
SELECT public.respond_to_group_invitation(current_setting('test.joined_invite')::uuid,true);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_joined_groups() WHERE id=current_setting('test.joined_group')::uuid AND name='My group' AND lga_name='Uvwie';IF n<>1 THEN RAISE EXCEPTION 'Joined group missing';END IF;
 BEGIN PERFORM * FROM public.list_own_joined_groups(now(),null);RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.joined_c'),false);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_joined_groups();IF n<>0 THEN RAISE EXCEPTION 'Group leaked';END IF;
 BEGIN PERFORM public.leave_joined_group(current_setting('test.joined_group')::uuid);RAISE EXCEPTION 'Third party could leave';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.joined_a'),false);
DO $test$ BEGIN BEGIN PERFORM public.leave_joined_group(current_setting('test.joined_group')::uuid);RAISE EXCEPTION 'Owner allowed to leave';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.joined_b'),false);
SELECT public.block_user(current_setting('test.joined_a')::uuid);
DO $test$ DECLARE n int; BEGIN SELECT count(*) INTO n FROM public.list_own_joined_groups();IF n<>0 THEN RAISE EXCEPTION 'Blocked owner group visible';END IF;END $test$;
DO $test$ DECLARE n int; BEGIN SELECT count(*) INTO n FROM public.list_own_unavailable_group_memberships() WHERE id=current_setting('test.joined_group')::uuid;IF n<>1 THEN RAISE EXCEPTION 'Unavailable membership not available for leaving';END IF;END $test$;
SELECT public.leave_joined_group(current_setting('test.joined_group')::uuid);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.community_group_memberships WHERE group_id=current_setting('test.joined_group')::uuid AND user_id=current_setting('test.joined_b')::uuid AND status='left') THEN RAISE EXCEPTION 'Leave not recorded';END IF;END $test$;
