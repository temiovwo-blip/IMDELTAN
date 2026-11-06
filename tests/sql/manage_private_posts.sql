-- Synthetic identities only, disposable PostgreSQL.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); pending uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(pending);
 INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active'),(pending,'pending');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(a,'eligible','test','test',now()),(b,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id)
 SELECT u.id,p.id FROM (VALUES(a),(b)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.manage_a',a::text,false); PERFORM set_config('test.manage_b',b::text,false); PERFORM set_config('test.manage_pending',pending::text,false);
 IF has_function_privilege('anon','public.edit_own_private_text_post(uuid,text)','EXECUTE') OR has_function_privilege('anon','public.delete_own_private_text_post(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous mutation allowed'; END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.manage_a'),false);
SELECT set_config('test.manage_post',public.create_own_private_text_post('first')::text,false);
SELECT public.edit_own_private_text_post(current_setting('test.manage_post')::uuid,' updated ');
DO $test$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM public.posts WHERE id=current_setting('test.manage_post')::uuid AND body='updated';
 IF n<>1 THEN RAISE EXCEPTION 'Edit not saved'; END IF;
 BEGIN PERFORM public.edit_own_private_text_post(current_setting('test.manage_post')::uuid,' '); RAISE EXCEPTION 'Empty edit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN UPDATE public.posts SET body='forged' WHERE id=current_setting('test.manage_post')::uuid; RAISE EXCEPTION 'Direct update allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.manage_b'),false);
DO $test$ BEGIN
 BEGIN PERFORM public.edit_own_private_text_post(current_setting('test.manage_post')::uuid,'not yours'); RAISE EXCEPTION 'Other user edit allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.delete_own_private_text_post(current_setting('test.manage_post')::uuid); RAISE EXCEPTION 'Other user delete allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.manage_pending'),false);
DO $test$ BEGIN BEGIN PERFORM public.delete_own_private_text_post(current_setting('test.manage_post')::uuid); RAISE EXCEPTION 'Pending account deleted note'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.manage_a'),false);
SELECT public.delete_own_private_text_post(current_setting('test.manage_post')::uuid);
DO $test$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM public.posts WHERE id=current_setting('test.manage_post')::uuid; IF n<>0 THEN RAISE EXCEPTION 'Deleted note visible'; END IF;
 BEGIN PERFORM public.edit_own_private_text_post(current_setting('test.manage_post')::uuid,'resurrect'); RAISE EXCEPTION 'Deleted note edited'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.posts WHERE id=current_setting('test.manage_post')::uuid AND status='deleted' AND body='') THEN RAISE EXCEPTION 'Deleted text not cleared'; END IF; END $test$;
