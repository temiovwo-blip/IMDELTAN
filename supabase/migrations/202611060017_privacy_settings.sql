-- Draft privacy preferences. Other-user visibility and block policies do not yet exist.
-- These functions do not grant direct table access or make profiles public.
create function public.get_own_privacy_settings()
returns table (profile_visibility text, contact_permission text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  return query select s.profile_visibility, s.contact_permission
    from public.user_privacy_settings s where s.user_id = current_user_id;
end;
$$;
revoke all on function public.get_own_privacy_settings() from public, anon, authenticated;
grant execute on function public.get_own_privacy_settings() to authenticated;

create function public.update_own_privacy_settings(p_profile_visibility text, p_contact_permission text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  perform 1 from public.profiles p where p.user_id = current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  if p_profile_visibility is null or p_profile_visibility not in ('private','friends','public')
    or p_contact_permission is null or p_contact_permission not in ('nobody','friends','members') then
    raise exception 'Invalid privacy settings' using errcode = '22023';
  end if;
  update public.user_privacy_settings s
    set profile_visibility = p_profile_visibility, contact_permission = p_contact_permission,
        updated_at = pg_catalog.now()
    where s.user_id = current_user_id;
  if not found then raise exception 'Action not permitted' using errcode = '42501'; end if;
end;
$$;
revoke all on function public.update_own_privacy_settings(text,text) from public, anon, authenticated;
grant execute on function public.update_own_privacy_settings(text,text) to authenticated;
-- Security review, rate limits, concurrency tests, API tests and full enforcement
-- across content, search and messaging are required before enabling this feature.
