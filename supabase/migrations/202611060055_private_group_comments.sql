-- Local-only group comments and reporting. No replies, media, public release,
-- legal retention policy or complete moderation operations are provided.
create table public.private_group_post_comments(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.private_group_text_posts(id) on delete restrict,
 author_id uuid not null references auth.users(id) on delete restrict,
 body text not null check(pg_catalog.length(pg_catalog.btrim(body)) between 1 and 2000),
 status text not null default 'active' check(status in ('active','deleted','removed')),
 created_at timestamptz not null default pg_catalog.now(),
 deleted_at timestamptz
);
create index private_group_comments_post_idx on public.private_group_post_comments(post_id,created_at desc,id desc) where status='active';
create index private_group_comments_author_idx on public.private_group_post_comments(author_id,created_at desc);
alter table public.private_group_post_comments enable row level security;
revoke all on public.private_group_post_comments from public,anon,authenticated;
alter table public.user_reports add column reported_private_group_comment_id uuid references public.private_group_post_comments(id) on delete restrict;
alter table public.user_reports drop constraint user_reports_exactly_one_target_check;
alter table public.user_reports add constraint user_reports_exactly_one_target_check check
 (pg_catalog.num_nonnulls(reported_user_id,reported_post_id,reported_comment_id,reported_lga_post_id,reported_lga_comment_id,reported_direct_message_id,reported_private_group_post_id,reported_private_group_comment_id)=1);
create index user_reports_private_group_comment_idx on public.user_reports(reported_private_group_comment_id) where reported_private_group_comment_id is not null;
create unique index user_reports_one_open_private_group_comment_idx on public.user_reports(reporter_id,reported_private_group_comment_id)
 where reporter_id is not null and reported_private_group_comment_id is not null and status in ('open','reviewing');

create function public.create_private_group_post_comment(p_post_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();author uuid;owner_id uuid;gid uuid;clean text:=pg_catalog.btrim(p_body);n int;result uuid;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 2000 then raise exception 'Invalid comment' using errcode='22023';end if;
 select t.author_id,t.group_id,g.created_by into author,gid,owner_id from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=p_post_id for update;
 if not app_private.can_view_private_group_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.private_group_post_comments c where c.author_id=u and c.created_at>pg_catalog.now()-interval '1 hour';
 if n>=20 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.private_group_post_comments(post_id,author_id,body) values(p_post_id,u,clean) returning id into result;return result;
end; $$;
create function public.list_private_group_post_comments(p_post_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if not app_private.can_view_private_group_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select c.id,c.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),c.body,c.created_at
 from public.private_group_post_comments c join public.profiles p on p.user_id=c.author_id
 where c.post_id=p_post_id and c.status='active' and app_private.can_view_private_group_post(c.author_id,p_post_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=c.author_id) or (b.blocker_id=c.author_id and b.blocked_id=u))
 and (p_before is null or (c.created_at,c.id)<(p_before,p_before_id)) order by c.created_at desc,c.id desc limit 30;
end; $$;
create function public.delete_own_private_group_post_comment(p_comment_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.private_group_post_comments c where c.id=p_comment_id and c.author_id=u and c.status='active' for update;
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_post_comments c set status='deleted',body=case when exists(select 1 from public.user_reports r where r.reported_private_group_comment_id=c.id) then c.body else '[deleted]' end,deleted_at=pg_catalog.now() where c.id=p_comment_id;
end; $$;
create function public.report_private_group_post_comment(p_comment_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();commenter uuid;post_author uuid;owner_id uuid;gid uuid;pid uuid;why text:=pg_catalog.btrim(p_reason);n int;result uuid;
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if why is null or pg_catalog.length(why) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 select c.author_id,t.author_id,g.created_by,g.id,t.id into commenter,post_author,owner_id,gid,pid from public.private_group_post_comments c join public.private_group_text_posts t on t.id=c.post_id join public.community_groups g on g.id=t.group_id where c.id=p_comment_id;
 if commenter is null or commenter=u then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,commenter,post_author,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=pid for update;
 perform 1 from public.private_group_post_comments c where c.id=p_comment_id for update;
 if not app_private.can_view_private_group_post(u,pid) or not app_private.can_view_private_group_post(commenter,pid)
 or not exists(select 1 from public.private_group_post_comments c where c.id=p_comment_id and c.status='active')
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=commenter) or (b.blocker_id=commenter and b.blocked_id=u)) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_private_group_comment_id,reason) values(u,p_comment_id,why)
 on conflict(reporter_id,reported_private_group_comment_id) where reporter_id is not null and reported_private_group_comment_id is not null and status in ('open','reviewing') do nothing returning id into result;return result;
