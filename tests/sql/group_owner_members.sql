-- Local synthetic identities, never production data.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id,display_name) VALUES(a,'active',l,'Owner'),(b,'active',l,'Visible'),(c,'active',l,'Blocked'),(d,'active',l,'Ineligible');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.gm_a',a::text,false);PERFORM set_config('test.gm_b',b::text,false);PERFORM set_config('test.gm_c',c::text,false);PERFORM set_config('test.gm_d',d::text,false);
 IF has_function_privilege('anon','public.list_own_private_group_members(uuid,timestamptz,uuid)','EXECUTE') OR has_function_privilege('anon','public.remove_own_private_group_member(uuid,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.community_group_memberships','SELECT') THEN RAISE EXCEPTION 'Unsafe privileges';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gm_a'),false);SELECT set_config('test.gm_g',public.create_group_in_own_lga('Member controls','')::text,false);
RESET ROLE;INSERT INTO public.community_group_memberships(group_id,user_id,role,status) SELECT current_setting('test.gm_g')::uuid,v.id,'member','active' FROM (VALUES(current_setting('test.gm_b')::uuid),(current_setting('test.gm_c')::uuid),(current_setting('test.gm_d')::uuid))v(id);
UPDATE public.user_eligibility SET status='ineligible' WHERE user_id=current_setting('test.gm_d')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gm_b'),false);SELECT set_config('test.gm_post',public.create_private_group_text_post(current_setting('test.gm_g')::uuid,'Retained post')::text,false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid);RAISE EXCEPTION 'Member listing others';EXCEPTION WHEN insufficient_privilege THEN NULL;END;BEGIN PERFORM public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_c')::uuid);RAISE EXCEPTION 'Member removing others';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.gm_a'),false);SELECT public.block_user(current_setting('test.gm_c')::uuid);
DO $test$ BEGIN
 IF (SELECT count(*) FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid))<>1 OR NOT EXISTS(SELECT 1 FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid) WHERE user_id=current_setting('test.gm_b')::uuid AND display_name='Visible') THEN RAISE EXCEPTION 'Member list filtering wrong';END IF;
 BEGIN PERFORM * FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid,now(),null);RAISE EXCEPTION 'Invalid cursor';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_c')::uuid);RAISE EXCEPTION 'Blocked target removable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_d')::uuid);RAISE EXCEPTION 'Ineligible target removable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_a')::uuid);RAISE EXCEPTION 'Owner removable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.report_private_group_text_post(current_setting('test.gm_post')::uuid,'Safety reason');
SELECT public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_b')::uuid);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_private_group_text_posts(current_setting('test.gm_g')::uuid) WHERE id=current_setting('test.gm_post')::uuid) THEN RAISE EXCEPTION 'Removed author visible';END IF;
 BEGIN PERFORM public.remove_own_private_group_member(current_setting('test.gm_g')::uuid,current_setting('test.gm_b')::uuid);RAISE EXCEPTION 'Repeated removal';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT public.invite_to_own_group(current_setting('test.gm_g')::uuid,current_setting('test.gm_b')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.gm_b'),false);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_own_group_invitations() WHERE group_id=current_setting('test.gm_g')::uuid) THEN RAISE EXCEPTION 'Removed member reinvited';END IF;
 BEGIN PERFORM * FROM public.list_private_group_text_posts(current_setting('test.gm_g')::uuid);RAISE EXCEPTION 'Removed member retained access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;RESET ROLE;
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.community_group_memberships WHERE group_id=current_setting('test.gm_g')::uuid AND user_id=current_setting('test.gm_b')::uuid AND status='removed') THEN RAISE EXCEPTION 'Member status wrong';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.private_group_text_posts WHERE id=current_setting('test.gm_post')::uuid AND body='Retained post' AND status='active') THEN RAISE EXCEPTION 'Content erased';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_reports WHERE reported_private_group_post_id=current_setting('test.gm_post')::uuid) THEN RAISE EXCEPTION 'Report missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.audit_logs WHERE actor_id=current_setting('test.gm_a')::uuid AND action='group_owner_member_removed' AND target_id=current_setting('test.gm_g')||':'||current_setting('test.gm_b')) THEN RAISE EXCEPTION 'Audit missing';END IF;
END $test$;
-- Tied timestamps exercise paging without gaps or duplicates.
DO $test$ DECLARE n int;v uuid;l uuid;BEGIN SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';FOR n IN 1..26 LOOP
 v:=gen_random_uuid();INSERT INTO auth.users(id) VALUES(v);INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(v,'active',l);INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(v,'eligible','test','test',now());INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v,id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;INSERT INTO public.community_group_memberships(group_id,user_id,role,status,joined_at) VALUES(current_setting('test.gm_g')::uuid,v,'member','active','2020-01-01T00:00:00Z');
END LOOP;END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.gm_a'),false);
DO $test$ DECLARE first_time timestamptz;first_id uuid;n1 int;n2 int;nall int;BEGIN
 SELECT count(*) INTO n1 FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid);
 SELECT joined_at,user_id INTO first_time,first_id FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid) ORDER BY joined_at,user_id LIMIT 1;
 SELECT count(*) INTO n2 FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid,first_time,first_id);
 SELECT count(DISTINCT user_id) INTO nall FROM (SELECT user_id FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid) UNION ALL SELECT user_id FROM public.list_own_private_group_members(current_setting('test.gm_g')::uuid,first_time,first_id))p;
 IF n1<>25 OR n2<>1 OR nall<>26 THEN RAISE EXCEPTION 'Paging failed %,%,%',n1,n2,nall;END IF;
END $test$;RESET ROLE;
