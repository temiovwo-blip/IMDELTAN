-- Development-only report triage. Closing a report does not hide the item.
-- Removal uses separate explicit MFA-gated actions in migrations 034/039.
create function public.review_lga_content_report(p_report_id uuid,p_new_status text,p_justification text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); prior text; why text:=pg_catalog.btrim(p_justification);
begin
 if not app_private.current_user_can_review_reports() then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_report_id is null or p_new_status is null or p_new_status not in ('reviewing','closed') or why is null or pg_catalog.length(why) not between 1 and 4000 then raise exception 'Invalid review' using errcode='22023';end if;
 select r.status into prior from public.user_reports r where r.id=p_report_id and (r.reported_lga_post_id is not null or r.reported_lga_comment_id is not null) for update;
 if not found or prior='closed' or prior=p_new_status then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.user_reports r set status=p_new_status where r.id=p_report_id;
 insert into public.moderation_records(report_id,actor_id,action,justification) values(p_report_id,u,'lga_report_'||p_new_status,why);
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'lga_report_'||p_new_status,'user_report',p_report_id::text,'success');
end; $$;
revoke all on function public.review_lga_content_report(uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_lga_content_report(uuid,text,text) to authenticated;
