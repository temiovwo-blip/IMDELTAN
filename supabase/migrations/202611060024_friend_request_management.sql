-- Draft, self-bound friend request management. These endpoints expose only
-- records involving the caller; no public profile or discovery access is granted.
create function public.list_own_friend_requests(p_before timestamptz default null, p_before_id uuid default null)
returns table (id uuid, sender_id uuid, recipient_id uuid, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
  if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  if (p_before is null) <> (p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023'; end if;
  return query select r.id,r.sender_id,r.recipient_id,r.created_at from public.friend_requests r
    where r.status='pending' and (r.sender_id=u or r.recipient_id=u)
      and (p_before is null or (r.created_at,r.id)<(p_before,p_before_id))
      and app_private.user_passes_platform_gate(case when r.sender_id=u then r.recipient_id else r.sender_id end)
      and not exists(select 1 from public.user_blocks b where
        (b.blocker_id=r.sender_id and b.blocked_id=r.recipient_id) or
        (b.blocker_id=r.recipient_id and b.blocked_id=r.sender_id))
    order by r.created_at desc,r.id desc limit 50;
end; $$;

create function public.cancel_own_friend_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); target uuid;
begin
  if u is null or p_request_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  select r.recipient_id into target from public.friend_requests r where r.id=p_request_id and r.sender_id=u;
  if target is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id in (u,target) order by p.user_id for update;
  if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  update public.friend_requests r set status='cancelled',resolved_at=pg_catalog.now()
    where r.id=p_request_id and r.sender_id=u and r.status='pending';
  if not found then raise exception 'Action not permitted' using errcode='42501'; end if;
end; $$;
revoke all on function public.list_own_friend_requests(timestamptz,uuid) from public,anon,authenticated;
revoke all on function public.cancel_own_friend_request(uuid) from public,anon,authenticated;
grant execute on function public.list_own_friend_requests(timestamptz,uuid) to authenticated;
grant execute on function public.cancel_own_friend_request(uuid) to authenticated;
-- Direct API, concurrency, policy-change races, discovery, UI, and rate limits
-- still require validation. Do not expose this draft as a completed feature.
