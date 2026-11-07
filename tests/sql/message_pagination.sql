-- Synthetic fixtures only. Exercise equal timestamps and the UUID tie-breaker.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b);INSERT INTO public.profiles(user_id,account_state) VALUES(a,'active'),(b,'active');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'private','friends'),(b,'private','friends');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT v.id,'eligible','test','test',now() FROM (VALUES(a),(b)) v(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT v.id,p.id FROM (VALUES(a),(b)) v(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 INSERT INTO public.friendships(user_low,user_high) VALUES(least(a,b),greatest(a,b));PERFORM set_config('test.mpage_a',a::text,false);PERFORM set_config('test.mpage_b',b::text,false);
END $test$;
SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub',current_setting('test.mpage_a'),false);
SELECT set_config('test.mpage_thread',public.start_friend_conversation(current_setting('test.mpage_b')::uuid)::text,false);RESET ROLE;
INSERT INTO public.messages(conversation_id,sender_id,body,created_at) SELECT current_setting('test.mpage_thread')::uuid,current_setting('test.mpage_b')::uuid,'Synthetic '||n,'2020-01-01'::timestamptz FROM generate_series(1,71) n;
SET ROLE authenticated;
DO $test$ DECLARE boundary timestamptz;boundary_id uuid;n1 int;n2 int;total int;BEGIN
 SELECT count(*) INTO n1 FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid);
 SELECT created_at,id INTO boundary,boundary_id FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid) ORDER BY created_at,id LIMIT 1;
 SELECT count(*) INTO n2 FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid,boundary,boundary_id);
 SELECT count(DISTINCT id) INTO total FROM (SELECT id FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid) UNION ALL SELECT id FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid,boundary,boundary_id)) pages;
 IF n1<>50 OR n2<>21 OR total<>71 THEN RAISE EXCEPTION 'Message cursor gap or duplicate: %, %, %',n1,n2,total;END IF;
 BEGIN PERFORM * FROM public.list_friend_messages(current_setting('test.mpage_thread')::uuid,now(),null);RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;RESET ROLE;
