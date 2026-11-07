-- Disposable PostgreSQL only; assumes current required test policy exists.
DO $test$ DECLARE owner_id uuid:=gen_random_uuid(); target uuid; l uuid; BEGIN
 SELECT id INTO l FROM public.lgas WHERE state_name='Delta' AND name='Uvwie';
 INSERT INTO auth.users(id) VALUES(owner_id);
 INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(owner_id,'active',l);
 INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(owner_id,'eligible','test','test',now());
 INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT owner_id,id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;
 FOR i IN 1..21 LOOP
  target:=gen_random_uuid();
  INSERT INTO auth.users(id) VALUES(target);
  INSERT INTO public.profiles(user_id,account_state,lga_id) VALUES(target,'active',l);
  INSERT INTO public.user_privacy_settings(user_id,profile_visibility,contact_permission) VALUES(target,'public','members');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at) VALUES(target,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id) SELECT target,id FROM public.policy_versions WHERE mandatory AND published_at<=now() AND retired_at IS NULL;
  PERFORM set_config('test.limit_target_'||i,target::text,false);
 END LOOP;
 PERFORM set_config('test.limit_owner',owner_id::text,false);
 IF has_table_privilege('authenticated','app_private.group_invitation_sends','SELECT') THEN RAISE EXCEPTION 'Rate data exposed';END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.limit_owner'),false);
SELECT set_config('test.limit_group',public.create_group_in_own_lga('Rate limit test','')::text,false);
DO $test$ BEGIN
 FOR i IN 1..20 LOOP PERFORM public.invite_to_own_group(current_setting('test.limit_group')::uuid,current_setting('test.limit_target_'||i)::uuid);END LOOP;
 BEGIN
  PERFORM public.invite_to_own_group(current_setting('test.limit_group')::uuid,current_setting('test.limit_target_21')::uuid);
  RAISE EXCEPTION 'Rate limit was bypassed';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'Please try again later' THEN RAISE; END IF; END;
END $test$;
RESET ROLE;
DO $test$ BEGIN
 IF (SELECT count(*) FROM app_private.group_invitation_sends WHERE user_id=current_setting('test.limit_owner')::uuid)<>20 THEN RAISE EXCEPTION 'Incorrect rate count';END IF;
 UPDATE app_private.group_invitation_sends SET created_at=now()-interval '2 hours' WHERE user_id=current_setting('test.limit_owner')::uuid;
END $test$;
SET ROLE authenticated;
SELECT public.invite_to_own_group(current_setting('test.limit_group')::uuid,current_setting('test.limit_target_21')::uuid);
RESET ROLE;
DO $test$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.community_group_invitations WHERE group_id=current_setting('test.limit_group')::uuid AND invitee_id=current_setting('test.limit_target_21')::uuid) THEN RAISE EXCEPTION 'Window did not reset';END IF;END $test$;
