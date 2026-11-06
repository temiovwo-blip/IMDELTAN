-- Draft owner-only group maintenance; not a full group administration system.
alter table public.community_groups add column updated_at timestamptz not null default pg_catalog.now();
create function public.update_own_group(p_group_id uuid,p_name text,p_description text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); clean_name text:=pg_catalog.btrim(p_name); clean_description text:=pg_catalog.btrim(p_description);
begin
 if u is null or p_group_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not found or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
 if clean_name is null or pg_catalog.length(clean_name) not between 1 and 120 or clean_description is null or pg_catalog.length(clean_description)>1000 then
   raise exception 'Invalid group details' using errcode='22023'; end if;
 update public.community_groups g set name=clean_name,description=clean_description,updated_at=pg_catalog.now()
 where g.id=p_group_id and g.created_by=u and g.status='active' and exists(
   select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active');
 if not found then raise exception 'Action not permitted' using errcode='42501'; end if;
end; $$;
create function public.archive_own_group(p_group_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_group_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not found or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
 -- Archiving hides the group from the own-created list; it is not deletion.
 update public.community_groups g set status='archived',updated_at=pg_catalog.now()
 where g.id=p_group_id and g.created_by=u and g.status='active' and exists(
   select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active');
 if not found then raise exception 'Action not permitted' using errcode='42501'; end if;
end; $$;
revoke all on function public.update_own_group(uuid,text,text) from public,anon,authenticated;
revoke all on function public.archive_own_group(uuid) from public,anon,authenticated;
grant execute on function public.update_own_group(uuid,text,text) to authenticated;
grant execute on function public.archive_own_group(uuid) to authenticated;
-- Recovery, deletion/retention, ownership transfer, notifications, direct API
-- review and moderator permissions remain outside this draft.
