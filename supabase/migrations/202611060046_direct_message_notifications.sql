-- Development only: in-app notices with no content, no push and no backfill.
create unique index notifications_one_direct_message_idx on public.notifications(recipient_id,reference_id)
 where event_type='direct_message_received' and reference_type='direct_message';
create index notifications_direct_message_cursor_idx on public.notifications(recipient_id,created_at desc,id desc)
 where event_type='direct_message_received' and reference_type='direct_message';

create function app_private.notify_direct_message_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.notifications(recipient_id,event_type,reference_type,reference_id)
 select case when pair.user_low=new.sender_id then pair.user_high else pair.user_low end,'direct_message_received','direct_message',new.id
 from app_private.direct_conversation_pairs pair
 where pair.conversation_id=new.conversation_id and new.sender_id in(pair.user_low,pair.user_high)
 on conflict (recipient_id,reference_id) where event_type='direct_message_received' and reference_type='direct_message' do nothing;
 return new;
end; $$;
revoke all on function app_private.notify_direct_message_insert() from public,anon,authenticated;
create trigger direct_message_notification_after_insert after insert on public.messages
 for each row execute function app_private.notify_direct_message_insert();

create function public.list_own_direct_message_notifications(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,conversation_id uuid,created_at timestamptz,read_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select n.id,pair.conversation_id,n.created_at,n.read_at
 from public.notifications n join public.messages m on m.id=n.reference_id
 join app_private.direct_conversation_pairs pair on pair.conversation_id=m.conversation_id and u in(pair.user_low,pair.user_high) and m.sender_id in(pair.user_low,pair.user_high) and m.sender_id<>u
 join public.friendships f on f.user_low=pair.user_low and f.user_high=pair.user_high
 join public.conversation_participants mine on mine.conversation_id=pair.conversation_id and mine.user_id=u and mine.status='active'
 join public.conversation_participants theirs on theirs.conversation_id=pair.conversation_id and theirs.user_id=m.sender_id and theirs.status='active'
 where n.recipient_id=u and n.event_type='direct_message_received' and n.reference_type='direct_message' and m.deleted_at is null
 and app_private.user_passes_platform_gate(m.sender_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=m.sender_id) or (b.blocker_id=m.sender_id and b.blocked_id=u))
 and (p_before is null or (n.created_at,n.id)<(p_before,p_before_id))
 order by n.created_at desc,n.id desc limit 30;
end; $$;
create function public.mark_own_direct_message_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.notifications n set read_at=coalesce(n.read_at,pg_catalog.now()) where n.id=p_notification_id and n.recipient_id=u and n.event_type='direct_message_received' and n.reference_type='direct_message';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.list_own_direct_message_notifications(timestamptz,uuid),public.mark_own_direct_message_notification_read(uuid) from public,anon,authenticated;
grant execute on function public.list_own_direct_message_notifications(timestamptz,uuid),public.mark_own_direct_message_notification_read(uuid) to authenticated;
