-- Development-only comment editing: no version history and no launch approval.
-- Report-first prevents edits, preserving the body available as evidence.
alter table public.private_group_post_comments add column edited_at timestamptz;
create function public.edit_own_private_group_post_comment(p_comment_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();clean text:=pg_catalog.btrim(p_body);gid uuid;pid uuid;post_author uuid;owner_id uuid;
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 2000 then raise exception 'Invalid comment' using errcode='22023';end if;
 select g.id,t.id,t.author_id,g.created_by into gid,pid,post_author,owner_id
 from public.private_group_post_comments c join public.private_group_text_posts t on t.id=c.post_id join public.community_groups g on g.id=t.group_id
 where c.id=p_comment_id and c.author_id=u;
 if gid is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,post_author,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=pid for update;
 perform 1 from public.private_group_post_comments c where c.id=p_comment_id and c.author_id=u and c.status='active' for update;
 if not found or not app_private.can_view_private_group_post(u,pid)
 or exists(select 1 from public.user_reports r where r.reported_private_group_comment_id=p_comment_id) then
  raise exception 'Action not permitted' using errcode='42501';
 end if;
 update public.private_group_post_comments set body=clean,edited_at=pg_catalog.now() where id=p_comment_id;
end; $$;
revoke all on function public.edit_own_private_group_post_comment(uuid,text) from public,anon,authenticated;
grant execute on function public.edit_own_private_group_post_comment(uuid,text) to authenticated;

drop function public.list_private_group_post_comments(uuid,timestamptz,uuid);
create function public.list_private_group_post_comments(p_post_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz,edited_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_private_group_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select c.id,c.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),c.body,c.created_at,c.edited_at
 from public.private_group_post_comments c join public.profiles p on p.user_id=c.author_id
 where c.post_id=p_post_id and c.status='active' and app_private.can_view_private_group_post(c.author_id,p_post_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=c.author_id) or (b.blocker_id=c.author_id and b.blocked_id=u))
 and (p_before is null or (c.created_at,c.id)<(p_before,p_before_id)) order by c.created_at desc,c.id desc limit 30;
end; $$;
revoke all on function public.list_private_group_post_comments(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_private_group_post_comments(uuid,timestamptz,uuid) to authenticated;
