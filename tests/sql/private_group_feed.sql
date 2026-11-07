DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;l2 uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO l2 FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);INSERT INTO public.profiles(user_id,account_state,lga_id,display_name) VALUES(a,'active',l,'Owner'),(b,'active',l,'Member'),(c,'active',l,'Other member'),(d,'active',l2,'Outsider');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.gfeed_a',a::text,false);PERFORM set_config('test.gfeed_b',b::text,false);PERFORM set_config('test.gfeed_c',c::text,false);PERFORM set_config('test.gfeed_d',d::text,false);
 IF has_function_privilege('anon','public.list_private_group_text_posts(uuid,timestamptz,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.private_group_text_posts','SELECT') THEN RAISE EXCEPTION 'Unsafe access';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_a'),false);
SELECT set_config('test.gfeed_group',public.create_group_in_own_lga('Group feed','')::text,false);
SELECT public.invite_to_own_group(current_setting('test.gfeed_group')::uuid,current_setting('test.gfeed_b')::uuid);
SELECT public.invite_to_own_group(current_setting('test.gfeed_group')::uuid,current_setting('test.gfeed_c')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_b'),false);
SELECT public.respond_to_group_invitation((SELECT id FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.gfeed_group')::uuid),true);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_c'),false);
SELECT public.respond_to_group_invitation((SELECT id FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.gfeed_group')::uuid),true);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_b'),false);
SELECT set_config('test.gfeed_post',public.create_private_group_text_post(current_setting('test.gfeed_group')::uuid,' Hello group ')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_c'),false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.gfeed_group')::uuid) WHERE id=current_setting('test.gfeed_post')::uuid AND body='Hello group') THEN RAISE EXCEPTION 'Member post missing';END IF;
 BEGIN PERFORM public.delete_own_private_group_text_post(current_setting('test.gfeed_post')::uuid);RAISE EXCEPTION 'Deleted other member post';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM * FROM public.list_private_group_text_posts(current_setting('test.gfeed_group')::uuid,now(),null);RAISE EXCEPTION 'Invalid cursor';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT public.block_user(current_setting('test.gfeed_b')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.gfeed_group')::uuid) WHERE id=current_setting('test.gfeed_post')::uuid) THEN RAISE EXCEPTION 'Blocked post visible';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_d'),false);
DO $test$ BEGIN
 BEGIN PERFORM * FROM public.list_private_group_text_posts(current_setting('test.gfeed_group')::uuid);RAISE EXCEPTION 'Nonmember read';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.create_private_group_text_post(current_setting('test.gfeed_group')::uuid,'Not a member');RAISE EXCEPTION 'Nonmember write';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_b'),false);
SELECT public.leave_joined_group(current_setting('test.gfeed_group')::uuid);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_private_group_text_posts(current_setting('test.gfeed_group')::uuid);RAISE EXCEPTION 'Former member read';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
-- Author may remove their own post even after leaving.
SELECT public.delete_own_private_group_text_post(current_setting('test.gfeed_post')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_a'),false);
SELECT public.archive_own_group(current_setting('test.gfeed_group')::uuid);
DO $test$ BEGIN BEGIN PERFORM public.create_private_group_text_post(current_setting('test.gfeed_group')::uuid,'Archived');RAISE EXCEPTION 'Archived write';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.private_group_text_posts WHERE id=current_setting('test.gfeed_post')::uuid AND status='deleted' AND body='[deleted]') THEN RAISE EXCEPTION 'Own delete missing';END IF;END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gfeed_a'),false);
SELECT set_config('test.gfeed_rate_group',public.create_group_in_own_lga('Rate group','')::text,false);
DO $test$ BEGIN
 BEGIN PERFORM public.create_private_group_text_post(current_setting('test.gfeed_rate_group')::uuid,'   ');RAISE EXCEPTION 'Blank post accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 FOR i IN 1..10 LOOP PERFORM public.create_private_group_text_post(current_setting('test.gfeed_rate_group')::uuid,'Rate test '||i);END LOOP;
 BEGIN PERFORM public.create_private_group_text_post(current_setting('test.gfeed_rate_group')::uuid,'Over limit');RAISE EXCEPTION 'Rate limit bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;RESET ROLE;
