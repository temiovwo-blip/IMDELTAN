-- Development-only text messaging draft. No attachments, E2EE, notifications,
-- read receipts, group chats, message deletion, or production release approval.
create table app_private.direct_conversation_pairs (
 user_low uuid not null references auth.users(id) on delete restrict,
 user_high uuid not null references auth.users(id) on delete restrict,
 conversation_id uuid not null unique references public.conversations(id) on delete restrict,
 primary key(user_low,user_high), check (user_low < user_high)
);
revoke all on app_private.direct_conversation_pairs from public,anon,authenticated;

create function public.start_friend_conversation(p_friend_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); cid uuid;
begin
 if u is null or p_friend_id is null or u=p_friend_id then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Shared UUID-order locks serialize with block, friendship and message writes.
 perform 1 from public.profiles p where p.user_id in (u,p_friend_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) or not app_private.user_passes_platform_gate(p_friend_id)
 or not exists(select 1 from public.friendships f where f.user_low=least(u,p_friend_id) and f.user_high=greatest(u,p_friend_id))
 or not exists(select 1 from public.user_privacy_settings s where s.user_id=p_friend_id and s.contact_permission in ('friends','members'))
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_friend_id) or (b.blocker_id=p_friend_id and b.blocked_id=u)) then
  raise exception 'Action not permitted' using errcode='42501';end if;
 select pair.conversation_id into cid from app_private.direct_conversation_pairs pair where pair.user_low=least(u,p_friend_id) and pair.user_high=greatest(u,p_friend_id);
 if cid is not null then return cid;end if;
 insert into public.conversations(created_by,conversation_type) values(u,'direct') returning id into cid;
 insert into public.conversation_participants(conversation_id,user_id) values(cid,u),(cid,p_friend_id);
 insert into app_private.direct_conversation_pairs(user_low,user_high,conversation_id) values(least(u,p_friend_id),greatest(u,p_friend_id),cid);
 return cid;
end; $$;

create function public.list_friend_conversations()
returns table(conversation_id uuid,friend_id uuid,friend_name text,last_message_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select pair.conversation_id,p.user_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),
  (select max(m.created_at) from public.messages m where m.conversation_id=pair.conversation_id and m.deleted_at is null)
 from app_private.direct_conversation_pairs pair
 join public.profiles p on p.user_id=case when pair.user_low=u then pair.user_high else pair.user_low end
 join public.friendships f on f.user_low=pair.user_low and f.user_high=pair.user_high
 join public.conversation_participants mine on mine.conversation_id=pair.conversation_id and mine.user_id=u and mine.status='active'
 join public.conversation_participants theirs on theirs.conversation_id=pair.conversation_id and theirs.user_id=p.user_id and theirs.status='active'
 where u in (pair.user_low,pair.user_high) and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 order by 4 desc nulls last,pair.conversation_id limit 50;
end; $$;

create function public.list_friend_messages(p_conversation_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,sender_id uuid,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); friend_id uuid;
begin
 if u is null or p_conversation_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 select case when pair.user_low=u then pair.user_high else pair.user_low end into friend_id
 from app_private.direct_conversation_pairs pair join public.friendships f on f.user_low=pair.user_low and f.user_high=pair.user_high
 join public.conversation_participants mine on mine.conversation_id=pair.conversation_id and mine.user_id=u and mine.status='active'
 join public.conversation_participants theirs on theirs.conversation_id=pair.conversation_id and theirs.user_id=case when pair.user_low=u then pair.user_high else pair.user_low end and theirs.status='active'
 where pair.conversation_id=p_conversation_id and u in (pair.user_low,pair.user_high);
 if friend_id is null or not app_private.user_passes_platform_gate(friend_id)
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=friend_id) or (b.blocker_id=friend_id and b.blocked_id=u)) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select m.id,m.sender_id,m.body,m.created_at from public.messages m where m.conversation_id=p_conversation_id and m.deleted_at is null
  and (p_before is null or (m.created_at,m.id)<(p_before,p_before_id)) order by m.created_at desc,m.id desc limit 50;
end; $$;

create function public.send_friend_message(p_conversation_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); friend_id uuid; clean text:=pg_catalog.btrim(p_body); result uuid; n int;
begin
 if u is null or p_conversation_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid message' using errcode='22023';end if;
 select case when pair.user_low=u then pair.user_high else pair.user_low end into friend_id from app_private.direct_conversation_pairs pair
 where pair.conversation_id=p_conversation_id and u in (pair.user_low,pair.user_high);
 if friend_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,friend_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) or not app_private.user_passes_platform_gate(friend_id)
 or not exists(select 1 from public.friendships f where f.user_low=least(u,friend_id) and f.user_high=greatest(u,friend_id))
 or not exists(select 1 from public.user_privacy_settings s where s.user_id=friend_id and s.contact_permission in ('friends','members'))
 or not exists(select 1 from public.conversation_participants c where c.conversation_id=p_conversation_id and c.user_id=u and c.status='active')
 or not exists(select 1 from public.conversation_participants c where c.conversation_id=p_conversation_id and c.user_id=friend_id and c.status='active')
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=friend_id) or (b.blocker_id=friend_id and b.blocked_id=u)) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.messages m where m.sender_id=u and m.created_at>pg_catalog.now()-interval '1 hour';
 if n>=30 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.messages(conversation_id,sender_id,body) values(p_conversation_id,u,clean) returning id into result;
 return result;
end; $$;
revoke all on function public.start_friend_conversation(uuid),public.list_friend_conversations(),public.list_friend_messages(uuid,timestamptz,uuid),public.send_friend_message(uuid,text) from public,anon,authenticated;
grant execute on function public.start_friend_conversation(uuid),public.list_friend_conversations(),public.list_friend_messages(uuid,timestamptz,uuid),public.send_friend_message(uuid,text) to authenticated;
