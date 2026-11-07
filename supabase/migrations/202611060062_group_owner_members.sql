-- Development-only group-owner membership controls. Membership is visible to
-- the owner, not other members; blocked/ineligible/out-of-LGA members are
-- deliberately omitted. Removal is not moderation, erasure or a launch grant.
create function public.list_own_private_group_members(p_group_id uuid,p_before timestamptz default null,p_before_id uuid default null)
returns table(user_id uuid,display_name text,joined_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_group_id is null or not app_private.can_access_private_group_feed(u,p_group_id)
 or not exists(select 1 from public.community_groups g where g.id=p_group_id and g.created_by=u)
 or not exists(select 1 from public.community_group_memberships m where m.group_id=p_group_id and m.user_id=u and m.role='owner' and m.status='active') then
  raise exception 'Action not permitted' using errcode='42501';
 end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select m.user_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),m.joined_at
 from public.community_group_memberships m join public.profiles p on p.user_id=m.user_id join public.community_groups g on g.id=m.group_id
 where m.group_id=p_group_id and m.role='member' and m.status='active' and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(p.user_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=m.user_id) or (b.blocker_id=m.user_id and b.blocked_id=u))
 and (p_before is null or (m.joined_at,m.user_id)<(p_before,p_before_id)) order by m.joined_at desc,m.user_id desc limit 25;
end; $$;
create function public.remove_own_private_group_member(p_group_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_group_id is null or p_member_id is null or u=p_member_id then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Same profile/group lock order as invitations, leaving, feeds and block.
 perform 1 from public.profiles p where p.user_id in(u,p_member_id) order by p.user_id for update;
 perform 1 from public.community_groups g where g.id=p_group_id and g.created_by=u and g.status='active' for update;
 if not found or not app_private.can_access_private_group_feed(u,p_group_id)
 or not exists(select 1 from public.community_group_memberships m where m.group_id=p_group_id and m.user_id=u and m.role='owner' and m.status='active')
 or not app_private.user_passes_platform_gate(p_member_id)
 or not exists(select 1 from public.profiles p join public.community_groups g on g.id=p_group_id where p.user_id=p_member_id and p.lga_id=g.lga_id)
 or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_member_id) or (b.blocker_id=p_member_id and b.blocked_id=u)) then
  raise exception 'Action not permitted' using errcode='42501';
 end if;
 update public.community_group_memberships m set status='removed' where m.group_id=p_group_id and m.user_id=p_member_id and m.role='member' and m.status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Defensively resolve stale invites; no automatic reinvitation for removed.
 update public.community_group_invitations i set status='cancelled',resolved_at=pg_catalog.clock_timestamp() where i.group_id=p_group_id and i.invitee_id=p_member_id and i.status='pending';
 insert into public.audit_logs(actor_id,action,target_type,target_id,outcome) values(u,'group_owner_member_removed','community_group_membership',p_group_id::text||':'||p_member_id::text,'success');
end; $$;
revoke all on function public.list_own_private_group_members(uuid,timestamptz,uuid),public.remove_own_private_group_member(uuid,uuid) from public,anon,authenticated;
grant execute on function public.list_own_private_group_members(uuid,timestamptz,uuid),public.remove_own_private_group_member(uuid,uuid) to authenticated;
