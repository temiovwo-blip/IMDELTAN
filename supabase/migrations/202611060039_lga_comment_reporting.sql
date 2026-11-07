-- Development draft only. Report and moderate LGA comments. No automatic
-- takedown, appeals, retention policy or production-readiness claim.
alter table public.user_reports add column reported_lga_comment_id uuid references public.lga_post_comments(id) on delete restrict;
alter table public.user_reports drop constraint user_reports_exactly_one_target_check;
alter table public.user_reports add constraint user_reports_exactly_one_target_check
 check(pg_catalog.num_nonnulls(reported_user_id,reported_post_id,reported_comment_id,reported_lga_post_id,reported_lga_comment_id)=1);
create index user_reports_lga_comment_idx on public.user_reports(reported_lga_comment_id) where reported_lga_comment_id is not null;
create unique index user_reports_one_open_lga_comment_per_reporter_idx on public.user_reports(reporter_id,reported_lga_comment_id)
 where reporter_id is not null and reported_lga_comment_id is not null and status in ('open','reviewing');

create function public.report_lga_post_comment(p_comment_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); commenter uuid; post_id uuid; post_author uuid; why text:=pg_catalog.btrim(p_reason); result uuid; n int;
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if why is null or pg_catalog.length(why) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 select c.author_id,c.post_id,t.author_id into commenter,post_id,post_author from public.lga_post_comments c join public.lga_text_posts t on t.id=c.post_id where c.id=p_comment_id;
 if commenter is null or commenter=u then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,commenter,post_author) order by p.user_id for update;
 perform 1 from public.lga_text_posts t where t.id=post_id for update;
 perform 1 from public.lga_post_comments c where c.id=p_comment_id for update;
 if not app_private.can_view_lga_post(u,post_id) or not app_private.user_passes_platform_gate(commenter)
 or not exists(select 1 from public.lga_post_comments c join public.profiles p on p.user_id=c.author_id join public.lga_text_posts t on t.id=c.post_id where c.id=p_comment_id and c.status='active' and p.lga_id=t.lga_id)
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=commenter) or (b.blocker_id=commenter and b.blocked_id=u)) then raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_lga_comment_id,reason) values(u,p_comment_id,why)
 on conflict (reporter_id,reported_lga_comment_id) where reporter_id is not null and reported_lga_comment_id is not null and status in ('open','reviewing') do nothing returning id into result;
 return result;
end; $$;

create function public.list_lga_comment_reports_for_review()
returns table(report_id uuid,reporter_id uuid,comment_id uuid,post_id uuid,author_id uuid,comment_body text,comment_status text,reason text,report_status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,c.id,c.post_id,c.author_id,c.body,c.status,r.reason,r.status,r.created_at
 from public.user_reports r join public.lga_post_comments c on c.id=r.reported_lga_comment_id
 where r.status in ('open','reviewing') order by r.created_at,r.id limit 50;
end; $$;

create function public.remove_reported_lga_post_comment(p_report_id uuid,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); comment_id uuid; why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.reported_lga_comment_id into comment_id from public.user_reports r where r.id=p_report_id and r.status in ('open','reviewing') and r.reported_lga_comment_id is not null for update;
 if comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_post_comments c set status='removed' where c.id=comment_id and c.status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports r set status='closed' where r.id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'lga_comment_removed',why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'lga_comment_removed','lga_post_comment',comment_id::text,'success');
end; $$;
revoke all on function public.report_lga_post_comment(uuid,text),public.list_lga_comment_reports_for_review(),public.remove_reported_lga_post_comment(uuid,text) from public,anon,authenticated;
grant execute on function public.report_lga_post_comment(uuid,text),public.list_lga_comment_reports_for_review(),public.remove_reported_lga_post_comment(uuid,text) to authenticated;

-- Keep comment reports out of legacy user-report actions.
create or replace function public.list_reports_for_review()
returns table(id uuid,reporter_id uuid,reported_user_id uuid,reason text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
 from public.user_reports r where r.status in ('open','reviewing') and r.reported_lga_post_id is null and r.reported_lga_comment_id is null
 order by r.created_at,r.id limit 50;
end; $$;


-- Keep comment reports out of legacy user-report actions.
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
  select r.status into previous_status from public.user_reports r where r.id=p_report_id and r.reported_lga_post_id is null and r.reported_lga_comment_id is null for update;
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
