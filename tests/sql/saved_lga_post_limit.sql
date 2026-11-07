-- Synthetic DB fixtures test the hard bound and duplicate-idempotency at cap.
DO $test$ DECLARE u uuid:=gen_random_uuid();a uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';INSERT INTO auth.users(id) VALUES(u),(a);INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(u,'active',l),(a,'active',l);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(u,'public','members'),(a,'public','members');INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(u,'eligible','test','test',now()),(a,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(u),(a)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.slim_u',u::text,false);PERFORM set_config('test.slim_a',a::text,false);PERFORM set_config('test.slim_l',l::text,false);
END $test$;
INSERT INTO public.lga_text_posts(author_id,lga_id,body) SELECT current_setting('test.slim_a')::uuid,current_setting('test.slim_l')::uuid,'Fixture '||n FROM generate_series(1,301)n;
INSERT INTO public.saved_lga_text_posts(user_id,post_id) SELECT current_setting('test.slim_u')::uuid,id FROM public.lga_text_posts WHERE author_id=current_setting('test.slim_a')::uuid ORDER BY id LIMIT 300;
SELECT set_config('test.slim_saved',(SELECT post_id::text FROM public.saved_lga_text_posts WHERE user_id=current_setting('test.slim_u')::uuid LIMIT 1),false);
SELECT set_config('test.slim_extra',(SELECT id::text FROM public.lga_text_posts t WHERE author_id=current_setting('test.slim_a')::uuid AND NOT EXISTS(SELECT 1 FROM public.saved_lga_text_posts s WHERE s.post_id=t.id) LIMIT 1),false);
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.slim_u'),false);
SELECT public.save_visible_lga_text_post(current_setting('test.slim_saved')::uuid);
DO $test$ BEGIN BEGIN PERFORM public.save_visible_lga_text_post(current_setting('test.slim_extra')::uuid);RAISE EXCEPTION 'Saved limit exceeded';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Saved post limit reached' THEN RAISE;END IF;END;END $test$;
SELECT public.remove_own_saved_lga_text_post(current_setting('test.slim_saved')::uuid);
SELECT public.save_visible_lga_text_post(current_setting('test.slim_extra')::uuid);
RESET ROLE;
