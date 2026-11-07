-- Local development only: an intentional, read-only safety view for messages
-- received from accounts the caller personally blocked. It never reopens the
-- conversation or enables sending, and must not be exposed without review.
create function public.list_own_blocked_received_messages(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select m.id,m.body,m.created_at from public.messages m
 join app_private.direct_conversation_pairs pair on pair.conversation_id=m.conversation_id
 join public.user_blocks b on b.blocker_id=u and b.blocked_id=m.sender_id
 where u in(pair.user_low,pair.user_high) and m.sender_id<>u and m.sender_id in(pair.user_low,pair.user_high)
 and m.deleted_at is null
 and exists(select 1 from public.conversation_participants c where c.conversation_id=m.conversation_id and c.user_id=u)
 and (p_before is null or (m.created_at,m.id)<(p_before,p_before_id))
 order by m.created_at desc,m.id desc limit 30;
end; $$;
revoke all on function public.list_own_blocked_received_messages(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_own_blocked_received_messages(timestamptz,uuid) to authenticated;
