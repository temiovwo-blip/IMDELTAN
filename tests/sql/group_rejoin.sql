-- Only synthetic identities; legacy 'removed' membership is not assumed voluntary.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state,lga_id,handle) VALUES(a,'active',l,'rejoin_a_'||substr(replace(a::text,'-',''),1,12)),(b,'active',l,'rejoin_b_'||substr(replace(b::text,'-',''),1,12)),(c,'active',l,'rejoin_c_'||substr(replace(c::text,'-',''),1,12));
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now()),(c,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.rj_a',a::text,false);PERFORM set_config('test.rj_b',b::text,false);PERFORM set_config('test.rj_c',c::text,false);PERFORM set_config('test.rj_handle','rejoin_b_'||substr(replace(b::text,'-',''),1,12),false);
 IF has_function_privilege('anon','public.list_own_group_invitations(timestamptz,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.community_group_memberships','SELECT') THEN RAISE EXCEPTION 'Unsafe access';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);
SELECT set_config('test.rj_g',public.create_group_in_own_lga('Rejoin test','')::text,false);
SELECT set_config('test.rj_p',public.create_private_group_text_post(current_setting('test.rj_g')::uuid,'Parent')::text,false);
SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_b'),false);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.rj_g')::uuid AND is_rejoin=false) THEN RAISE EXCEPTION 'First invite marked rejoin';END IF;END $test$;
SELECT public.respond_to_group_invitation((SELECT id FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.rj_g')::uuid),true);
SELECT set_config('test.rj_oldpost',public.create_private_group_text_post(current_setting('test.rj_g')::uuid,'Old post')::text,false);
SELECT public.create_private_group_post_comment(current_setting('test.rj_p')::uuid,'Old comment');SELECT public.set_private_group_post_like(current_setting('test.rj_p')::uuid,true);
SELECT public.leave_joined_group(current_setting('test.rj_g')::uuid);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_private_group_text_posts(current_setting('test.rj_g')::uuid);RAISE EXCEPTION 'Left group access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;UPDATE public.community_group_memberships SET joined_at=now()-interval '1 day' WHERE group_id=current_setting('test.rj_g')::uuid AND user_id=current_setting('test.rj_b')::uuid;
INSERT INTO public.community_group_memberships(group_id,user_id,role,status) VALUES(current_setting('test.rj_g')::uuid,current_setting('test.rj_c')::uuid,'member','removed');
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.rj_g')::uuid) WHERE id=current_setting('test.rj_oldpost')::uuid) THEN RAISE EXCEPTION 'Former member post visible';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_private_group_post_like_summary(current_setting('test.rj_p')::uuid) WHERE like_count=0) THEN RAISE EXCEPTION 'Former like visible';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.find_group_invitee(current_setting('test.rj_g')::uuid,current_setting('test.rj_handle')) WHERE user_id=current_setting('test.rj_b')::uuid AND is_rejoin) THEN RAISE EXCEPTION 'Former member lookup missing';END IF;
END $test$;
RESET ROLE;UPDATE public.user_privacy_settings SET profile_visibility='private' WHERE user_id=current_setting('test.rj_b')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);
SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_b')::uuid);
RESET ROLE;
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.community_group_invitations WHERE group_id=current_setting('test.rj_g')::uuid AND invitee_id=current_setting('test.rj_b')::uuid AND status='pending') THEN RAISE EXCEPTION 'Private target invited';END IF;END $test$;
UPDATE public.user_privacy_settings SET profile_visibility='public' WHERE user_id=current_setting('test.rj_b')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);
SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_c')::uuid);
SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_b'),false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.rj_g')::uuid AND is_rejoin) THEN RAISE EXCEPTION 'Rejoin invitation missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_own_group_invitation_notifications()) THEN RAISE EXCEPTION 'Rejoin notice missing';END IF;
 IF EXISTS(SELECT 1 FROM public.list_own_joined_groups() WHERE id=current_setting('test.rj_g')::uuid) THEN RAISE EXCEPTION 'Rejoined without consent';END IF;
END $test$;
SELECT set_config('test.rj_declined',(SELECT id::text FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.rj_g')::uuid),false);
SELECT public.respond_to_group_invitation(current_setting('test.rj_declined')::uuid,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_b')::uuid);
RESET ROLE;
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.community_group_invitations WHERE group_id=current_setting('test.rj_g')::uuid AND invitee_id=current_setting('test.rj_b')::uuid AND status='pending') THEN RAISE EXCEPTION 'Decline cooldown bypassed';END IF;
 IF EXISTS(SELECT 1 FROM public.community_group_invitations WHERE group_id=current_setting('test.rj_g')::uuid AND invitee_id=current_setting('test.rj_c')::uuid) THEN RAISE EXCEPTION 'Legacy removed reinvited';END IF;
END $test$;
UPDATE public.community_group_invitations SET resolved_at=now()-interval '8 days' WHERE id=current_setting('test.rj_declined')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);SELECT public.invite_to_own_group(current_setting('test.rj_g')::uuid,current_setting('test.rj_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_b'),false);SELECT set_config('test.rj_invite',(SELECT id::text FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.rj_g')::uuid),false);
SELECT public.block_user(current_setting('test.rj_a')::uuid);
DO $test$ BEGIN BEGIN PERFORM public.respond_to_group_invitation(current_setting('test.rj_invite')::uuid,true);RAISE EXCEPTION 'Blocked acceptance';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT public.unblock_user(current_setting('test.rj_a')::uuid);SELECT public.respond_to_group_invitation(current_setting('test.rj_invite')::uuid,true);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_joined_groups() WHERE id=current_setting('test.rj_g')::uuid AND joined_at>now()-interval '1 hour') THEN RAISE EXCEPTION 'Rejoin not active or time incorrect';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_a'),false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.rj_g')::uuid) WHERE id=current_setting('test.rj_oldpost')::uuid) THEN RAISE EXCEPTION 'Old post not visible after rejoin';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_private_group_post_comments(current_setting('test.rj_p')::uuid) WHERE body='Old comment') THEN RAISE EXCEPTION 'Old comment not visible after rejoin';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_private_group_post_like_summary(current_setting('test.rj_p')::uuid) WHERE like_count=1) THEN RAISE EXCEPTION 'Old like not visible after rejoin';END IF;
END $test$;RESET ROLE;

-- Even a privileged stale/synthetic pending invitation cannot reactivate an
-- ambiguous legacy 'removed' row; normal RPCs cannot create this invitation.
INSERT INTO public.community_group_invitations(group_id,inviter_id,invitee_id) VALUES(current_setting('test.rj_g')::uuid,current_setting('test.rj_a')::uuid,current_setting('test.rj_c')::uuid);
SELECT set_config('test.rj_stale',(SELECT id::text FROM public.community_group_invitations WHERE group_id=current_setting('test.rj_g')::uuid AND invitee_id=current_setting('test.rj_c')::uuid AND status='pending'),false);
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.rj_c'),false);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_own_group_invitations() WHERE id=current_setting('test.rj_stale')::uuid) THEN RAISE EXCEPTION 'Legacy invitation visible';END IF;
 IF EXISTS(SELECT 1 FROM public.list_own_group_invitation_notifications()) THEN RAISE EXCEPTION 'Legacy notification visible';END IF;
 BEGIN PERFORM public.respond_to_group_invitation(current_setting('test.rj_stale')::uuid,true);RAISE EXCEPTION 'Legacy membership reactivated';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;RESET ROLE;
