-- Draft onboarding operation. No public registration is enabled.
-- Call only after security review and API integration testing.
create function public.accept_current_policy(p_policy_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or p_policy_version_id is null then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- A pending user must be able to accept policies during onboarding, before
  -- the full platform eligibility gate can pass. Suspended users cannot.
  perform 1 from public.profiles p
    where p.user_id = current_user_id and p.account_state in ('pending', 'active')
    for share;
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- Lock the policy while validating and recording acceptance, preventing a
  -- concurrent retirement from racing with this transaction.
  perform 1 from public.policy_versions pv
    where pv.id = p_policy_version_id and pv.mandatory
      and pv.published_at is not null and pv.published_at <= pg_catalog.now()
      and pv.retired_at is null
    for share;
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  insert into public.policy_acceptances (user_id, policy_version_id)
    values (current_user_id, p_policy_version_id)
    on conflict (user_id, policy_version_id) do nothing;
end;
$$;
revoke all on function public.accept_current_policy(uuid) from public, anon, authenticated;
grant execute on function public.accept_current_policy(uuid) to authenticated;
-- There is no direct authenticated INSERT grant on policy_acceptances.
-- Current-policy discovery, profile setup, Auth configuration and auditing
-- are not implemented. Review retention, logging and direct API behavior.
