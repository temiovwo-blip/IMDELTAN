-- Development-only comments and likes on LGA text posts. No media, reply
-- threads, comment reporting, notification delivery or public launch approval.
create table public.lga_post_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.lga_text_posts(id) on delete restrict,
 author_id uuid not null references auth.users(id) on delete restrict,
 body text not null check (pg_catalog.length(pg_catalog.btrim(body)) between 1 and 2000),
 status text not null default 'active' check (status in ('active','deleted','removed')),
 created_at timestamptz not null default pg_catalog.now(),
 deleted_at timestamptz
);
create index lga_post_comments_post_time_idx on public.lga_post_comments(post_id,created_at desc,id desc) where status='active';
create index lga_post_comments_author_time_idx on public.lga_post_comments(author_id,created_at desc);
create table public.lga_post_likes (
 post_id uuid not null references public.lga_text_posts(id) on delete restrict,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default pg_catalog.now(),
 primary key(post_id,user_id)
);
alter table public.lga_post_comments enable row level security;
alter table public.lga_post_likes enable row level security;
revoke all on public.lga_post_comments,public.lga_post_likes from public,anon,authenticated;

-- Helper never callable directly by clients. Visibility is evaluated afresh.
create function app_private.can_view_lga_post(p_viewer uuid,p_post uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_viewer is not null and exists(
  select 1 from public.lga_text_posts t join public.profiles viewer on viewer.user_id=p_viewer
  join public.profiles author on author.user_id=t.author_id
  where t.id=p_post and t.status='active' and viewer.lga_id=t.lga_id and author.lga_id=t.lga_id
   and app_private.user_passes_platform_gate(p_viewer) and app_private.user_passes_platform_gate(t.author_id)
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=p_viewer and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=p_viewer))
 );
$$;
revoke all on function app_private.can_view_lga_post(uuid,uuid) from public,anon,authenticated;

create function public.list_lga_post_comments(p_post_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select c.id,c.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),c.body,c.created_at
 from public.lga_post_comments c join public.profiles p on p.user_id=c.author_id join public.lga_text_posts t on t.id=c.post_id
 where c.post_id=p_post_id and c.status='active' and p.lga_id=t.lga_id and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 and (p_before is null or (c.created_at,c.id)<(p_before,p_before_id)) order by c.created_at desc,c.id desc limit 30;
end; $$;

create function public.create_lga_post_comment(p_post_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); author uuid; clean text:=pg_catalog.btrim(p_body); n int; result uuid;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 2000 then raise exception 'Invalid comment' using errcode='22023';end if;
 select t.author_id into author from public.lga_text_posts t where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author) order by p.user_id for update;
 perform 1 from public.lga_text_posts t where t.id=p_post_id for update;
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.lga_post_comments c where c.author_id=u and c.created_at>pg_catalog.now()-interval '1 hour';
 if n>=20 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.lga_post_comments(post_id,author_id,body) values(p_post_id,u,clean) returning id into result;
 return result;
end; $$;

create function public.delete_own_lga_post_comment(p_comment_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_post_comments set status='deleted',body='[deleted]',deleted_at=pg_catalog.now() where id=p_comment_id and author_id=u and status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;

create function public.set_lga_post_like(p_post_id uuid,p_liked boolean)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); author uuid;
begin
 if u is null or p_post_id is null or p_liked is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select t.author_id into author from public.lga_text_posts t where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author) order by p.user_id for update;
 perform 1 from public.lga_text_posts t where t.id=p_post_id for update;
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_liked then insert into public.lga_post_likes(post_id,user_id) values(p_post_id,u) on conflict do nothing;
 else delete from public.lga_post_likes l where l.post_id=p_post_id and l.user_id=u;end if;
end; $$;

create function public.get_lga_post_like_summary(p_post_id uuid)
returns table(like_count bigint,liked_by_me boolean)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select count(*),coalesce(bool_or(l.user_id=u),false)
 from public.lga_post_likes l join public.profiles p on p.user_id=l.user_id join public.lga_text_posts t on t.id=l.post_id
 where l.post_id=p_post_id and p.lga_id=t.lga_id and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u));
end; $$;
revoke all on function public.list_lga_post_comments(uuid,timestamptz,uuid),public.create_lga_post_comment(uuid,text),public.delete_own_lga_post_comment(uuid),public.set_lga_post_like(uuid,boolean),public.get_lga_post_like_summary(uuid) from public,anon,authenticated;
grant execute on function public.list_lga_post_comments(uuid,timestamptz,uuid),public.create_lga_post_comment(uuid,text),public.delete_own_lga_post_comment(uuid),public.set_lga_post_like(uuid,boolean),public.get_lga_post_like_summary(uuid) to authenticated;
