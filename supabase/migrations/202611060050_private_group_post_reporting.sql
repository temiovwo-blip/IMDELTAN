-- Local development only. Reporting and moderation for private group posts.
-- No appeals, retention schedule, launch approval or full moderation program.
alter table public.user_reports add column reported_private_group_post_id uuid references public.private_group_text_posts(id) on delete restrict;
alter table public.user_reports drop constraint user_reports_exactly_one_target_check;
alter table public.user_reports add constraint user_reports_exactly_one_target_check check
 (pg_catalog.num_nonnulls(reported_user_id,reported_post_id,reported_comment_id,reported_lga_post_id,reported_lga_comment_id,reported_direct_message_id,reported_private_group_post_id)=1);
create index user_reports_private_group_post_idx on public.user_reports(reported_private_group_post_id) where reported_private_group_post_id is not null;
create unique index user_reports_one_open_private_group_post_idx on public.user_reports(reporter_id,reported_private_group_post_id)
 where reporter_id is not null and reported_private_group_post_id is not null and status in ('open','reviewing');

create function public.report_private_group_text_post(p_post_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); author uuid;owner_id uuid;gid uuid;why text:=pg_catalog.btrim(p_reason);n int;result uuid;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if why is null or pg_catalog.length(why) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 select t.author_id,t.group_id,g.created_by into author,gid,owner_id from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id where t.id=p_post_id;
 if author is null or author=u then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author,owner_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=gid for update;
 perform 1 from public.private_group_text_posts t where t.id=p_post_id for update;
 if not app_private.can_access_private_group_feed(u,gid) or not app_private.user_passes_platform_gate(author)
 or not exists(select 1 from public.private_group_text_posts t join public.community_groups g on g.id=t.group_id join public.profiles p on p.user_id=t.author_id join public.community_group_memberships m on m.group_id=g.id and m.user_id=t.author_id and m.status='active' where t.id=p_post_id and t.status='active' and p.lga_id=g.lga_id)
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=author) or (b.blocker_id=author and b.blocked_id=u)) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_private_group_post_id,reason) values(u,p_post_id,why)
 on conflict(reporter_id,reported_private_group_post_id) where reporter_id is not null and reported_private_group_post_id is not null and status in ('open','reviewing') do nothing returning id into result;
 return result;
end; $$;

-- Retain reported post text for review even if its author subsequently deletes
-- it; unreported posts are redacted. Both cases may persist in backups.
create or replace function public.delete_own_private_group_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.private_group_text_posts t where t.id=p_post_id and t.author_id=u and t.status='active' for update;
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_text_posts t set status='deleted',body=case when exists(select 1 from public.user_reports r where r.reported_private_group_post_id=t.id) then t.body else '[deleted]' end,deleted_at=pg_catalog.now() where t.id=p_post_id;
end; $$;

create function public.list_private_group_post_reports_for_review()
returns table(report_id uuid,reporter_id uuid,post_id uuid,group_id uuid,author_id uuid,post_body text,post_status text,reason text,report_status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,t.id,t.group_id,t.author_id,t.body,t.status,r.reason,r.status,r.created_at from public.user_reports r
 join public.private_group_text_posts t on t.id=r.reported_private_group_post_id where r.status in ('open','reviewing') order by r.created_at,r.id limit 50;
end; $$;
create function public.review_private_group_post_report(p_report_id uuid,p_new_status text,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();prior text;why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or p_new_status is null or p_new_status not in ('reviewing','closed') or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.status into prior from public.user_reports r where r.id=p_report_id and r.reported_private_group_post_id is not null for update;
 if not found or prior='closed' or prior=p_new_status then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports set status=p_new_status where id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'group_post_report_'||p_new_status,why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'group_post_report_'||p_new_status,'user_report',p_report_id::text,'success');
end; $$;
create function public.remove_reported_private_group_post(p_report_id uuid,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();pid uuid;why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.reported_private_group_post_id into pid from public.user_reports r where r.id=p_report_id and r.status in ('open','reviewing') and r.reported_private_group_post_id is not null for update;
 if pid is null then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.private_group_text_posts set status='removed' where id=pid and status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports set status='closed' where id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'private_group_post_removed',why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'private_group_post_removed','private_group_text_post',pid::text,'success');
end; $$;
revoke all on function public.report_private_group_text_post(uuid,text),public.list_private_group_post_reports_for_review(),public.review_private_group_post_report(uuid,text,text),public.remove_reported_private_group_post(uuid,text) from public,anon,authenticated;
grant execute on function public.report_private_group_text_post(uuid,text),public.list_private_group_post_reports_for_review(),public.review_private_group_post_report(uuid,text,text),public.remove_reported_private_group_post(uuid,text) to authenticated;

-- Keep group-post reports out of generic user-report actions.
create or replace function public.list_reports_for_review()
returns table(id uuid,reporter_id uuid,reported_user_id uuid,reason text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
 from public.user_reports r where r.status in ('open','reviewing') and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null and r.reported_private_group_post_id is null
 order by r.created_at,r.id limit 50;
end; $$;




-- Keep group-post reports out of generic user-report actions.
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
  select r.status into previous_status from public.user_reports r where r.id=p_report_id and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null and r.reported_private_group_post_id is null for update;
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
