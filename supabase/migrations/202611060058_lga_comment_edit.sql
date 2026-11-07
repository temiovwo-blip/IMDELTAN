-- Development-only author comment editing; reported evidence is immutable.
-- No edit history, abuse approval or production launch approval.
alter table public.lga_post_comments add column edited_at timestamptz;
create function public.edit_own_lga_post_comment(p_comment_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();clean text:=pg_catalog.btrim(p_body);pid uuid;post_author uuid;
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 2000 then raise exception 'Invalid comment' using errcode='22023';end if;
 select c.post_id,t.author_id into pid,post_author from public.lga_post_comments c join public.lga_text_posts t on t.id=c.post_id where c.id=p_comment_id and c.author_id=u;
 if pid is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,post_author) order by p.user_id for update;
 perform 1 from public.lga_text_posts t where t.id=pid for update;
 perform 1 from public.lga_post_comments c where c.id=p_comment_id and c.author_id=u and c.status='active' for update;
 if not found or not app_private.can_view_lga_post(u,pid)
 or exists(select 1 from public.user_reports r where r.reported_lga_comment_id=p_comment_id) then
  raise exception 'Action not permitted' using errcode='42501';
 end if;
 update public.lga_post_comments set body=clean,edited_at=pg_catalog.now() where id=p_comment_id;
end; $$;
revoke all on function public.edit_own_lga_post_comment(uuid,text) from public,anon,authenticated;
grant execute on function public.edit_own_lga_post_comment(uuid,text) to authenticated;

drop function public.list_lga_post_comments(uuid,timestamptz,uuid);
create function public.list_lga_post_comments(p_post_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz,edited_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select c.id,c.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),c.body,c.created_at,c.edited_at
 from public.lga_post_comments c join public.profiles p on p.user_id=c.author_id join public.lga_text_posts t on t.id=c.post_id
 where c.post_id=p_post_id and c.status='active' and p.lga_id=t.lga_id and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 and (p_before is null or (c.created_at,c.id)<(p_before,p_before_id)) order by c.created_at desc,c.id desc limit 30;
end; $$;
revoke all on function public.list_lga_post_comments(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_lga_post_comments(uuid,timestamptz,uuid) to authenticated;
