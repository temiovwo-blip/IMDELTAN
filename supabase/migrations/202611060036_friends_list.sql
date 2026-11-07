-- Development-only friends list and removal. No discovery or broad profile grants.
create function public.list_own_friends(p_after uuid default null)
returns table(user_id uuid,display_name text,handle text)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select p.user_id,
  case when s.profile_visibility in ('friends','public') then coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member') else 'Community member' end,
  case when s.profile_visibility in ('friends','public') then p.handle else null end
 from public.friendships f
 join public.profiles p on p.user_id=case when f.user_low=u then f.user_high else f.user_low end
 join public.user_privacy_settings s on s.user_id=p.user_id
 where u in(f.user_low,f.user_high) and (p_after is null or p.user_id>p_after)
  and app_private.user_passes_platform_gate(p.user_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 order by p.user_id limit 50;
end; $$;

create function public.remove_own_friend(p_friend_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_friend_id is null or u=p_friend_id then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,p_friend_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 delete from public.friendships f where f.user_low=least(u,p_friend_id) and f.user_high=greatest(u,p_friend_id);
 -- Idempotent; does not reveal whether the relationship existed.
end; $$;
revoke all on function public.list_own_friends(uuid),public.remove_own_friend(uuid) from public,anon,authenticated;
grant execute on function public.list_own_friends(uuid),public.remove_own_friend(uuid) to authenticated;

-- Existing conversations obey the same profile-visibility setting as friends.
create or replace function public.list_friend_conversations()
returns table(conversation_id uuid,friend_id uuid,friend_name text,last_message_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select pair.conversation_id,p.user_id,
  case when s.profile_visibility in ('friends','public') then coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member') else 'Community member' end,
  (select max(m.created_at) from public.messages m where m.conversation_id=pair.conversation_id and m.deleted_at is null)
 from app_private.direct_conversation_pairs pair
 join public.profiles p on p.user_id=case when pair.user_low=u then pair.user_high else pair.user_low end
 join public.user_privacy_settings s on s.user_id=p.user_id
 join public.friendships f on f.user_low=pair.user_low and f.user_high=pair.user_high
 join public.conversation_participants mine on mine.conversation_id=pair.conversation_id and mine.user_id=u and mine.status='active'
 join public.conversation_participants theirs on theirs.conversation_id=pair.conversation_id and theirs.user_id=p.user_id and theirs.status='active'
 where u in (pair.user_low,pair.user_high) and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 order by 4 desc nulls last,pair.conversation_id limit 50;
end; $$;
