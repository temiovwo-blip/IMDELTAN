-- Draft minimal, read-only profile access for eligible signed-in owners only.
-- No sign-up, writes, other users' profiles or admin access is enabled here.
create function app_private.current_user_passes_platform_gate()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.user_passes_platform_gate(auth.uid());
$$;
revoke all on function app_private.current_user_passes_platform_gate() from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.current_user_passes_platform_gate() to authenticated;
-- Only these non-administrative columns are exposed. RLS applies to all reads.
grant select (user_id, handle, display_name, biography, created_at, updated_at) on public.profiles to authenticated;
create policy eligible_user_reads_own_profile on public.profiles
  for select to authenticated
  using (user_id = auth.uid() and app_private.current_user_passes_platform_gate());
-- This is not an onboarding, account administration, or social-profile policy.
-- The app_private schema must remain outside the exposed PostgREST schemas.
-- More direct API and multi-user RLS tests and security review are mandatory.
