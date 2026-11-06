-- Draft private eligibility gate. Not granted to API roles or called by RLS yet.
-- Eligibility is only one part of resource-specific authorization.
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create function app_private.user_passes_platform_gate(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null
    and exists (
      select 1 from public.profiles p
      join public.user_eligibility e on e.user_id = p.user_id
      where p.user_id = p_user_id and p.account_state = 'active'
        and e.status = 'eligible' and e.verified_at is not null
    )
    and exists (
      select 1 from public.policy_versions pv
      where pv.mandatory and pv.published_at is not null
        and pv.published_at <= pg_catalog.now() and pv.retired_at is null
    )
    and not exists (
      select 1 from public.policy_versions pv
      where pv.mandatory and pv.published_at is not null
        and pv.published_at <= pg_catalog.now() and pv.retired_at is null
        and not exists (
          select 1 from public.policy_acceptances pa
          where pa.user_id = p_user_id and pa.policy_version_id = pv.id
        )
    );
$$;
revoke all on function app_private.user_passes_platform_gate(uuid) from public, anon, authenticated;
-- This gate is deliberately unusable by API clients. Future authorization must
-- bind the identity to auth.uid(), prevent arbitrary-identity probes, enforce
-- resource rules, handle onboarding exceptions and undergo a security review.
