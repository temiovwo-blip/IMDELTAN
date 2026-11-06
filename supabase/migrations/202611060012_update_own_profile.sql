-- Draft: controlled, self-only profile edits; no table UPDATE grant.
-- Not activated until full API, race-condition and security review.
create function public.update_own_profile(p_handle text, p_display_name text, p_biography text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  clean_handle text := pg_catalog.lower(pg_catalog.btrim(p_handle));
  clean_name text := pg_catalog.btrim(p_display_name);
  clean_biography text := pg_catalog.btrim(p_biography);
begin
  if current_user_id is null then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  -- Serialize profile-state changes with this operation.
  perform 1 from public.profiles p where p.user_id = current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode = '42501';
  end if;
  if clean_handle is null or clean_handle !~ '^[a-z0-9_]{3,30}$'
    or clean_name is null or pg_catalog.length(clean_name) not between 1 and 80
    or (clean_biography is not null and pg_catalog.length(clean_biography) > 500) then
    raise exception 'Invalid profile details' using errcode = '22023';
  end if;
  update public.profiles p
    set handle = clean_handle, display_name = clean_name,
        biography = clean_biography, updated_at = pg_catalog.now()
    where p.user_id = current_user_id;
end;
$$;
revoke all on function public.update_own_profile(text,text,text) from public, anon, authenticated;
grant execute on function public.update_own_profile(text,text,text) to authenticated;
-- No editable administrative, eligibility, identity, or consent fields.
-- Verify handle conflicts, abuse controls and concurrent policy updates before use.
