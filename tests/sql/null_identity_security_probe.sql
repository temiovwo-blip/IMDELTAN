-- Disposable database only. Exercise every currently authenticated-executable
-- application SECURITY DEFINER with a null caller and non-null, synthetic input.
-- Expected denial is SQLSTATE 42501, not merely any error. Each call executes
-- in a subtransaction rolled back even if it unexpectedly succeeds. This is
-- a defence-in-depth test, not proof of JWT, function-body or resource security.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT pg_catalog.set_config('request.jwt.claim.sub','',true);
SELECT pg_catalog.set_config('request.jwt.claims','{}',true);
DO $probe$
DECLARE f record; args text; statement text; tested integer:=0;
BEGIN
 IF NOT pg_catalog.has_schema_privilege('authenticated','public','USAGE') OR
    NOT pg_catalog.has_schema_privilege('authenticated','app_private','USAGE') THEN
  RAISE EXCEPTION 'Probe requires access to the application schemas';
 END IF;
 IF app_private.current_user_passes_platform_gate() IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'Null-user gate must return false';
 END IF;
 FOR f IN
  SELECT p.oid,p.proname,n.nspname,p.proargtypes
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('public','app_private') AND p.prosecdef
   AND pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
   AND NOT (n.nspname='app_private' AND p.proname='current_user_passes_platform_gate' AND p.pronargs=0)
  ORDER BY n.nspname,p.proname,p.oid
 LOOP
  IF EXISTS(SELECT 1 FROM pg_catalog.unnest(f.proargtypes::oid[]) a(typ)
   WHERE pg_catalog.format_type(a.typ,NULL) NOT IN ('uuid','uuid[]','text','boolean','timestamp with time zone')) THEN
   RAISE EXCEPTION 'New argument type requires a reviewed probe fixture: %.%',f.nspname,f.proname;
  END IF;
  SELECT pg_catalog.string_agg(CASE pg_catalog.format_type(a.typ,NULL)
   WHEN 'uuid' THEN pg_catalog.quote_literal('11111111-1111-4111-8111-111111111111')||'::uuid'
   WHEN 'uuid[]' THEN 'ARRAY['||pg_catalog.quote_literal('11111111-1111-4111-8111-111111111111')||'::uuid]'
   WHEN 'text' THEN pg_catalog.quote_literal('synthetic')||'::text'
   WHEN 'boolean' THEN 'false'
   WHEN 'timestamp with time zone' THEN 'pg_catalog.now()'
   END,',' ORDER BY a.ord) INTO args
  FROM pg_catalog.unnest(f.proargtypes::oid[]) WITH ORDINALITY a(typ,ord);
  statement:=pg_catalog.format('SELECT * FROM %I.%I(%s)',f.nspname,f.proname,coalesce(args,''));
  BEGIN
   EXECUTE statement;
   -- Raises and rolls back the subtransaction if a function unexpectedly succeeds.
   RAISE EXCEPTION 'Unexpected successful no-identity call: %.%',f.nspname,f.proname USING ERRCODE='P9999';
  EXCEPTION
   WHEN insufficient_privilege THEN NULL;
  END;
  tested:=tested+1;
 END LOOP;
 IF tested=0 THEN RAISE EXCEPTION 'No functions were exercised'; END IF;
 RAISE NOTICE 'Permission-denied checks passed for % authenticated-executable functions',tested;
END $probe$;
RESET ROLE;
ROLLBACK;
