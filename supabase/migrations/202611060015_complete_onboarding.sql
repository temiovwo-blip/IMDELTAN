-- Draft: transition the caller from pending to active after onboarding.
-- Public registration remains closed; do not deploy without legal/security review.
create function public.complete_own_onboarding()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- A pending profile is necessary. This lock prevents concurrent changes to
  -- the profile's state during this operation.
  perform 1 from public.profiles p
    where p.user_id = current_user_id and p.account_state = 'pending'
    for update;
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  perform 1 from public.user_eligibility e
    where e.user_id = current_user_id and e.status = 'eligible'
      and e.verified_at is not null
    for share;
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.policy_versions pv
    where pv.mandatory and pv.published_at is not null
      and pv.published_at <= pg_catalog.now() and pv.retired_at is null
  ) or exists (
    select 1 from public.policy_versions pv
    where pv.mandatory and pv.published_at is not null
      and pv.published_at <= pg_catalog.now() and pv.retired_at is null
      and not exists (
        select 1 from public.policy_acceptances pa
        where pa.user_id = current_user_id and pa.policy_version_id = pv.id
      )
  ) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  update public.profiles set account_state = 'active', updated_at = pg_catalog.now()
    where user_id = current_user_id and account_state = 'pending';
end;
$$;
revoke all on function public.complete_own_onboarding() from public, anon, authenticated;
grant execute on function public.complete_own_onboarding() to authenticated;
-- The normal gate rechecks current eligibility and policies for every protected
-- access. Policy publication races, email/provider verification, recovery,
-- audit, rate limits and direct API behavior still require security review.
