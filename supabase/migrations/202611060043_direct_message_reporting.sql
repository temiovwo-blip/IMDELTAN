-- Development only. Reporting exposes ONLY the selected message and reason to
-- role/MFA-authorized moderators; direct messages are NOT end-to-end encrypted.
-- Blocking/unfriending does not prevent a recipient from reporting a message.
alter table public.user_reports add column reported_direct_message_id uuid references public.messages(id) on delete restrict;
alter table public.user_reports drop constraint user_reports_exactly_one_target_check;
alter table public.user_reports add constraint user_reports_exactly_one_target_check check
 (pg_catalog.num_nonnulls(reported_user_id,reported_post_id,reported_comment_id,reported_lga_post_id,reported_lga_comment_id,reported_direct_message_id)=1);
create index user_reports_direct_message_idx on public.user_reports(reported_direct_message_id) where reported_direct_message_id is not null;
create unique index user_reports_one_open_direct_message_per_reporter_idx on public.user_reports(reporter_id,reported_direct_message_id)
 where reporter_id is not null and reported_direct_message_id is not null and status in ('open','reviewing');

create function public.report_received_friend_message(p_message_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); msg public.messages%rowtype; why text:=pg_catalog.btrim(p_reason); result uuid;n int;
begin
 if u is null or p_message_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if why is null or pg_catalog.length(why) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 -- The reporter lock serializes report limits. Do not depend on a friendship or
 -- block relationship: a recipient must be able to report after blocking.
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select m.* into msg from public.messages m where m.id=p_message_id for update;
 if not found or msg.deleted_at is not null or msg.sender_id=u
 or not exists(select 1 from app_private.direct_conversation_pairs pair where pair.conversation_id=msg.conversation_id and u in(pair.user_low,pair.user_high) and msg.sender_id in(pair.user_low,pair.user_high))
 or not exists(select 1 from public.conversation_participants cp where cp.conversation_id=msg.conversation_id and cp.user_id=u) then
  raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into n from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if n>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_direct_message_id,reason) values(u,p_message_id,why)
 on conflict(reporter_id,reported_direct_message_id) where reporter_id is not null and reported_direct_message_id is not null and status in ('open','reviewing') do nothing returning id into result;
 return result;
end; $$;

create function public.list_direct_message_reports_for_review()
returns table(report_id uuid,reporter_id uuid,message_id uuid,sender_id uuid,message_body text,reason text,report_status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,m.id,m.sender_id,m.body,r.reason,r.status,r.created_at from public.user_reports r
 join public.messages m on m.id=r.reported_direct_message_id where r.status in ('open','reviewing') order by r.created_at,r.id limit 50;
end; $$;

create function public.review_direct_message_report(p_report_id uuid,p_new_status text,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); prior text; why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or p_new_status is null or p_new_status not in ('reviewing','closed') or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.status into prior from public.user_reports r where r.id=p_report_id and r.reported_direct_message_id is not null for update;
 if not found or prior='closed' or prior=p_new_status then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports set status=p_new_status where id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'direct_message_report_'||p_new_status,why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'direct_message_report_'||p_new_status,'user_report',p_report_id::text,'success');
end; $$;
revoke all on function public.report_received_friend_message(uuid,text),public.list_direct_message_reports_for_review(),public.review_direct_message_report(uuid,text,text) from public,anon,authenticated;
grant execute on function public.report_received_friend_message(uuid,text),public.list_direct_message_reports_for_review(),public.review_direct_message_report(uuid,text,text) to authenticated;

-- Keep private-message reports out of the generic user-report queue.
create or replace function public.list_reports_for_review()
returns table(id uuid,reporter_id uuid,reported_user_id uuid,reason text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
 from public.user_reports r where r.status in ('open','reviewing') and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null
 order by r.created_at,r.id limit 50;
end; $$;



-- Keep private-message reports out of the generic user-report queue.
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
  select r.status into previous_status from public.user_reports r where r.id=p_report_id and r.reported_lga_post_id is null and r.reported_lga_comment_id is null and r.reported_direct_message_id is null for update;
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
