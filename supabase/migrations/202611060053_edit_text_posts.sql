-- Development-only text editing. Reported posts cannot be edited, so reported
-- evidence remains stable. No version history, attachment edits or launch approval.
alter table public.lga_text_posts add column edited_at timestamptz;
alter table public.private_group_text_posts add column edited_at timestamptz;

create function public.edit_own_lga_text_post(p_post_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();clean text:=pg_catalog.btrim(p_body);
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 perform 1 from public.lga_text_posts t where t.id=p_post_id and t.author_id=u and t.status='active' for update;
 if not found or not app_private.can_view_lga_post(u,p_post_id) or exists(select 1 from public.user_reports r where r.reported_lga_post_id=p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_text_posts set body=clean,edited_at=pg_catalog.now() where id=p_post_id;
end; $$;
create function public.edit_own_private_group_text_post(p_post_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();clean text:=pg_catalog.btrim(p_body);gid uuid;owner_id uuid;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023';end if;
 select t.group_id,g.created_by into gid,owner_id from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id where t.id=p_post_id and t.author_id=u;
 if gid is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=p_post_id and t.author_id=u and t.status='active' for update;
 if not found or not app_private.can_access_private_group_feed(u,gid) or exists(select 1 from public.user_reports r where r.reported_private_group_post_id=p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_text_posts set body=clean,edited_at=pg_catalog.now() where id=p_post_id;
end; $$;
revoke all on function public.edit_own_lga_text_post(uuid,text),public.edit_own_private_group_text_post(uuid,text) from public,anon,authenticated;
grant execute on function public.edit_own_lga_text_post(uuid,text),public.edit_own_private_group_text_post(uuid,text) to authenticated;

-- Extend this draft list with an edited marker; restore least-privilege ACL.
drop function public.list_lga_text_posts(timestamptz,uuid);
create function public.list_lga_text_posts(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz,edited_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); l uuid;
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 select p.lga_id into l from public.profiles p where p.user_id=u;
 if l is null then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,t.created_at,t.edited_at
 from public.lga_text_posts t join public.profiles p on p.user_id=t.author_id
 where t.lga_id=l and t.status='active' and p.lga_id=t.lga_id
  and app_private.user_passes_platform_gate(t.author_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=u))
  and (p_before is null or (t.created_at,t.id)<(p_before,p_before_id))
 order by t.created_at desc,t.id desc limit 20;
end; $$;

revoke all on function public.list_lga_text_posts(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_lga_text_posts(timestamptz,uuid) to authenticated;

-- Extend this draft list with an edited marker; restore least-privilege ACL.
drop function public.list_private_group_text_posts(uuid,timestamptz,uuid);
create function public.list_private_group_text_posts(p_group_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz,edited_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_access_private_group_feed(u,p_group_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,t.created_at,t.edited_at
 from public.private_group_text_posts t join public.profiles p on p.user_id=t.author_id
 join public.community_groups g on g.id=t.group_id
 join public.community_group_memberships m on m.group_id=t.group_id and m.user_id=t.author_id and m.status='active'
 where t.group_id=p_group_id and t.status='active' and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(t.author_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=u))
 and (p_before is null or (t.created_at,t.id)<(p_before,p_before_id)) order by t.created_at desc,t.id desc limit 20;
end; $$;
revoke all on function public.list_private_group_text_posts(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_private_group_text_posts(uuid,timestamptz,uuid) to authenticated;

-- Extend this draft list with an edited marker; restore least-privilege ACL.
drop function public.list_own_saved_lga_text_posts(timestamptz,uuid);
create function public.list_own_saved_lga_text_posts(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,saved_at timestamptz,edited_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,s.created_at,t.edited_at
 from public.saved_lga_text_posts s join public.lga_text_posts t on t.id=s.post_id join public.profiles p on p.user_id=t.author_id
 where s.user_id=u and app_private.can_view_lga_post(u,t.id)
 and (p_before is null or (s.created_at,s.post_id)<(p_before,p_before_id)) order by s.created_at desc,s.post_id desc limit 20;
end; $$;
revoke all on function public.list_own_saved_lga_text_posts(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_own_saved_lga_text_posts(timestamptz,uuid) to authenticated;
