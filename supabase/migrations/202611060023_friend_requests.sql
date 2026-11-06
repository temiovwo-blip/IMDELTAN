-- Draft social request operations. Profile locks are acquired in UUID order by
-- all operations in this migration to serialize requests with block/unblock.
-- No discovery, notifications, messages, feeds, rate limiting or UI is enabled.
create or replace function public.block_user(p_target_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
  if u is null or p_target_id is null or u=p_target_id then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id in (u,p_target_id) order by p.user_id for update;
  if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  insert into public.user_blocks(blocker_id,blocked_id)
    select u,p_target_id where exists(select 1 from public.profiles p where p.user_id=p_target_id and p.account_state='active')
    on conflict do nothing;
  -- Blocking severs the relationship and cancels either direction's pending request.
  delete from public.friendships f where f.user_low=least(u,p_target_id) and f.user_high=greatest(u,p_target_id);
  update public.friend_requests r set status='cancelled',resolved_at=pg_catalog.now()
    where r.status='pending' and ((r.sender_id=u and r.recipient_id=p_target_id) or (r.sender_id=p_target_id and r.recipient_id=u));
end; $$;

create or replace function public.unblock_user(p_target_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
  if u is null or p_target_id is null or u=p_target_id then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id in (u,p_target_id) order by p.user_id for update;
  if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  delete from public.user_blocks b where b.blocker_id=u and b.blocked_id=p_target_id;
end; $$;

create function public.send_friend_request(p_target_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
  if u is null or p_target_id is null or u=p_target_id then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id in (u,p_target_id) order by p.user_id for update;
  if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  -- Uniform result for unavailable targets, privacy, blocks, existing friendship or duplicate request.
  if not app_private.user_passes_platform_gate(p_target_id)
     or not exists(select 1 from public.user_privacy_settings s where s.user_id=p_target_id and s.contact_permission='members')
     or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_target_id) or (b.blocker_id=p_target_id and b.blocked_id=u))
     or exists(select 1 from public.friendships f where f.user_low=least(u,p_target_id) and f.user_high=greatest(u,p_target_id)) then return; end if;
  insert into public.friend_requests(sender_id,recipient_id) values(u,p_target_id) on conflict do nothing;
end; $$;

create function public.respond_friend_request(p_request_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); sender uuid; row_data public.friend_requests%rowtype;
begin
  if u is null or p_request_id is null or p_accept is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  select r.sender_id into sender from public.friend_requests r where r.id=p_request_id and r.recipient_id=u;
  if sender is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id in (u,sender) order by p.user_id for update;
  select * into row_data from public.friend_requests r where r.id=p_request_id and r.recipient_id=u for update;
  if not found or row_data.status<>'pending' or not app_private.user_passes_platform_gate(u) then
    raise exception 'Action not permitted' using errcode='42501'; end if;
  if p_accept then
    if not app_private.user_passes_platform_gate(sender)
      or not exists(select 1 from public.user_privacy_settings s where s.user_id=u and s.contact_permission='members')
      or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=sender) or (b.blocker_id=sender and b.blocked_id=u)) then
      raise exception 'Action not permitted' using errcode='42501'; end if;
    insert into public.friendships(user_low,user_high) values(least(u,sender),greatest(u,sender)) on conflict do nothing;
  end if;
  update public.friend_requests set status=case when p_accept then 'accepted' else 'declined' end,resolved_at=pg_catalog.now() where id=p_request_id;
end; $$;

revoke all on function public.send_friend_request(uuid) from public,anon,authenticated;
revoke all on function public.respond_friend_request(uuid,boolean) from public,anon,authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid,boolean) to authenticated;
-- Existing block function ACLs are retained by CREATE OR REPLACE. Feature must
-- remain disabled pending policy/eligibility races, concurrency and direct API tests.
