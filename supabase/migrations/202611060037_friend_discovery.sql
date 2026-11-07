-- Development draft: exact username lookup, private search counters, and
-- successful request caps. This is not complete anti-abuse protection.
create table app_private.friend_lookup_attempts(user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default pg_catalog.now());
create index friend_lookup_attempts_user_time_idx on app_private.friend_lookup_attempts(user_id,created_at);
create table app_private.friend_request_sends(user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default pg_catalog.now());
create index friend_request_sends_user_time_idx on app_private.friend_request_sends(user_id,created_at);
revoke all on app_private.friend_lookup_attempts,app_private.friend_request_sends from public,anon,authenticated;

create function public.find_friend_by_handle(p_handle text)
returns table(user_id uuid,handle text,display_name text)
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); clean text:=pg_catalog.lower(pg_catalog.btrim(p_handle)); target uuid; n int;
begin
 if u is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or clean !~ '^[a-z0-9_]{3,30}$' then raise exception 'Invalid username' using errcode='22023';end if;
 select p.user_id into target from public.profiles p where p.handle=clean;
 perform 1 from public.profiles p where p.user_id in(u,target) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 delete from app_private.friend_lookup_attempts a where a.user_id=u and a.created_at<pg_catalog.now()-interval '1 day';
 select count(*) into n from app_private.friend_lookup_attempts a where a.user_id=u and a.created_at>pg_catalog.now()-interval '1 minute';
 if n>=12 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into app_private.friend_lookup_attempts(user_id) values(u);
 return query select p.user_id,p.handle,p.display_name from public.profiles p join public.user_privacy_settings s on s.user_id=p.user_id
 where p.user_id=target and p.user_id<>u and s.profile_visibility='public' and s.contact_permission='members'
 and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.friendships f where f.user_low=least(u,p.user_id) and f.user_high=greatest(u,p.user_id))
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u));
end; $$;

create or replace function public.send_friend_request(p_target_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); n int; inserted int;
begin
 if u is null or p_target_id is null or u=p_target_id then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,p_target_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if not app_private.user_passes_platform_gate(p_target_id)
 or not exists(select 1 from public.user_privacy_settings s where s.user_id=p_target_id and s.contact_permission='members')
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_target_id) or (b.blocker_id=p_target_id and b.blocked_id=u))
 or exists(select 1 from public.friendships f where f.user_low=least(u,p_target_id) and f.user_high=greatest(u,p_target_id)) then return;end if;
 delete from app_private.friend_request_sends a where a.user_id=u and a.created_at<pg_catalog.now()-interval '1 day';
 select count(*) into n from app_private.friend_request_sends a where a.user_id=u and a.created_at>pg_catalog.now()-interval '1 hour';
 if n>=20 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.friend_requests(sender_id,recipient_id) values(u,p_target_id) on conflict do nothing;
 get diagnostics inserted = row_count;
 if inserted=1 then insert into app_private.friend_request_sends(user_id) values(u);end if;
end; $$;

create function public.list_own_friend_requests_display(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,direction text,other_user_id uuid,other_name text,other_handle text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select r.id,case when r.sender_id=u then 'sent' else 'received' end,p.user_id,
  case when s.profile_visibility='public' then coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member') else 'Community member' end,
  case when s.profile_visibility='public' then p.handle else null end,r.created_at
 from public.friend_requests r join public.profiles p on p.user_id=case when r.sender_id=u then r.recipient_id else r.sender_id end
 join public.user_privacy_settings s on s.user_id=p.user_id
 where r.status='pending' and (r.sender_id=u or r.recipient_id=u)
 and (p_before is null or (r.created_at,r.id)<(p_before,p_before_id)) and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 order by r.created_at desc,r.id desc limit 50;
end; $$;
revoke all on function public.find_friend_by_handle(text),public.list_own_friend_requests_display(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.find_friend_by_handle(text),public.list_own_friend_requests_display(timestamptz,uuid) to authenticated;
