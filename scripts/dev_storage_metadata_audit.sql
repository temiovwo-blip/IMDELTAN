-- Read-only metadata audit for the dedicated dev project; run only after
-- independently verifying the connected project. Does not inspect object data.
-- Intended baseline: six expected buckets private with expected limits/MIMEs;
-- storage.objects RLS enabled, zero policies, client roles non-super/non-bypass.
-- SQL grants can exist even when RLS denies rows; this is not an API test.
with expected(id,max_bytes,mimes) as (values
 ('profile-pictures',5242880,array['image/jpeg','image/png','image/webp']::text[]),
 ('cover-pictures',10485760,array['image/jpeg','image/png','image/webp']::text[]),
 ('post-images',10485760,array['image/jpeg','image/png','image/webp']::text[]),
 ('community-images',10485760,array['image/jpeg','image/png','image/webp']::text[]),
 ('video-uploads',104857600,array['video/mp4','video/webm']::text[]),
 ('message-attachments',10485760,array['image/jpeg','image/png','image/webp','application/pdf']::text[])
), checks as (
 select e.id,coalesce(not b.public and b.file_size_limit=e.max_bytes and b.allowed_mime_types @> e.mimes and b.allowed_mime_types <@ e.mimes,false) as expected_configuration
 from expected e left join storage.buckets b on b.id=e.id
)
select (select count(*) from checks) as expected_bucket_count,
       (select count(*) from checks where expected_configuration) as buckets_matching_baseline,
       (select count(*) from storage.buckets b where not exists(select 1 from expected e where e.id=b.id)) as unexpected_bucket_count,
       (select c.relrowsecurity from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='storage' and c.relname='objects' and c.relkind='r') as objects_rls_enabled,
       (select count(*) from pg_catalog.pg_policies p where p.schemaname='storage' and p.tablename='objects') as objects_policy_count,
       (select count(*) from pg_catalog.pg_roles r where r.rolname in ('anon','authenticated') and not r.rolsuper and not r.rolbypassrls) as client_roles_non_bypass_count,
       pg_catalog.has_table_privilege('anon','storage.objects','SELECT') as anon_object_select_grant,
       pg_catalog.has_table_privilege('authenticated','storage.objects','SELECT') as authenticated_object_select_grant;
