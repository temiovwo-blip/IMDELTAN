-- Draft: initialize the caller's onboarding records, without changing existing state.
-- Does not create Auth users, open registration, verify age or activate accounts.
create function public.initialize_own_onboarding()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or not exists (
    select 1 from auth.users u where u.id = current_user_id
  ) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  insert into public.profiles (user_id) values (current_user_id)
    on conflict (user_id) do nothing;
  insert into public.user_eligibility (user_id) values (current_user_id)
    on conflict (user_id) do nothing;
  insert into public.user_privacy_settings (user_id) values (current_user_id)
    on conflict (user_id) do nothing;
end;
$$;
revoke all on function public.initialize_own_onboarding() from public, anon, authenticated;
grant execute on function public.initialize_own_onboarding() to authenticated;
-- Existing suspended/eligible states are never overwritten by this function.
-- Requires rate-limit, audit, provider-behavior and direct-API testing.
