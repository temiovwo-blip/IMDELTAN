-- Disposable PostgreSQL catalog guardrail, not a Supabase REST/storage test.
DO $audit$
DECLARE t record; f record;
BEGIN
 FOR t IN SELECT c.oid,c.relname,c.relrowsecurity FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='app_private' AND c.relkind IN ('r','p')
 LOOP
  IF NOT t.relrowsecurity THEN RAISE EXCEPTION 'Private table lacks RLS: %',t.relname; END IF;
  IF pg_catalog.has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR
     pg_catalog.has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR
     pg_catalog.has_any_column_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,REFERENCES') OR
     pg_catalog.has_any_column_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,REFERENCES') THEN
   RAISE EXCEPTION 'Unexpected private-table or column client grant: %',t.relname;
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='app_private') THEN
  RAISE EXCEPTION 'Private schema policy requires explicit security review';
 END IF;
 FOR f IN SELECT p.oid,n.nspname,p.proname,p.proconfig FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('app_private','public') AND p.prosecdef
 LOOP
  IF f.proconfig IS NULL OR NOT ('search_path=""' = ANY(f.proconfig)) THEN
   RAISE EXCEPTION 'Unsafe security-definer search path: %.%',f.nspname,f.proname;
  END IF;
  IF pg_catalog.has_function_privilege('anon',f.oid,'EXECUTE') THEN
   RAISE EXCEPTION 'Anonymous security-definer execute grant: %.%',f.nspname,f.proname;
  END IF;
 END LOOP;
 FOR f IN SELECT p.oid,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid) args FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='app_private' AND pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
 LOOP
  IF f.proname <> 'current_user_passes_platform_gate' OR f.args <> '' THEN
   RAISE EXCEPTION 'Unexpected authenticated private helper access: %',f.proname;
  END IF;
 END LOOP;
END $audit$;

-- Prove the policy-free RLS boundary on a newly protected table, even if a
-- future change accidentally grants SELECT/INSERT. The temporary grant and
-- synthetic row exist only in this rolled-back disposable test transaction.
BEGIN;
SELECT pg_catalog.set_config('test.private_rls_user',pg_catalog.gen_random_uuid()::text,true);
INSERT INTO auth.users(id) VALUES(current_setting('test.private_rls_user')::uuid);
INSERT INTO app_private.friend_lookup_attempts(user_id) VALUES(current_setting('test.private_rls_user')::uuid);
GRANT SELECT,INSERT ON app_private.friend_lookup_attempts TO authenticated;
SET LOCAL ROLE authenticated;
DO $test$
BEGIN
 IF EXISTS(SELECT 1 FROM app_private.friend_lookup_attempts) THEN
  RAISE EXCEPTION 'RLS allowed a client to read private lookup counters';
 END IF;
 BEGIN
  INSERT INTO app_private.friend_lookup_attempts(user_id) VALUES(current_setting('test.private_rls_user')::uuid);
  RAISE EXCEPTION 'RLS allowed a client to write private lookup counters';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $test$;
RESET ROLE;
ROLLBACK;

-- A column-only grant can be missed by table-level privilege checks.
BEGIN;
GRANT SELECT (user_id) ON app_private.friend_lookup_attempts TO authenticated;
DO $test$
BEGIN
 IF pg_catalog.has_table_privilege('authenticated','app_private.friend_lookup_attempts','SELECT') THEN
  RAISE EXCEPTION 'Expected a column-only grant, not a table grant';
 END IF;
 IF NOT pg_catalog.has_any_column_privilege('authenticated','app_private.friend_lookup_attempts','SELECT') THEN
  RAISE EXCEPTION 'Column-only privilege detection failed';
 END IF;
END $test$;
ROLLBACK;
