DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;l2 uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO l2 FROM public.lgas WHERE state_name='Delta' AND name='Okpe';INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l),(c,'active',l),(d,'active',l2);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT v.id,'public','members' FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.saved_a',a::text,false);PERFORM set_config('test.saved_b',b::text,false);PERFORM set_config('test.saved_c',c::text,false);PERFORM set_config('test.saved_d',d::text,false);
 IF has_function_privilege('anon','public.list_own_saved_lga_text_posts(timestamptz,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.saved_lga_text_posts','SELECT') THEN RAISE EXCEPTION 'Unsafe saved post access';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_a'),false);
SELECT set_config('test.saved_post',public.create_lga_text_post('Visible post')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_b'),false);
SELECT public.save_visible_lga_text_post(current_setting('test.saved_post')::uuid);SELECT public.save_visible_lga_text_post(current_setting('test.saved_post')::uuid);
DO $test$ BEGIN
 IF (SELECT count(*) FROM public.list_own_saved_lga_text_posts())<>1 OR NOT EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts() WHERE id=current_setting('test.saved_post')::uuid AND body='Visible post') THEN RAISE EXCEPTION 'Saved post missing or duplicate';END IF;
 BEGIN PERFORM * FROM public.list_own_saved_lga_text_posts(now(),null);RAISE EXCEPTION 'Bad cursor';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_c'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts()) THEN RAISE EXCEPTION 'Other user sees saved item';END IF;END $test$;
SELECT public.remove_own_saved_lga_text_post(current_setting('test.saved_post')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_d'),false);
DO $test$ BEGIN BEGIN PERFORM public.save_visible_lga_text_post(current_setting('test.saved_post')::uuid);RAISE EXCEPTION 'Cross-LGA save';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_b'),false);
DO $test$ BEGIN IF (SELECT count(*) FROM public.list_own_saved_lga_text_posts())<>1 THEN RAISE EXCEPTION 'Other user changed save';END IF;END $test$;
SELECT public.block_user(current_setting('test.saved_a')::uuid);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts()) THEN RAISE EXCEPTION 'Blocked post visible';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_own_unavailable_saved_lga_text_posts() WHERE id=current_setting('test.saved_post')::uuid) THEN RAISE EXCEPTION 'Unavailable save cannot be removed';END IF;
 BEGIN PERFORM public.save_visible_lga_text_post(current_setting('test.saved_post')::uuid);RAISE EXCEPTION 'Saved blocked post';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
-- Removal is possible without revealing a now-unavailable post.
SELECT public.remove_own_saved_lga_text_post(current_setting('test.saved_post')::uuid);
SELECT public.unblock_user(current_setting('test.saved_a')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts()) OR EXISTS(SELECT 1 FROM public.list_own_unavailable_saved_lga_text_posts()) THEN RAISE EXCEPTION 'Removed save returned';END IF;END $test$;
SELECT public.save_visible_lga_text_post(current_setting('test.saved_post')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_a'),false);
SELECT public.delete_own_lga_text_post(current_setting('test.saved_post')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.saved_b'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_saved_lga_text_posts()) THEN RAISE EXCEPTION 'Deleted saved post visible';END IF;END $test$;
RESET ROLE;
UPDATE public.profiles SET account_state='suspended' WHERE user_id=current_setting('test.saved_b')::uuid;
SET ROLE authenticated;
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_own_saved_lga_text_posts();RAISE EXCEPTION 'Suspended access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
RESET ROLE;
