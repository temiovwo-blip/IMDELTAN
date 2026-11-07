-- Local development only: in-app friend-request notices, no push, email or backfill.
-- Notifications never contain message text or profile details.
create unique index notifications_one_friend_request_idx on public.notifications(recipient_id,reference_id)
 where event_type='friend_request_received' and reference_type='friend_request';
create index notifications_own_cursor_idx on public.notifications(recipient_id,created_at desc,id desc)
 where event_type='friend_request_received' and reference_type='friend_request';

create function app_private.notify_friend_request_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='pending' then
  insert into public.notifications(recipient_id,event_type,reference_type,reference_id)
   values(new.recipient_id,'friend_request_received','friend_request',new.id)
   on conflict (recipient_id,reference_id) where event_type='friend_request_received' and reference_type='friend_request' do nothing;
 end if;
 return new;
end; $$;
revoke all on function app_private.notify_friend_request_insert() from public,anon,authenticated;
create trigger friend_request_notification_after_insert after insert on public.friend_requests
 for each row execute function app_private.notify_friend_request_insert();

create function public.list_own_friend_request_notifications(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,request_id uuid,created_at timestamptz,read_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select n.id,r.id,n.created_at,n.read_at from public.notifications n
 join public.friend_requests r on r.id=n.reference_id and r.recipient_id=n.recipient_id
 where n.recipient_id=u and n.event_type='friend_request_received' and n.reference_type='friend_request' and r.status='pending'
 and app_private.user_passes_platform_gate(r.sender_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=r.sender_id) or (b.blocker_id=r.sender_id and b.blocked_id=u))
 and (p_before is null or (n.created_at,n.id)<(p_before,p_before_id))
 order by n.created_at desc,n.id desc limit 30;
end; $$;

create function public.mark_own_friend_request_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Resolved notifications may also be marked read by their owner; no content is returned.
 update public.notifications n set read_at=coalesce(n.read_at,pg_catalog.now())
 where n.id=p_notification_id and n.recipient_id=u and n.event_type='friend_request_received' and n.reference_type='friend_request';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.list_own_friend_request_notifications(timestamptz,uuid),public.mark_own_friend_request_notification_read(uuid) from public,anon,authenticated;
grant execute on function public.list_own_friend_request_notifications(timestamptz,uuid),public.mark_own_friend_request_notification_read(uuid) to authenticated;
