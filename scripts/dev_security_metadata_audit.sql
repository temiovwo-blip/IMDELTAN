-- Read-only metadata audit. First independently confirm the connection targets
-- the dedicated development project; this SQL does not verify the project ref.
-- These counts do not examine function bodies, JWT requests, objects or data.
WITH functions AS (
 SELECT p.oid,n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid) AS args,
        p.proconfig,p.prosecdef,r.rolsuper,r.rolbypassrls
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 JOIN pg_catalog.pg_roles r ON r.oid=p.proowner
 WHERE n.nspname IN ('public','app_private')
), tables AS (
 SELECT c.oid,n.nspname,c.relrowsecurity FROM pg_catalog.pg_class c
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','app_private') AND c.relkind IN ('r','p')
)
SELECT
 (SELECT count(*) FROM functions WHERE prosecdef) AS definer_functions,
 (SELECT count(*) FROM functions WHERE prosecdef AND NOT COALESCE('search_path=""'=ANY(proconfig),false)) AS definer_without_empty_search_path,
 (SELECT count(*) FROM functions WHERE prosecdef AND pg_catalog.has_function_privilege('anon',oid,'EXECUTE')) AS anon_executable_definers,
 (SELECT count(*) FROM functions WHERE prosecdef AND (rolsuper OR rolbypassrls)) AS definer_owned_by_rls_bypass_role,
 (SELECT count(*) FROM functions WHERE nspname='app_private' AND pg_catalog.has_function_privilege('authenticated',oid,'EXECUTE') AND NOT(proname='current_user_passes_platform_gate' AND args='')) AS unexpected_authenticated_private_functions,
 (SELECT count(*) FROM tables WHERE nspname='public') AS public_tables,
 (SELECT count(*) FROM tables WHERE nspname='public' AND NOT relrowsecurity) AS public_tables_without_rls,
 (SELECT count(*) FROM tables WHERE nspname='app_private') AS private_tables,
 (SELECT count(*) FROM tables WHERE nspname='app_private' AND NOT relrowsecurity) AS private_tables_without_rls,
 (SELECT count(*) FROM tables WHERE nspname='app_private' AND (pg_catalog.has_table_privilege('anon',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR pg_catalog.has_table_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR pg_catalog.has_any_column_privilege('anon',oid,'SELECT,INSERT,UPDATE,REFERENCES') OR pg_catalog.has_any_column_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,REFERENCES'))) AS private_tables_with_client_grant;
