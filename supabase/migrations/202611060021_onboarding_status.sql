-- Draft self-only onboarding state; does not grant full application access.
create function public.get_own_onboarding_status()
returns table (account_state text, eligibility_status text, policy_complete boolean)
language plpgsql stable security definer set search_path = '' as $$
declare current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  return query
    select p.account_state, e.status,
      exists (select 1 from public.policy_versions pv
        where pv.mandatory and pv.published_at is not null
          and pv.published_at <= pg_catalog.now() and pv.retired_at is null)
      and not exists (select 1 from public.policy_versions pv
        where pv.mandatory and pv.published_at is not null
          and pv.published_at <= pg_catalog.now() and pv.retired_at is null
          and not exists (select 1 from public.policy_acceptances pa
            where pa.user_id=current_user_id and pa.policy_version_id=pv.id))
    from public.profiles p join public.user_eligibility e on e.user_id=p.user_id
    where p.user_id=current_user_id;
end;
$$;
revoke all on function public.get_own_onboarding_status() from public, anon, authenticated;
grant execute on function public.get_own_onboarding_status() to authenticated;
-- Reveals only the signed-in identity's own minimal state. Direct API tests,
-- abuse controls, email/phone verification and legal/security approval remain.
