-- Disposable PostgreSQL only; synthetic identities and simulated auth.
DO $test$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state,display_name) VALUES(a,'active','Sender'),(b,'active','Friend'),(c,'active','Other');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'private','friends'),(b,'private','friends'),(c,'private','friends');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.friendships(user_low,user_high) VALUES(least(a,b),greatest(a,b));
 PERFORM set_config('test.dm_a',a::text,false);PERFORM set_config('test.dm_b',b::text,false);PERFORM set_config('test.dm_c',c::text,false);
 IF has_function_privilege('anon','public.send_friend_message(uuid,text)','EXECUTE') OR has_table_privilege('authenticated','public.messages','SELECT') THEN RAISE EXCEPTION 'Message data exposed';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_a'),false);
SELECT set_config('test.dm_id',public.start_friend_conversation(current_setting('test.dm_b')::uuid)::text,false);
DO $test$ BEGIN
 IF public.start_friend_conversation(current_setting('test.dm_b')::uuid)<>current_setting('test.dm_id')::uuid THEN RAISE EXCEPTION 'Duplicate conversation';END IF;
 BEGIN PERFORM public.start_friend_conversation(current_setting('test.dm_c')::uuid);RAISE EXCEPTION 'Non-friend conversation';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'   ');RAISE EXCEPTION 'Blank message';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
SELECT set_config('test.dm_message',public.send_friend_message(current_setting('test.dm_id')::uuid,' Hello friend ')::text,false);
DO $test$ BEGIN
 FOR i IN 1..29 LOOP PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'rate test '||i);END LOOP;
 BEGIN PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'over limit');RAISE EXCEPTION 'Message limit bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_b'),false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_friend_conversations() WHERE conversation_id=current_setting('test.dm_id')::uuid AND friend_id=current_setting('test.dm_a')::uuid) THEN RAISE EXCEPTION 'Friend conversation missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.list_friend_messages(current_setting('test.dm_id')::uuid) WHERE id=current_setting('test.dm_message')::uuid AND body='Hello friend') THEN RAISE EXCEPTION 'Friend message missing';END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_c'),false);
DO $test$ BEGIN
 BEGIN PERFORM * FROM public.list_friend_messages(current_setting('test.dm_id')::uuid);RAISE EXCEPTION 'Nonparticipant read';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'intrusion');RAISE EXCEPTION 'Nonparticipant send';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_b'),false);
SELECT public.update_own_privacy_settings('private','nobody');
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_a'),false);
DO $test$ BEGIN BEGIN PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'not allowed');RAISE EXCEPTION 'Contact privacy bypassed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_b'),false);
SELECT public.update_own_privacy_settings('private','friends');
SELECT public.block_user(current_setting('test.dm_a')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.dm_a'),false);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_friend_conversations() WHERE conversation_id=current_setting('test.dm_id')::uuid) THEN RAISE EXCEPTION 'Blocked conversation listed';END IF;
 BEGIN PERFORM * FROM public.list_friend_messages(current_setting('test.dm_id')::uuid);RAISE EXCEPTION 'Blocked read';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.send_friend_message(current_setting('test.dm_id')::uuid,'blocked');RAISE EXCEPTION 'Blocked send';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
RESET ROLE;
