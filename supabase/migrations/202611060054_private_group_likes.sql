-- Local-only private-group likes: counts are filtered to currently eligible,
-- in-group likers visible to the viewer. No public launch or abuse approval.
create table public.private_group_post_likes(
 post_id uuid not null references public.private_group_text_posts(id) on delete restrict,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default pg_catalog.now(),
 primary key(post_id,user_id)
);
create index private_group_post_likes_user_idx on public.private_group_post_likes(user_id,created_at desc);
alter table public.private_group_post_likes enable row level security;
revoke all on public.private_group_post_likes from public,anon,authenticated;
create function app_private.can_view_private_group_post(p_viewer uuid,p_post_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id
  join public.profiles p on p.user_id=t.author_id
  join public.community_group_memberships m on m.group_id=t.group_id and m.user_id=t.author_id and m.status='active'
  where t.id=p_post_id and t.status='active' and p.lga_id=g.lga_id and app_private.can_access_private_group_feed(p_viewer,g.id)
   and app_private.user_passes_platform_gate(t.author_id)
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=p_viewer and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=p_viewer))
 );
$$;
revoke all on function app_private.can_view_private_group_post(uuid,uuid) from public,anon,authenticated;
create function public.set_private_group_post_like(p_post_id uuid,p_liked boolean)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();author uuid;owner_id uuid;gid uuid;
begin
 if u is null or p_post_id is null or p_liked is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select t.author_id,t.group_id,g.created_by into author,gid,owner_id from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=p_post_id for update;
 if not app_private.can_view_private_group_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_liked then insert into public.private_group_post_likes(post_id,user_id) values(p_post_id,u) on conflict do nothing;
 else delete from public.private_group_post_likes l where l.post_id=p_post_id and l.user_id=u;end if;
end; $$;
create function public.get_private_group_post_like_summary(p_post_id uuid)
returns table(like_count bigint,liked_by_me boolean)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_private_group_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select count(*),coalesce(bool_or(l.user_id=u),false) from public.private_group_post_likes l
 where l.post_id=p_post_id and app_private.can_view_private_group_post(l.user_id,p_post_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=l.user_id) or (b.blocker_id=l.user_id and b.blocked_id=u));
end; $$;
revoke all on function public.set_private_group_post_like(uuid,boolean),public.get_private_group_post_like_summary(uuid) from public,anon,authenticated;
grant execute on function public.set_private_group_post_like(uuid,boolean),public.get_private_group_post_like_summary(uuid) to authenticated;
