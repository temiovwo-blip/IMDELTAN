-- Synthetic identities only; disposable PostgreSQL.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b),(c);
 INSERT INTO public.profiles(user_id,account_state,display_name,handle) VALUES(a,'active','First','x'||substr(replace(a::text,'-',''),1,16)),(b,'active','Hidden','x'||substr(replace(b::text,'-',''),1,16)),(c,'active','Stranger','x'||substr(replace(c::text,'-',''),1,16));
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'friends','friends'),(b,'private','friends'),(c,'friends','friends');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b),(c)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.friendships(user_low,user_high) VALUES(least(a,b),greatest(a,b));
 PERFORM set_config('test.flist_a',a::text,false);PERFORM set_config('test.flist_b',b::text,false);PERFORM set_config('test.flist_c',c::text,false);
 IF has_function_privilege('anon','public.list_own_friends(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous friends listing';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.flist_a'),false);
DO $test$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.list_own_friends() WHERE user_id=current_setting('test.flist_b')::uuid AND display_name='Community member' AND handle IS NULL) THEN RAISE EXCEPTION 'Private friend profile leaked or missing';END IF;
 IF EXISTS(SELECT 1 FROM public.list_own_friends() WHERE user_id=current_setting('test.flist_c')::uuid) THEN RAISE EXCEPTION 'Nonfriend listed';END IF;
END $test$;
SELECT set_config('test.flist_conversation',public.start_friend_conversation(current_setting('test.flist_b')::uuid)::text,false);
SELECT public.send_friend_message(current_setting('test.flist_conversation')::uuid,'test');
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.list_friend_conversations() WHERE conversation_id=current_setting('test.flist_conversation')::uuid AND friend_name='Community member') THEN RAISE EXCEPTION 'Private name leaked in conversation';END IF;END $test$;
SELECT public.remove_own_friend(current_setting('test.flist_b')::uuid);
DO $test$ BEGIN
 IF EXISTS(SELECT 1 FROM public.list_own_friends() WHERE user_id=current_setting('test.flist_b')::uuid) OR EXISTS(SELECT 1 FROM public.list_friend_conversations() WHERE conversation_id=current_setting('test.flist_conversation')::uuid) THEN RAISE EXCEPTION 'Removed friend or conversation visible';END IF;
 BEGIN PERFORM * FROM public.list_friend_messages(current_setting('test.flist_conversation')::uuid);RAISE EXCEPTION 'Removed friendship can read messages';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $test$;
RESET ROLE;
