-- Local-only draft: private group text posts. No media, moderation or public launch.
-- Same-LGA, owner and membership restrictions are provisional product rules.
create table public.private_group_text_posts(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.community_groups(id) on delete restrict,
 author_id uuid not null references auth.users(id) on delete restrict,
 body text not null check(pg_catalog.length(pg_catalog.btrim(body)) between 1 and 5000),
 status text not null default 'active' check(status in ('active','deleted','removed')),
 created_at timestamptz not null default pg_catalog.now(),
 deleted_at timestamptz
);
create index private_group_posts_feed_idx on public.private_group_text_posts(group_id,created_at desc,id desc) where status='active';
create index private_group_posts_author_idx on public.private_group_text_posts(author_id,created_at desc);
alter table public.private_group_text_posts enable row level security;
revoke all on public.private_group_text_posts from public,anon,authenticated;

create function app_private.can_access_private_group_feed(p_viewer uuid,p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_viewer is not null and exists(
  select 1 from public.community_groups g join public.profiles vp on vp.user_id=p_viewer
  join public.profiles owner on owner.user_id=g.created_by
  join public.community_group_memberships vm on vm.group_id=g.id and vm.user_id=p_viewer and vm.status='active'
  join public.community_group_memberships om on om.group_id=g.id and om.user_id=g.created_by and om.role='owner' and om.status='active'
  where g.id=p_group_id and g.status='active' and g.visibility='private' and vp.lga_id=g.lga_id and owner.lga_id=g.lga_id
   and app_private.user_passes_platform_gate(p_viewer) and app_private.user_passes_platform_gate(g.created_by)
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=p_viewer and b.blocked_id=g.created_by) or (b.blocker_id=g.created_by and b.blocked_id=p_viewer))
 );
$$;
revoke all on function app_private.can_access_private_group_feed(uuid,uuid) from public,anon,authenticated;

create function public.create_private_group_text_post(p_group_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();owner_id uuid;clean text:=pg_catalog.btrim(p_body);n int;result uuid;
begin
 if u is null or p_group_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023';end if;
 select g.created_by into owner_id from public.community_groups g where g.id=p_group_id;
 if owner_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=p_group_id for update;
 if not app_private.can_access_private_group_feed(u,p_group_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.private_group_text_posts t where t.author_id=u and t.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.private_group_text_posts(group_id,author_id,body) values(p_group_id,u,clean) returning id into result;return result;
end; $$;
create function public.list_private_group_text_posts(p_group_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_access_private_group_feed(u,p_group_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,t.created_at
 from public.private_group_text_posts t join public.profiles p on p.user_id=t.author_id
 join public.community_groups g on g.id=t.group_id
 join public.community_group_memberships m on m.group_id=t.group_id and m.user_id=t.author_id and m.status='active'
 where t.group_id=p_group_id and t.status='active' and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(t.author_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=u))
 and (p_before is null or (t.created_at,t.id)<(p_before,p_before_id)) order by t.created_at desc,t.id desc limit 20;
end; $$;
create function public.delete_own_private_group_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_text_posts set status='deleted',body='[deleted]',deleted_at=pg_catalog.now() where id=p_post_id and author_id=u and status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.create_private_group_text_post(uuid,text),public.list_private_group_text_posts(uuid,timestamptz,uuid),public.delete_own_private_group_text_post(uuid) from public,anon,authenticated;
grant execute on function public.create_private_group_text_post(uuid,text),public.list_private_group_text_posts(uuid,timestamptz,uuid),public.delete_own_private_group_text_post(uuid) to authenticated;
