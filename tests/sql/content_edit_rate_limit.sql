-- Synthetic identities; checks a shared rolling cap and no content metadata.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(a),(b);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(a,'active',l),(b,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.er_a',a::text,false);PERFORM set_config('test.er_b',b::text,false);
 IF has_table_privilege('anon','app_private.content_edit_events','SELECT') OR has_table_privilege('authenticated','app_private.content_edit_events','SELECT') OR has_function_privilege('authenticated','app_private.record_content_edit(uuid)','EXECUTE') OR has_function_privilege('anon','app_private.record_content_edit(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Edit event access exposed';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.er_a'),false);
SELECT set_config('test.er_lp',public.create_lga_text_post('LGA post')::text,false);
SELECT set_config('test.er_g',public.create_group_in_own_lga('Edit cap','')::text,false);
SELECT set_config('test.er_gp',public.create_private_group_text_post(current_setting('test.er_g')::uuid,'Group post')::text,false);
SELECT set_config('test.er_lc',public.create_lga_post_comment(current_setting('test.er_lp')::uuid,'LGA comment')::text,false);
SELECT set_config('test.er_gc',public.create_private_group_post_comment(current_setting('test.er_gp')::uuid,'Group comment')::text,false);
DO $test$ BEGIN
 -- Failed input/authorization does not consume quota.
 BEGIN PERFORM public.edit_own_lga_post_comment(current_setting('test.er_lc')::uuid,' ');RAISE EXCEPTION 'Blank allowed';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.edit_own_lga_text_post(gen_random_uuid(),'No');RAISE EXCEPTION 'Invalid target';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 FOR i IN 1..5 LOOP
  PERFORM public.edit_own_lga_text_post(current_setting('test.er_lp')::uuid,'LGA '||i);
  PERFORM public.edit_own_private_group_text_post(current_setting('test.er_gp')::uuid,'Group '||i);
  PERFORM public.edit_own_lga_post_comment(current_setting('test.er_lc')::uuid,'LGA comment '||i);
  PERFORM public.edit_own_private_group_post_comment(current_setting('test.er_gc')::uuid,'Group comment '||i);
 END LOOP;
 BEGIN PERFORM public.edit_own_lga_text_post(current_setting('test.er_lp')::uuid,'Over limit');RAISE EXCEPTION 'Cap bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
 BEGIN PERFORM public.edit_own_private_group_text_post(current_setting('test.er_gp')::uuid,'Over limit');RAISE EXCEPTION 'Cap bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
 BEGIN PERFORM public.edit_own_lga_post_comment(current_setting('test.er_lc')::uuid,'Over limit');RAISE EXCEPTION 'Cap bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
 BEGIN PERFORM public.edit_own_private_group_post_comment(current_setting('test.er_gc')::uuid,'Over limit');RAISE EXCEPTION 'Cap bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.er_b'),false);
SELECT set_config('test.er_bp',public.create_lga_text_post('Second user')::text,false);SELECT public.edit_own_lga_text_post(current_setting('test.er_bp')::uuid,'Independent');
RESET ROLE;
DO $test$ BEGIN
 IF (SELECT count(*) FROM app_private.content_edit_events WHERE user_id=current_setting('test.er_a')::uuid)<>20 OR (SELECT count(*) FROM app_private.content_edit_events WHERE user_id=current_setting('test.er_b')::uuid)<>1 THEN RAISE EXCEPTION 'Invalid edit event count';END IF;
 IF (SELECT body FROM public.lga_text_posts WHERE id=current_setting('test.er_lp')::uuid)<>'LGA 5' OR (SELECT body FROM public.private_group_post_comments WHERE id=current_setting('test.er_gc')::uuid)<>'Group comment 5' THEN RAISE EXCEPTION 'Failed edit changed text';END IF;
END $test$;
UPDATE app_private.content_edit_events SET created_at=pg_catalog.clock_timestamp()-interval '61 minutes' WHERE user_id=current_setting('test.er_a')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.er_a'),false);SELECT public.edit_own_lga_text_post(current_setting('test.er_lp')::uuid,'After window');RESET ROLE;
DO $test$ BEGIN IF (SELECT count(*) FROM app_private.content_edit_events WHERE user_id=current_setting('test.er_a')::uuid)<>1 THEN RAISE EXCEPTION 'Expired entries not pruned';END IF;END $test$;
-- Explicit transaction rollback must roll back both the text and event.
BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.er_a'),true);SELECT public.edit_own_lga_text_post(current_setting('test.er_lp')::uuid,'Rolled back');ROLLBACK;
DO $test$ BEGIN IF (SELECT count(*) FROM app_private.content_edit_events WHERE user_id=current_setting('test.er_a')::uuid)<>1 OR (SELECT body FROM public.lga_text_posts WHERE id=current_setting('test.er_lp')::uuid)<>'After window' THEN RAISE EXCEPTION 'Rollback incorrect';END IF;END $test$;
