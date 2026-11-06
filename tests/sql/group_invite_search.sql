-- Disposable database only; synthetic users with simulated auth.
DO $test$ DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();e uuid:=gen_random_uuid();l uuid;other_l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';SELECT id INTO other_l FROM public.lgas WHERE state_name='Delta' AND name='Okpe';
 INSERT INTO auth.users(id) VALUES(a),(b),(c),(d),(e);
 INSERT INTO public.profiles(user_id,account_state,lga_id,handle,display_name) VALUES
 (a,'active',l,'a'||substr(replace(a::text,'-',''),1,16),'Owner'),
 (b,'active',l,'b'||substr(replace(b::text,'-',''),1,16),'Visible'),
 (c,'active',l,'c'||substr(replace(c::text,'-',''),1,16),'Private'),
 (d,'active',other_l,'d'||substr(replace(d::text,'-',''),1,16),'Other LGA'),
 (e,'active',l,'e'||substr(replace(e::text,'-',''),1,16),'Blocked');
 INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(a,'public','members'),(b,'public','members'),(c,'private','members'),(d,'public','members'),(e,'public','members');
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) SELECT u.id,'eligible','test','test',now() FROM (VALUES(a),(b),(c),(d),(e)) u(id);
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT u.id,p.id FROM (VALUES(a),(b),(c),(d),(e)) u(id) CROSS JOIN public.policy_versions p WHERE p.mandatory AND p.published_at<=now() AND p.retired_at IS NULL;
 PERFORM set_config('test.lookup_a',a::text,false);PERFORM set_config('test.lookup_b',b::text,false);PERFORM set_config('test.lookup_c',c::text,false);PERFORM set_config('test.lookup_d',d::text,false);PERFORM set_config('test.lookup_e',e::text,false);
 PERFORM set_config('test.handle_b','b'||substr(replace(b::text,'-',''),1,16),false);PERFORM set_config('test.handle_c','c'||substr(replace(c::text,'-',''),1,16),false);PERFORM set_config('test.handle_d','d'||substr(replace(d::text,'-',''),1,16),false);PERFORM set_config('test.handle_e','e'||substr(replace(e::text,'-',''),1,16),false);
 IF has_function_privilege('anon','public.find_group_invitee(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous group search';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lookup_a'),false);
SELECT set_config('test.lookup_group',public.create_group_in_own_lga('Lookup test','')::text,false);
SELECT public.block_user(current_setting('test.lookup_e')::uuid);
DO $test$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,upper(current_setting('test.handle_b'))) WHERE user_id=current_setting('test.lookup_b')::uuid AND display_name='Visible';IF n<>1 THEN RAISE EXCEPTION 'Eligible exact result missing';END IF;
 SELECT count(*) INTO n FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,current_setting('test.handle_c'));IF n<>0 THEN RAISE EXCEPTION 'Private profile leaked';END IF;
 SELECT count(*) INTO n FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,current_setting('test.handle_d'));IF n<>0 THEN RAISE EXCEPTION 'Cross-LGA profile leaked';END IF;
 SELECT count(*) INTO n FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,current_setting('test.handle_e'));IF n<>0 THEN RAISE EXCEPTION 'Blocked profile leaked';END IF;
 BEGIN PERFORM * FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,'%%');RAISE EXCEPTION 'Invalid search accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $test$;
RESET ROLE;
UPDATE public.user_privacy_settings SET contact_permission='nobody' WHERE user_id=current_setting('test.lookup_b')::uuid;
SET ROLE authenticated;
SELECT public.invite_to_own_group(current_setting('test.lookup_group')::uuid,current_setting('test.lookup_b')::uuid);
DO $test$ DECLARE n int;BEGIN SELECT count(*) INTO n FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,current_setting('test.handle_b'));IF n<>0 THEN RAISE EXCEPTION 'Contact preference ignored';END IF;END $test$;
RESET ROLE;
DO $test$ BEGIN IF EXISTS(SELECT 1 FROM public.community_group_invitations WHERE group_id=current_setting('test.lookup_group')::uuid AND invitee_id=current_setting('test.lookup_b')::uuid) THEN RAISE EXCEPTION 'Invitation ignored updated privacy';END IF;END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lookup_b'),false);
DO $test$ BEGIN BEGIN PERFORM * FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,current_setting('test.handle_c'));RAISE EXCEPTION 'Non-owner lookup allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.lookup_a'),false);
DO $test$ BEGIN
 -- Five successful lookup calls above; seven more reach the per-minute cap.
 FOR i IN 1..7 LOOP PERFORM * FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,'missing_name');END LOOP;
 BEGIN PERFORM * FROM public.find_group_invitee(current_setting('test.lookup_group')::uuid,'missing_name');RAISE EXCEPTION 'Lookup limit bypassed';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE;END IF;END;
END $test$;
RESET ROLE;
