-- Synthetic users and simulated identities; disposable database only.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();h text; BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d);
 INSERT INTO public.profiles(user_id,account_state,handle,display_name) VALUES(a,'active','x'||substr(replace(a::text,'-',''),1,16),'Caller'),(b,'active','x'||substr(replace(b::text,'-',''),1,16),'Visible'),(c,'active','x'||substr(replace(c::text,'-',''),1,16),'Private'),(d,'active','x'||substr(replace(d::text,'-',''),1,16),'Blocked');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'private','members'),(d,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c),(d)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.fdisc_a',a::text,false);PERFORM set_config('test.fdisc_b',b::text,false);PERFORM set_config('test.fdisc_c',c::text,false);PERFORM set_config('test.fdisc_d',d::text,false);
 PERFORM set_config('test.fdisc_bhandle','x'||substr(replace(b::text,'-',''),1,16),false);PERFORM set_config('test.fdisc_chandle','x'||substr(replace(c::text,'-',''),1,16),false);PERFORM set_config('test.fdisc_dhandle','x'||substr(replace(d::text,'-',''),1,16),false);
 IF has_function_privilege('anon','public.find_friend_by_handle(text)','EXECUTE') OR has_table_privilege('authenticated','app_private.friend_lookup_attempts','SELECT') THEN RAISE EXCEPTION 'Search access leaked';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fdisc_a'),false);
SELECT public.block_user(current_setting('test.fdisc_d')::uuid);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.find_friend_by_handle(upper(current_setting('test.fdisc_bhandle'))) WHERE user_id=current_setting('test.fdisc_b')::uuid) THEN RAISE EXCEPTION 'Public exact match missing';END IF;
 IF EXISTS(SELECT 1 FROM public.find_friend_by_handle(current_setting('test.fdisc_chandle'))) THEN RAISE EXCEPTION 'Private profile discoverable';END IF;
 IF EXISTS(SELECT 1 FROM public.find_friend_by_handle(current_setting('test.fdisc_dhandle'))) THEN RAISE EXCEPTION 'Blocked profile discoverable';END IF;
 BEGIN PERFORM * FROM public.find_friend_by_handle('!!');RAISE EXCEPTION 'Invalid handle accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 FOR i IN 1..9 LOOP PERFORM * FROM public.find_friend_by_handle('not_a_real_name');END LOOP;
 BEGIN PERFORM * FROM public.find_friend_by_handle('not_a_real_name');RAISE EXCEPTION 'Search rate exceeded';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;
SELECT public.send_friend_request(current_setting('test.fdisc_b')::uuid);
SELECT public.send_friend_request(current_setting('test.fdisc_b')::uuid);
DO $test$ BEGIN IF (SELECT count(*) FROM public.list_own_friend_requests_display() WHERE direction='sent' AND other_user_id=current_setting('test.fdisc_b')::uuid)<>1 THEN RAISE EXCEPTION 'Sent request missing or duplicate';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fdisc_c'),false);
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.list_own_friend_requests_display() WHERE other_user_id=current_setting('test.fdisc_b')::uuid) THEN RAISE EXCEPTION 'Third party sees request';END IF;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fdisc_b'),false);
SELECT set_config('test.fdisc_request',(SELECT id::text FROM public.list_own_friend_requests_display() WHERE other_user_id=current_setting('test.fdisc_a')::uuid AND direction='received'),false);
SELECT public.respond_friend_request(current_setting('test.fdisc_request')::uuid,true);
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_own_friends() WHERE user_id=current_setting('test.fdisc_a')::uuid) THEN RAISE EXCEPTION 'Friendship missing';END IF;END $test$;
RESET ROLE;
DO $test$ BEGIN IF (SELECT count(*) FROM app_private.friend_request_sends WHERE user_id=current_setting('test.fdisc_a')::uuid)<>1 THEN RAISE EXCEPTION 'Duplicate consumed request quota';END IF;END $test$;
DO $test$ DECLARE target uuid; BEGIN
 FOR i IN 1..20 LOOP
  target:=gen_random_uuid();INSERT INTO auth.users(id) VALUES(target);
  INSERT INTO public.profiles(user_id,account_state) VALUES(target,'active');
  INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(target,'public','members');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(target,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT target,id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;
  PERFORM set_config('test.fdisc_target_'||i,target::text,false);
 END LOOP;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.fdisc_a'),false);
DO $test$ BEGIN
 FOR i IN 1..19 LOOP PERFORM public.send_friend_request(current_setting('test.fdisc_target_'||i)::uuid);END LOOP;
 BEGIN PERFORM public.send_friend_request(current_setting('test.fdisc_target_20')::uuid);RAISE EXCEPTION 'Friend request rate exceeded';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;
RESET ROLE;
