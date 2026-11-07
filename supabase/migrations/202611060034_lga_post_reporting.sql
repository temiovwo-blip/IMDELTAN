-- Development draft: report an in-scope LGA text post and allow MFA-protected
-- moderators to remove it. Requires real-service security and operations review.
alter table public.user_reports add column reported_lga_post_id uuid references public.lga_text_posts(id) on delete restrict;
-- Drop only the original one-target check, verifying it is uniquely identified.
do $$
declare check_name text; matches int;
begin
 select count(*),min(c.conname) into matches,check_name from pg_catalog.pg_constraint c
 where c.conrelid='public.user_reports'::regclass and c.contype='c'
 and pg_catalog.pg_get_constraintdef(c.oid) like '%num_nonnulls%';
 if matches<>1 then raise exception 'Unexpected report target constraints';end if;
 execute pg_catalog.format('alter table public.user_reports drop constraint %I',check_name);
end; $$;
alter table public.user_reports add constraint user_reports_exactly_one_target_check
 check (pg_catalog.num_nonnulls(reported_user_id,reported_post_id,reported_comment_id,reported_lga_post_id)=1);
create index user_reports_lga_post_idx on public.user_reports(reported_lga_post_id) where reported_lga_post_id is not null;
create unique index user_reports_one_open_lga_post_per_reporter_idx on public.user_reports(reporter_id,reported_lga_post_id)
 where reporter_id is not null and reported_lga_post_id is not null and status in ('open','reviewing');

create function public.report_lga_text_post(p_post_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); l uuid; target public.lga_text_posts%rowtype; reason_clean text:=pg_catalog.btrim(p_reason); result_id uuid; recent int;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select p.lga_id into l from public.profiles p where p.user_id=u for update;
 if l is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if reason_clean is null or pg_catalog.length(reason_clean) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 select * into target from public.lga_text_posts t where t.id=p_post_id and t.status='active' for update;
 if not found or target.author_id=u or target.lga_id<>l
  or not app_private.user_passes_platform_gate(target.author_id)
  or not exists(select 1 from public.profiles p where p.user_id=target.author_id and p.lga_id=l)
  or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=target.author_id) or (b.blocker_id=target.author_id and b.blocked_id=u)) then
  raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into recent from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if recent>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_lga_post_id,reason) values(u,p_post_id,reason_clean)
 on conflict (reporter_id,reported_lga_post_id) where reporter_id is not null and reported_lga_post_id is not null and status in ('open','reviewing')
 do nothing returning id into result_id;
 -- Do not expose the existing report ID to callers.
 return result_id;
end; $$;

create function public.list_lga_post_reports_for_review()
returns table(report_id uuid,reporter_id uuid,post_id uuid,author_id uuid,post_body text,post_status text,reason text,report_status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,t.id,t.author_id,t.body,t.status,r.reason,r.status,r.created_at
 from public.user_reports r join public.lga_text_posts t on t.id=r.reported_lga_post_id
 where r.status in ('open','reviewing') order by r.created_at,r.id limit 50;
end; $$;

create function public.remove_reported_lga_text_post(p_report_id uuid,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p uuid; why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.reported_lga_post_id into p from public.user_reports r where r.id=p_report_id and r.status in ('open','reviewing') and r.reported_lga_post_id is not null for update;
 if p is null then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_text_posts t set status='removed' where t.id=p and t.status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports r set status='closed' where r.id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'lga_post_removed',why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'lga_post_removed','lga_text_post',p::text,'success');
end; $$;
revoke all on function public.report_lga_text_post(uuid,text),public.list_lga_post_reports_for_review(),public.remove_reported_lga_text_post(uuid,text) from public,anon,authenticated;
grant execute on function public.report_lga_text_post(uuid,text),public.list_lga_post_reports_for_review(),public.remove_reported_lga_text_post(uuid,text) to authenticated;
-- Keep the existing user-report queue from presenting LGA reports as user reports.
create or replace function public.list_reports_for_review()
returns table(id uuid,reporter_id uuid,reported_user_id uuid,reason text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
 from public.user_reports r where r.status in ('open','reviewing') and r.reported_lga_post_id is null
 order by r.created_at,r.id limit 50;
end; $$;

-- The old user-report review action must not close an LGA post report.
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
  select r.status into previous_status from public.user_reports r where r.id=p_report_id and r.reported_lga_post_id is null for update;
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
