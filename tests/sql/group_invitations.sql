-- Disposable database only. Synthetic identities and simulated authentication.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid(); l uuid; other_l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO other_l FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l),(d,'active',other_l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'public','members'),(d,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT u.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d)) u(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES(a),(b),(c),(d)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.ginvite_a',a::text,false);PERFORM set_config('test.ginvite_b',b::text,false);PERFORM set_config('test.ginvite_c',c::text,false);PERFORM set_config('test.ginvite_d',d::text,false);
 IF has_function_privilege('anon','public.invite_to_own_group(uuid,uuid)','EXECUTE') OR has_function_privilege('anon','public.list_own_group_invitations(timestamptz,uuid)','EXECUTE') OR has_function_privilege('anon','public.respond_to_group_invitation(uuid,boolean)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous invitation access';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_a'),false);
SELECT set_config('test.ginvite_group',public.create_group_in_own_lga('Private group','')::text,false);
SELECT public.invite_to_own_group(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_b')::uuid);
SELECT public.invite_to_own_group(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_b')::uuid);
SELECT public.invite_to_own_group(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_d')::uuid);
RESET ROLE;
DO $test$ DECLARE n int;BEGIN SELECT count(*) INTO n FROM public.community_group_invitations WHERE group_id=current_setting('test.ginvite_group')::uuid;IF n<>1 THEN RAISE EXCEPTION 'Duplicate or cross-LGA invitation';END IF;PERFORM set_config('test.ginvite_id',(SELECT id::text FROM public.community_group_invitations WHERE group_id=current_setting('test.ginvite_group')::uuid),false);END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_c'),false);
DO $test$ DECLARE n int;BEGIN
 SELECT count(*) INTO n FROM public.list_own_group_invitations();IF n<>0 THEN RAISE EXCEPTION 'Invitation leaked';END IF;
 BEGIN PERFORM public.respond_to_group_invitation(current_setting('test.ginvite_id')::uuid,true);RAISE EXCEPTION 'Third-party response allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.invite_to_own_group(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_b')::uuid);RAISE EXCEPTION 'Non-owner invited';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_b'),false);
DO $test$ DECLARE n int;BEGIN
 SELECT count(*) INTO n FROM public.list_own_group_invitations() WHERE id=current_setting('test.ginvite_id')::uuid AND group_name='Private group' AND lga_name='Uvwie';IF n<>1 THEN RAISE EXCEPTION 'Own invitation missing';END IF;
 BEGIN INSERT INTO public.community_group_memberships(group_id,user_id,role) VALUES(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_b')::uuid,'owner');RAISE EXCEPTION 'Forged direct membership allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.respond_to_group_invitation(current_setting('test.ginvite_id')::uuid,true);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.community_group_memberships WHERE group_id=current_setting('test.ginvite_group')::uuid AND user_id=current_setting('test.ginvite_b')::uuid AND role='member' AND status='active') THEN RAISE EXCEPTION 'Accepted membership missing';END IF;END $test$;
-- A subsequent block hides an invitation and prevents acceptance.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_a'),false);
SELECT public.invite_to_own_group(current_setting('test.ginvite_group')::uuid,current_setting('test.ginvite_c')::uuid);
RESET ROLE;
SELECT set_config('test.ginvite_c_id',(SELECT id::text FROM public.community_group_invitations WHERE invitee_id=current_setting('test.ginvite_c')::uuid AND status='pending'),false);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_c'),false);
SELECT public.block_user(current_setting('test.ginvite_a')::uuid);
DO $test$ DECLARE n int;BEGIN
 SELECT count(*) INTO n FROM public.list_own_group_invitations();IF n<>0 THEN RAISE EXCEPTION 'Blocked invitation visible';END IF;
 BEGIN PERFORM public.respond_to_group_invitation(current_setting('test.ginvite_c_id')::uuid,true);RAISE EXCEPTION 'Blocked invitation accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
RESET ROLE;
-- Archiving hides invitations and prevents acceptance; a recipient may decline.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_a'),false);
SELECT set_config('test.ginvite_archived',public.create_group_in_own_lga('Another group','')::text,false);
SELECT public.invite_to_own_group(current_setting('test.ginvite_archived')::uuid,current_setting('test.ginvite_b')::uuid);
RESET ROLE;
SELECT set_config('test.ginvite_archived_id',(SELECT id::text FROM public.community_group_invitations WHERE group_id=current_setting('test.ginvite_archived')::uuid),false);
SET ROLE authenticated;
SELECT public.archive_own_group(current_setting('test.ginvite_archived')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.ginvite_b'),false);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_own_group_invitations() WHERE id=current_setting('test.ginvite_archived_id')::uuid;IF n<>0 THEN RAISE EXCEPTION 'Archived invitation visible';END IF;
 BEGIN PERFORM public.respond_to_group_invitation(current_setting('test.ginvite_archived_id')::uuid,true);RAISE EXCEPTION 'Archived invitation accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.respond_to_group_invitation(current_setting('test.ginvite_archived_id')::uuid,false);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.community_group_invitations WHERE id=current_setting('test.ginvite_archived_id')::uuid AND status='declined') THEN RAISE EXCEPTION 'Decline not recorded';END IF;END $test$;
