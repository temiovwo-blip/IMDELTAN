-- Synthetic users only; compare batch results with single-post permissions/filtering.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id) SELECT id,'active',l FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) SELECT id,'public','members' FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d))v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d))v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.lb_a',a::text,false);PERFORM set_config('test.lb_b',b::text,false);PERFORM set_config('test.lb_c',c::text,false);PERFORM set_config('test.lb_d',d::text,false);
 IF has_function_privilege('anon','public.get_lga_post_like_summaries(uuid[])','EXECUTE') OR NOT has_function_privilege('authenticated','public.get_lga_post_like_summaries(uuid[])','EXECUTE') THEN RAISE EXCEPTION 'Wrong RPC grants';END IF;
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_a'),false);
SELECT set_config('test.lb_p1',public.create_lga_text_post('First')::text,false);
SELECT set_config('test.lb_p2',public.create_lga_text_post('Second')::text,false);
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_b'),false);
SELECT public.set_lga_post_like(current_setting('test.lb_p1')::uuid,true);
SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_c'),false);
SELECT public.set_lga_post_like(current_setting('test.lb_p1')::uuid,true);
SELECT set_config('test.lb_p3',public.create_lga_text_post('Blocked author')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_b'),false);SELECT public.block_user(current_setting('test.lb_c')::uuid);
DO $test$ DECLARE ids uuid[]:=ARRAY[current_setting('test.lb_p1')::uuid,current_setting('test.lb_p1')::uuid,current_setting('test.lb_p2')::uuid,current_setting('test.lb_p3')::uuid,gen_random_uuid()];BEGIN
 IF (SELECT count(*) FROM public.get_lga_post_like_summaries(ids))<>2 THEN RAISE EXCEPTION 'Wrong number of visible summaries';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ids) WHERE post_id=current_setting('test.lb_p1')::uuid AND like_count=1 AND liked_by_me) THEN RAISE EXCEPTION 'Blocked like or own like wrong';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ids) WHERE post_id=current_setting('test.lb_p2')::uuid AND like_count=0 AND NOT liked_by_me) THEN RAISE EXCEPTION 'Empty count wrong';END IF;
 IF EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ids) x CROSS JOIN LATERAL public.get_lga_post_like_summary(x.post_id) y WHERE x.like_count<>y.like_count OR x.liked_by_me<>y.liked_by_me) THEN RAISE EXCEPTION 'Batch/single disagreement';END IF;
 IF EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ARRAY[]::uuid[])) THEN RAISE EXCEPTION 'Empty array returned data';END IF;
 BEGIN PERFORM * FROM public.get_lga_post_like_summaries(NULL);RAISE EXCEPTION 'Null list accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM * FROM public.get_lga_post_like_summaries(ARRAY[NULL::uuid]);RAISE EXCEPTION 'Null item accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM * FROM public.get_lga_post_like_summaries(ARRAY[[gen_random_uuid()],[gen_random_uuid()]]);RAISE EXCEPTION 'Multidimensional array accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM * FROM public.get_lga_post_like_summaries(ARRAY(SELECT gen_random_uuid() FROM generate_series(1,21)));RAISE EXCEPTION 'Oversize batch accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT public.set_own_lga((SELECT id FROM public.list_delta_lgas() WHERE name='Warri South'));
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ARRAY[current_setting('test.lb_p1')::uuid])) THEN RAISE EXCEPTION 'Different LGA sees summary';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_a'),false);SELECT public.delete_own_lga_text_post(current_setting('test.lb_p1')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.get_lga_post_like_summaries(ARRAY[current_setting('test.lb_p1')::uuid])) THEN RAISE EXCEPTION 'Deleted summary visible';END IF;END $test$;
RESET ROLE;
UPDATE public.user_eligibility SET status='ineligible' WHERE user_id=current_setting('test.lb_d')::uuid;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.lb_d'),false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.get_lga_post_like_summaries(ARRAY[]::uuid[]);RAISE EXCEPTION 'Ineligible caller allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;RESET ROLE;