end; $$;
create function public.list_private_group_comment_reports_for_review()
returns table(report_id uuid,reporter_id uuid,comment_id uuid,post_id uuid,author_id uuid,comment_body text,comment_status text,reason text,report_status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,c.id,c.post_id,c.author_id,c.body,c.status,r.reason,r.status,r.created_at
 from public.user_reports r join public.private_group_post_comments c on c.id=r.reported_private_group_comment_id where r.status in ('open','reviewing') order by r.created_at,r.id limit 50;
end; $$;
create function public.review_private_group_comment_report(p_report_id uuid,p_new_status text,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();prior text;why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or p_new_status is null or p_new_status not in ('reviewing','closed') or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.status into prior from public.user_reports r where r.id=p_report_id and r.reported_private_group_comment_id is not null for update;
 if not found or prior='closed' or prior=p_new_status then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports set status=p_new_status where id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'group_comment_report_'||p_new_status,why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'group_comment_report_'||p_new_status,'user_report',p_report_id::text,'success');
end; $$;
create function public.remove_reported_private_group_comment(p_report_id uuid,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();cid uuid;why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.reported_private_group_comment_id into cid from public.user_reports r where r.id=p_report_id and r.status in ('open','reviewing') and r.reported_private_group_comment_id is not null for update;
 if cid is null then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_post_comments set status='removed' where id=cid and status='active';if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports set status='closed' where id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'private_group_comment_removed',why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'private_group_comment_removed','private_group_post_comment',cid::text,'success');
end; $$;
revoke all on function public.create_private_group_post_comment(uuid,text),public.list_private_group_post_comments(uuid,timestamptz,uuid),public.delete_own_private_group_post_comment(uuid),public.report_private_group_post_comment(uuid,text),public.list_private_group_comment_reports_for_review(),public.review_private_group_comment_report(uuid,text,text),public.remove_reported_private_group_comment(uuid,text) from public,anon,authenticated;
grant execute on function public.create_private_group_post_comment(uuid,text),public.list_private_group_post_comments(uuid,timestamptz,uuid),public.delete_own_private_group_post_comment(uuid),public.report_private_group_post_comment(uuid,text),public.list_private_group_comment_reports_for_review(),public.review_private_group_comment_report(uuid,text,text),public.remove_reported_private_group_comment(uuid,text) to authenticated;

-- Keep group comment reports out of generic user-report actions.
create or replace function public.list_reports_for_review()
returns table(id uuid,reporter_id uuid,reported_user_id uuid,reason text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
 from public.user_reports r where r.status in ('open','reviewing') and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null and r.reported_private_group_post_id is null and r.reported_private_group_comment_id is null
 order by r.created_at,r.id limit 50;
end; $$;





-- Keep group comment reports out of generic user-report actions.
create or replace function public.review_user_report(p_report_id uuid, p_new_status text, p_justification text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  current_user_id uuid := auth.uid();
  clean_justification text := pg_catalog.btrim(p_justification);
  previous_status text;
begin
  if not app_private.current_user_can_review_reports() then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  if p_report_id is null or p_new_status is null or p_new_status not in ('reviewing','closed')
     or clean_justification is null or pg_catalog.length(clean_justification) not between 1 and 4000 then
    raise exception 'Invalid review' using errcode='22023';
  end if;
  select r.status into previous_status from public.user_reports r where r.id=p_report_id and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null and r.reported_private_group_post_id is null and r.reported_private_group_comment_id is null for update;
  if not found or previous_status = 'closed' or previous_status = p_new_status then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  update public.user_reports set status=p_new_status where id=p_report_id;
  insert into public.moderation_records(report_id,actor_id,action,justification)
    values(p_report_id,current_user_id,p_new_status,clean_justification);
  insert into public.audit_logs(actor_id,action,target_type,target_id,outcome)
    values(current_user_id,'report_reviewed','user_report',p_report_id::text,'success');
end;
$$;
