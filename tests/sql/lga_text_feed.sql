-- Disposable database with synthetic users and a current test policy.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid(); l uuid; l2 uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE name='Uvwie' AND state_name='Delta';
 SELECT id INTO l2 FROM public.lgas WHERE name='Okpe' AND state_name='Delta';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(pending);
 INSERT INTO public.profiles(user_id,account_state,lga_id,display_name) VALUES(a,'active',l,'Author'),(b,'active',l,'Neighbor'),(c,'active',l2,'Elsewhere'),(pending,'pending',l,'Pending');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.feed_a',a::text,false);PERFORM set_config('test.feed_b',b::text,false);PERFORM set_config('test.feed_c',c::text,false);PERFORM set_config('test.feed_pending',pending::text,false);
 IF has_function_privilege('anon','public.list_lga_text_posts(timestamptz,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.lga_text_posts','SELECT') THEN RAISE EXCEPTION 'Feed directly accessible';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_a'),false);
SELECT set_config('test.feed_post',public.create_lga_text_post(' Hello Uvwie ')::text,false);
DO $test$ BEGIN BEGIN PERFORM public.create_lga_text_post('  ');RAISE EXCEPTION 'Empty post accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_b'),false);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.list_lga_text_posts() WHERE id=current_setting('test.feed_post')::uuid AND body='Hello Uvwie' AND author_name='Author';IF n<>1 THEN RAISE EXCEPTION 'Same LGA cannot read';END IF;
 BEGIN PERFORM public.delete_own_lga_text_post(current_setting('test.feed_post')::uuid);RAISE EXCEPTION 'Other user deleted post';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_c'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.feed_post')::uuid) THEN RAISE EXCEPTION 'Cross-LGA leak';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_pending'),false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.list_lga_text_posts();RAISE EXCEPTION 'Pending user read feed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_b'),false);
SELECT public.block_user(current_setting('test.feed_a')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.feed_post')::uuid) THEN RAISE EXCEPTION 'Blocked post leaked';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_a'),false);
SELECT public.delete_own_lga_text_post(current_setting('test.feed_post')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_text_posts() WHERE id=current_setting('test.feed_post')::uuid) THEN RAISE EXCEPTION 'Deleted post visible';END IF;END $test$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.feed_a'),false);
DO $test$ BEGIN
 FOR i IN 1..9 LOOP PERFORM public.create_lga_text_post('Rate test '||i);END LOOP;
 BEGIN PERFORM public.create_lga_text_post('Over limit');RAISE EXCEPTION 'Post limit bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
 BEGIN PERFORM * FROM public.list_lga_text_posts(now(),NULL);RAISE EXCEPTION 'Incomplete cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
RESET ROLE;
