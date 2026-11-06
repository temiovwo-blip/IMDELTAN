-- Draft self-only block list. Recording blocks is NOT app-wide enforcement.
-- Cursor is a blocked UUID, not an offset; return at most 50 rows per page.
create function public.list_own_blocks(p_after uuid default null)
returns table (blocked_id uuid, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare current_user_id uuid := auth.uid();
begin
  if current_user_id is null or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  return query select b.blocked_id, b.created_at
    from public.user_blocks b
    where b.blocker_id = current_user_id and (p_after is null or b.blocked_id > p_after)
    order by b.blocked_id limit 50;
end;
$$;
revoke all on function public.list_own_blocks(uuid) from public, anon, authenticated;
grant execute on function public.list_own_blocks(uuid) to authenticated;
-- No names are revealed; profile visibility, block enforcement and API review remain.
