-- Draft: self-only list and leave for accepted group members.
-- No group discovery, group contents, or other-member listing is granted.
create function public.list_own_joined_groups(p_before timestamptz default null,p_before_id uuid default null)
returns table (id uuid,lga_name text,name text,description text,joined_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select g.id,l.name,g.name,g.description,m.joined_at
 from public.community_group_memberships m
 join public.community_groups g on g.id=m.group_id
 join public.lgas l on l.id=g.lga_id
 join public.profiles p on p.user_id=u
 join public.community_group_memberships owner_m on owner_m.group_id=g.id and owner_m.user_id=g.created_by and owner_m.role='owner' and owner_m.status='active'
 where m.user_id=u and m.role='member' and m.status='active' and g.status='active'
  and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(g.created_by)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=g.created_by) or (b.blocker_id=g.created_by and b.blocked_id=u))
  and (p_before is null or (m.joined_at,g.id)<(p_before,p_before_id))
 order by m.joined_at desc,g.id desc limit 25;
end; $$;
-- Redacted entries let a person leave groups that became unavailable because
-- of blocks, owner status, an archive, or an LGA change, without exposing names.
create function public.list_own_unavailable_group_memberships(p_before timestamptz default null,p_before_id uuid default null)
returns table (id uuid,joined_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select g.id,m.joined_at from public.community_group_memberships m
 join public.community_groups g on g.id=m.group_id join public.profiles p on p.user_id=u
 where m.user_id=u and m.role='member' and m.status='active' and (
  g.status<>'active' or p.lga_id is distinct from g.lga_id or not app_private.user_passes_platform_gate(g.created_by)
  or not exists(select 1 from public.community_group_memberships om where om.group_id=g.id and om.user_id=g.created_by and om.role='owner' and om.status='active')
  or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=g.created_by) or (b.blocker_id=g.created_by and b.blocked_id=u)))
  and (p_before is null or (m.joined_at,g.id)<(p_before,p_before_id))
 order by m.joined_at desc,g.id desc limit 25;
end; $$;
create function public.leave_joined_group(p_group_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); owner_id uuid;
begin
 if u is null or p_group_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Bind the row to the caller before attempting to identify the owner.
 select g.created_by into owner_id from public.community_groups g
 join public.community_group_memberships m on m.group_id=g.id
 where g.id=p_group_id and m.user_id=u and m.role='member' and m.status='active';
 if owner_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,owner_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.community_groups g where g.id=p_group_id for update;
 update public.community_group_memberships m set status='removed'
  where m.group_id=p_group_id and m.user_id=u and m.role='member' and m.status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 -- A removed member cannot currently be reinvited; rejoining policy is pending.
end; $$;
revoke all on function public.list_own_joined_groups(timestamptz,uuid) from public,anon,authenticated;
revoke all on function public.list_own_unavailable_group_memberships(timestamptz,uuid) from public,anon,authenticated;
revoke all on function public.leave_joined_group(uuid) from public,anon,authenticated;
grant execute on function public.list_own_joined_groups(timestamptz,uuid) to authenticated;
grant execute on function public.list_own_unavailable_group_memberships(timestamptz,uuid) to authenticated;
grant execute on function public.leave_joined_group(uuid) to authenticated;
-- Same-LGA and block requirements are conservative temporary product rules.
-- Retention, rejoining, suspended users, content access and API review remain.
