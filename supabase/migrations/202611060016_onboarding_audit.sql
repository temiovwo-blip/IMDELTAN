-- Draft limited application audit for onboarding changes; not an auth event log.
-- Audit retention, protection from privileged modification, external export and
-- production monitoring still require design and review.
create function app_private.audit_onboarding_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_action text;
  event_target_type text;
  event_target_id text;
begin
  if tg_table_name = 'profiles' and tg_op = 'UPDATE' then
    if old.account_state is not distinct from new.account_state then return new; end if;
    event_action := 'account_state_changed';
    event_target_type := 'user';
    event_target_id := new.user_id::text;
  elsif tg_table_name = 'user_eligibility' and tg_op = 'UPDATE' then
    if old.status is not distinct from new.status then return new; end if;
    event_action := 'eligibility_status_changed';
    event_target_type := 'user';
    event_target_id := new.user_id::text;
  elsif tg_table_name = 'policy_acceptances' and tg_op = 'INSERT' then
    event_action := 'policy_accepted';
    event_target_type := 'policy_version';
    event_target_id := new.policy_version_id::text;
  else
    raise exception 'Unsupported audit trigger';
  end if;
  insert into public.audit_logs (actor_id, action, target_type, target_id, outcome)
    values (auth.uid(), event_action, event_target_type, event_target_id, 'success');
  return new;
end;
$$;
revoke all on function app_private.audit_onboarding_change() from public, anon, authenticated;
create trigger audit_profile_account_state after update of account_state on public.profiles
  for each row execute function app_private.audit_onboarding_change();
create trigger audit_eligibility_status after update of status on public.user_eligibility
  for each row execute function app_private.audit_onboarding_change();
create trigger audit_policy_acceptance after insert on public.policy_acceptances
  for each row execute function app_private.audit_onboarding_change();
-- No OTP, passwords, tokens, policy text, date of birth or message content is logged.
-- Audit triggers run atomically with their triggering transaction. Failed actions,
-- provider sign-ins, recovery and MFA events need separate trusted collection.
