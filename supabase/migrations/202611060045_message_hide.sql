-- Development only. Sender "remove" hides the message from normal conversation
-- lists, but intentionally retains its contents for reporting/safety review.
-- This is not data erasure and needs approved retention and privacy policies.
create function public.hide_own_friend_message(p_message_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();msg public.messages%rowtype;
begin
 if u is null or p_message_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select m.* into msg from public.messages m where m.id=p_message_id for update;
 if not found or msg.sender_id<>u or not exists(select 1 from app_private.direct_conversation_pairs pair where pair.conversation_id=msg.conversation_id and u in(pair.user_low,pair.user_high)) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.messages set deleted_at=coalesce(deleted_at,pg_catalog.now()) where id=p_message_id;
end; $$;
revoke all on function public.hide_own_friend_message(uuid) from public,anon,authenticated;
grant execute on function public.hide_own_friend_message(uuid) to authenticated;

-- A sender hiding a message must not destroy the recipient's ability to report it.
create or replace function public.report_received_friend_message(p_message_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); msg public.messages%rowtype; why text:=pg_catalog.btrim(p_reason); result uuid;n int;
begin
 if u is null or p_message_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if why is null or pg_catalog.length(why) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 -- The reporter lock serializes report limits. Do not depend on a friendship or
 -- block relationship: a recipient must be able to report after blocking.
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select m.* into msg from public.messages m where m.id=p_message_id for update;
 if not found or msg.sender_id=u
 or not exists(select 1 from app_private.direct_conversation_pairs pair where pair.conversation_id=msg.conversation_id and u in(pair.user_low,pair.user_high) and msg.sender_id in(pair.user_low,pair.user_high))
 or not exists(select 1 from public.conversation_participants cp where cp.conversation_id=msg.conversation_id and cp.user_id=u) then
  raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_direct_message_id,reason) values(u,p_message_id,why)
 on conflict(reporter_id,reported_direct_message_id) where reporter_id is not null and reported_direct_message_id is not null and status in ('open','reviewing') do nothing returning id into result;
 return result;
end; $$;


-- Safety view includes received messages even when hidden by the sender.
create or replace function public.list_own_blocked_received_messages(p_before timestamptz default null,p_before_id uuid default null)
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

 and exists(select 1 from public.conversation_participants c where c.conversation_id=m.conversation_id and c.user_id=u)
 and (p_before is null or (m.created_at,m.id)<(p_before,p_before_id))
 order by m.created_at desc,m.id desc limit 30;
end; $$;
