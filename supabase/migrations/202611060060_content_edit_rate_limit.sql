-- Provisional local-only abuse control: 20 successful text edits per user per
-- rolling hour across LGA/group posts and comments. This is not comprehensive
-- abuse prevention, approved retention policy or permission for public launch.
create table app_private.content_edit_events(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default pg_catalog.clock_timestamp()
);
create index content_edit_events_user_time_idx on app_private.content_edit_events(user_id,created_at);
alter table app_private.content_edit_events enable row level security;
revoke all on app_private.content_edit_events from public,anon,authenticated;

-- Call only after locking this user's profile and validating edit permission.
-- Self-lock again defensively. Events contain no content or target identity;
-- same-user edits serialize on the profile, so parallel requests share a cap.
create function app_private.record_content_edit(p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz;
begin
 if p_user_id is null or auth.uid() is distinct from p_user_id then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=p_user_id for update;
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 t:=pg_catalog.clock_timestamp();
 delete from app_private.content_edit_events e where e.user_id=p_user_id and e.created_at<=t-interval '1 hour';
 if (select pg_catalog.count(*) from app_private.content_edit_events e where e.user_id=p_user_id and e.created_at>t-interval '1 hour')>=20 then
  raise exception 'Please try again later' using errcode='P0001';
 end if;
 insert into app_private.content_edit_events(user_id,created_at) values(p_user_id,t);
end; $$;
revoke all on function app_private.record_content_edit(uuid) from public,anon,authenticated;

create or replace function public.edit_own_lga_text_post(p_post_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();clean text:=pg_catalog.btrim(p_body);
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 perform 1 from public.lga_text_posts t where t.id=p_post_id and t.author_id=u and t.status='active' for update;
 if not found or not app_private.can_view_lga_post(u,p_post_id) or exists(select 1 from public.user_reports r where r.reported_lga_post_id=p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform app_private.record_content_edit(u);
 update public.lga_text_posts set body=clean,edited_at=pg_catalog.now() where id=p_post_id;
end; $$;

create or replace function public.edit_own_private_group_text_post(p_post_id uuid,p_body text)
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
 perform app_private.record_content_edit(u);
 update public.private_group_text_posts set body=clean,edited_at=pg_catalog.now() where id=p_post_id;
end; $$;

create or replace function public.edit_own_private_group_post_comment(p_comment_id uuid,p_body text)
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
 perform app_private.record_content_edit(u);
 update public.private_group_post_comments set body=clean,edited_at=pg_catalog.now() where id=p_comment_id;
end; $$;

create or replace function public.edit_own_lga_post_comment(p_comment_id uuid,p_body text)
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
 perform app_private.record_content_edit(u);
 update public.lga_post_comments set body=clean,edited_at=pg_catalog.now() where id=p_comment_id;
end; $$;

