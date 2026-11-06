-- Draft onboarding reader. Sign-up remains disabled; no table grants added.
create function public.list_current_required_policies()
returns table (id uuid, policy_key text, version text, content_url text, content_sha256 text, accepted boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or not exists (
    select 1 from public.profiles p
    where p.user_id = current_user_id and p.account_state in ('pending', 'active')
  ) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  return query
    select pv.id, pv.policy_key, pv.version, pv.content_url, pv.content_sha256,
      exists (select 1 from public.policy_acceptances pa
        where pa.user_id = current_user_id and pa.policy_version_id = pv.id)
    from public.policy_versions pv
    where pv.mandatory and pv.published_at is not null
      and pv.published_at <= pg_catalog.now() and pv.retired_at is null
    order by pv.policy_key, pv.version;
end;
$$;
revoke all on function public.list_current_required_policies() from public, anon, authenticated;
grant execute on function public.list_current_required_policies() to authenticated;
-- An empty result is NOT permission to proceed: the gate fails closed if there
-- are no current mandatory policies. Security and direct API tests are required.
