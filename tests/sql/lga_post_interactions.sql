-- Synthetic identities; disposable database only.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();l uuid;l2 uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO l2 FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,lga_id,display_name) VALUES(a,'active',l,'Author'),(b,'active',l,'Neighbor'),(c,'active',l,'Third'),(d,'active',l2,'Other');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'public','members'),(d,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.lgai_a',a::text,false);PERFORM set_config('test.lgai_b',b::text,false);PERFORM set_config('test.lgai_c',c::text,false);PERFORM set_config('test.lgai_d',d::text,false);
 IF has_function_privilege('anon','public.create_lga_post_comment(uuid,text)','EXECUTE') OR has_table_privilege('authenticated','public.lga_post_likes','SELECT') THEN RAISE EXCEPTION 'Client access exposed';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_a'),false);
SELECT set_config('test.lgai_post',public.create_lga_text_post('Test post')::text,false);
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_b'),false);
SELECT set_config('test.lgai_comment',public.create_lga_post_comment(current_setting('test.lgai_post')::uuid,' Hello ')::text,false);
SELECT public.set_lga_post_like(current_setting('test.lgai_post')::uuid,true);
SELECT public.set_lga_post_like(current_setting('test.lgai_post')::uuid,true);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid) WHERE id=current_setting('test.lgai_comment')::uuid AND body='Hello') THEN RAISE EXCEPTION 'Comment missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_lga_post_like_summary(current_setting('test.lgai_post')::uuid) WHERE like_count=1 AND liked_by_me) THEN RAISE EXCEPTION 'Like not idempotent';END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_c'),false);
SELECT public.set_lga_post_like(current_setting('test.lgai_post')::uuid,true);
SELECT public.block_user(current_setting('test.lgai_b')::uuid);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid) WHERE id=current_setting('test.lgai_comment')::uuid) THEN RAISE EXCEPTION 'Blocked comment leaked';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.get_lga_post_like_summary(current_setting('test.lgai_post')::uuid) WHERE like_count=1 AND liked_by_me) THEN RAISE EXCEPTION 'Blocked like leaked in count';END IF;
 BEGIN PERFORM public.delete_own_lga_post_comment(current_setting('test.lgai_comment')::uuid);RAISE EXCEPTION 'Other comment deleted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_d'),false);
DO $test$ BEGIN
 BEGIN PERFORM public.create_lga_post_comment(current_setting('test.lgai_post')::uuid,'No access');RAISE EXCEPTION 'Cross LGA comment';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM * FROM public.get_lga_post_like_summary(current_setting('test.lgai_post')::uuid);RAISE EXCEPTION 'Cross LGA likes';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_b'),false);
SELECT public.set_lga_post_like(current_setting('test.lgai_post')::uuid,false);
SELECT public.delete_own_lga_post_comment(current_setting('test.lgai_comment')::uuid);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid) WHERE id=current_setting('test.lgai_comment')::uuid) THEN RAISE EXCEPTION 'Deleted comment visible';END IF;END $test$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_b'),false);
DO $test$ BEGIN
 FOR i IN 1..19 LOOP PERFORM public.create_lga_post_comment(current_setting('test.lgai_post')::uuid,'Rate test '||i);END LOOP;
 BEGIN PERFORM public.create_lga_post_comment(current_setting('test.lgai_post')::uuid,'Over limit');RAISE EXCEPTION 'Comment rate bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
 BEGIN PERFORM * FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid,now(),NULL);RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
RESET ROLE;
-- Stable pagination also needs an ID tie-breaker when timestamps are equal.
INSERT INTO public.lga_post_comments(post_id,author_id,body,created_at)
 SELECT current_setting('test.lgai_post')::uuid,current_setting('test.lgai_a')::uuid,'Older '||n,'2020-01-01T00:00:00Z'::timestamptz FROM generate_series(1,32) n;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lgai_a'),false);
DO $test$ DECLARE boundary timestamptz;boundary_id uuid;n1 int;n2 int;nall int; BEGIN
 SELECT count(*) INTO n1 FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid);
 SELECT created_at,id INTO boundary,boundary_id FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid) ORDER BY created_at,id LIMIT 1;
 SELECT count(*) INTO n2 FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid,boundary,boundary_id);
 SELECT count(DISTINCT id) INTO nall FROM (SELECT id FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid) UNION ALL SELECT id FROM public.list_lga_post_comments(current_setting('test.lgai_post')::uuid,boundary,boundary_id)) pages;
 IF n1<>30 OR n2<>21 OR nall<>51 THEN RAISE EXCEPTION 'Pagination gap or duplicate: %, %, %',n1,n2,nall;END IF;
END $test$;
RESET ROLE;
