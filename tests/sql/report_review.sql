-- Disposable database only: uses synthetic users and a simulated JWT claim.
DO $test$ DECLARE reporter uuid:=gen_random_uuid(); target uuid:=gen_random_uuid(); moderator uuid:=gen_random_uuid(); role_id uuid; BEGIN
  INSERT INTO auth.users(id) VALUES(reporter),(target),(moderator);
  INSERT INTO public.profiles(user_id,account_state) VALUES(reporter,'active'),(target,'active'),(moderator,'active');
  INSERT INTO public.user_eligibility(user_id,status,verification_method,verification_version,verified_at)
    VALUES(reporter,'eligible','test','test',now()),(target,'eligible','test','test',now()),(moderator,'eligible','test','test',now());
  INSERT INTO public.policy_acceptances(user_id,policy_version_id)
    SELECT users.id,pv.id FROM (VALUES(reporter),(target),(moderator)) AS users(id)
    CROSS JOIN public.policy_versions pv WHERE pv.mandatory AND pv.published_at <= now() AND pv.retired_at IS NULL;
  INSERT INTO public.admin_roles(role_key,description) VALUES('moderator','test')
    ON CONFLICT(role_key) DO UPDATE SET description=excluded.description RETURNING id INTO role_id;
  INSERT INTO public.admin_role_assignments(user_id,role_id) VALUES(moderator,role_id);
  PERFORM set_config('test.reporter',reporter::text,false);
  PERFORM set_config('test.report_target',target::text,false);
  PERFORM set_config('test.moderator',moderator::text,false);
  IF has_function_privilege('anon','public.report_user(uuid,text)','EXECUTE') OR
     has_function_privilege('anon','public.list_reports_for_review()','EXECUTE') OR
     has_function_privilege('anon','public.review_user_report(uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous reporting operation allowed';
  END IF;
END $test$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.reporter'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
SELECT set_config('test.report_id',public.report_user(current_setting('test.report_target')::uuid,'Synthetic safety report')::text,false);
DO $test$ BEGIN
  BEGIN
    PERFORM * FROM public.list_reports_for_review();
    RAISE EXCEPTION 'Non-moderator accessed reports';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.moderation_records(report_id,action,justification)
      VALUES(current_setting('test.report_id')::uuid,'forged','test');
    RAISE EXCEPTION 'Direct moderation insertion allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',current_setting('test.moderator'),false);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',false);
DO $test$ BEGIN
  BEGIN
    PERFORM * FROM public.list_reports_for_review();
    RAISE EXCEPTION 'Moderator without MFA accessed reports';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',false);
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.list_reports_for_review() WHERE id=current_setting('test.report_id')::uuid;
  IF n<>1 THEN RAISE EXCEPTION 'Moderator cannot see reported user'; END IF;
END $test$;
SELECT public.review_user_report(current_setting('test.report_id')::uuid,'reviewing','Review in progress');
SELECT public.review_user_report(current_setting('test.report_id')::uuid,'closed','Review completed');
DO $test$ BEGIN
  BEGIN
    PERFORM public.review_user_report(current_setting('test.report_id')::uuid,'closed','Again');
    RAISE EXCEPTION 'Closed report changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
DO $test$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.moderation_records WHERE report_id=current_setting('test.report_id')::uuid;
  IF n<>2 THEN RAISE EXCEPTION 'Moderation records missing'; END IF;
  SELECT count(*) INTO n FROM public.audit_logs WHERE action='report_reviewed' AND target_id=current_setting('test.report_id');
  IF n<>2 THEN RAISE EXCEPTION 'Moderation audit missing'; END IF;
END $test$;
