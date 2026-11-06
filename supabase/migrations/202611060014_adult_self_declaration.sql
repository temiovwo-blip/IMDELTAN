-- DRAFT ONLY. Self-declaration is not independent age or identity verification.
-- Legal and security approval is required before deployment or public registration.
create function public.declare_adult_eligibility(p_confirmed boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or p_confirmed is distinct from true then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  perform 1 from public.profiles p
    where p.user_id = current_user_id and p.account_state in ('pending', 'active')
    for share;
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- Only a pending eligibility record may be changed by self-declaration.
  -- Do not allow the caller to reset a revoked or ineligible determination.
  update public.user_eligibility e
    set status = 'eligible', verification_method = 'adult_self_declaration',
        verification_version = '1', verified_at = pg_catalog.now(),
        updated_at = pg_catalog.now()
    where e.user_id = current_user_id and e.status = 'pending';
  if not found then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.declare_adult_eligibility(boolean) from public, anon, authenticated;
grant execute on function public.declare_adult_eligibility(boolean) to authenticated;
-- No date of birth or identity documents are collected by this operation.
-- Acceptance text must clearly say the user declares they are 18 or older.
-- UI, abuse controls, audit events, concurrency tests and legal review are pending.
