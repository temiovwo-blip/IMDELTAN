-- Draft block recording only. DO NOT expose as a finished feature until block
-- checks apply to all relevant profiles, feeds, requests, messaging and storage.
create function public.block_user(p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or p_target_id is null or p_target_id = current_user_id then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  perform 1 from public.profiles p where p.user_id = current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- Avoid reporting whether a target exists; caller receives the same result.
  insert into public.user_blocks (blocker_id, blocked_id)
    select current_user_id, p_target_id
    where exists (select 1 from public.profiles p where p.user_id = p_target_id and p.account_state = 'active')
    on conflict (blocker_id, blocked_id) do nothing;
end;
$$;
revoke all on function public.block_user(uuid) from public, anon, authenticated;
grant execute on function public.block_user(uuid) to authenticated;

create function public.unblock_user(p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or p_target_id is null or p_target_id = current_user_id then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  perform 1 from public.profiles p where p.user_id = current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  delete from public.user_blocks b where b.blocker_id = current_user_id and b.blocked_id = p_target_id;
end;
$$;
revoke all on function public.unblock_user(uuid) from public, anon, authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
-- No existing friendship/request is removed here; no block enforcement exists.
-- Privacy, notification, direct API, race, audit and abuse tests are required.
