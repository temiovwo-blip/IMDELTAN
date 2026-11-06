-- Draft reporting and limited admin review, not a complete moderation system.
-- All methods remain subject to security review, abuse controls and direct API tests.
create function public.report_user(p_target_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  current_user_id uuid := auth.uid();
  clean_reason text := pg_catalog.btrim(p_reason);
  new_report_id uuid;
begin
  if current_user_id is null or p_target_id is null or p_target_id = current_user_id then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  perform 1 from public.profiles p where p.user_id=current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  if clean_reason is null or pg_catalog.length(clean_reason) not between 1 and 2000 then
    raise exception 'Invalid report' using errcode='22023';
  end if;
  if not exists(select 1 from public.profiles p where p.user_id=p_target_id and p.account_state='active') then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  insert into public.user_reports(reporter_id,reported_user_id,reason)
    values(current_user_id,p_target_id,clean_reason) returning id into new_report_id;
  return new_report_id;
end;
$$;
revoke all on function public.report_user(uuid,text) from public, anon, authenticated;
grant execute on function public.report_user(uuid,text) to authenticated;

create function app_private.current_user_can_review_reports()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
    and coalesce(auth.jwt()->>'aal','') = 'aal2'
    and app_private.user_passes_platform_gate(auth.uid())
    and exists(select 1 from public.admin_role_assignments a
      join public.admin_roles r on r.id=a.role_id
      where a.user_id=auth.uid() and r.role_key in ('moderator','administrator'));
$$;
revoke all on function app_private.current_user_can_review_reports() from public, anon, authenticated;

create function public.list_reports_for_review()
returns table(id uuid, reporter_id uuid, reported_user_id uuid, reason text, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app_private.current_user_can_review_reports() then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  return query select r.id,r.reporter_id,r.reported_user_id,r.reason,r.status,r.created_at
    from public.user_reports r where r.status in ('open','reviewing')
    order by r.created_at,r.id limit 50;
end;
$$;
revoke all on function public.list_reports_for_review() from public, anon, authenticated;
grant execute on function public.list_reports_for_review() to authenticated;

create function public.review_user_report(p_report_id uuid, p_new_status text, p_justification text)
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
  select r.status into previous_status from public.user_reports r where r.id=p_report_id for update;
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
revoke all on function public.review_user_report(uuid,text,text) from public, anon, authenticated;
grant execute on function public.review_user_report(uuid,text,text) to authenticated;
-- Only records review decisions; does not suspend users, remove content, enforce
-- blocks or record failed attempts. Monitor abuse and protect audit retention.
