-- Draft private invitations. Until broader rules are agreed, invitations only
-- work inside the same LGA. This does not grant discovery or group content access.
create table public.community_group_invitations (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.community_groups(id) on delete cascade,
 inviter_id uuid not null references auth.users(id) on delete cascade,
 invitee_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now(),
 resolved_at timestamptz,
 check (inviter_id <> invitee_id),
 check ((status='pending' and resolved_at is null) or (status<>'pending' and resolved_at is not null))
);
create unique index group_invitations_pending_idx on public.community_group_invitations(group_id,invitee_id) where status='pending';
create index group_invitations_invitee_idx on public.community_group_invitations(invitee_id,status,created_at desc,id desc);
alter table public.community_group_invitations enable row level security;
revoke all on public.community_group_invitations from public,anon,authenticated;

create function public.invite_to_own_group(p_group_id uuid,p_invitee_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.community_groups%rowtype;
begin
 if u is null or p_group_id is null or p_invitee_id is null or u=p_invitee_id then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,p_invitee_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select * into g from public.community_groups where id=p_group_id and created_by=u and status='active' for update;
 if not found or not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active') then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Uniform no-op for ineligible, unavailable, already-member, removed or blocked targets.
 if not app_private.user_passes_platform_gate(p_invitee_id)
  or not exists(select 1 from public.profiles p where p.user_id=p_invitee_id and p.lga_id=g.lga_id)
  or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_invitee_id) or (b.blocker_id=p_invitee_id and b.blocked_id=u))
  or exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=p_invitee_id) then return;end if;
 insert into public.community_group_invitations(group_id,inviter_id,invitee_id) values(g.id,u,p_invitee_id) on conflict do nothing;
end; $$;

create function public.list_own_group_invitations(p_before timestamptz default null,p_before_id uuid default null)
returns table (id uuid,group_id uuid,group_name text,lga_name text,inviter_id uuid,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select i.id,g.id,g.name,l.name,i.inviter_id,i.created_at
 from public.community_group_invitations i join public.community_groups g on g.id=i.group_id
 join public.lgas l on l.id=g.lga_id join public.profiles p on p.user_id=u
 join public.community_group_memberships m on m.group_id=g.id and m.user_id=i.inviter_id and m.role='owner' and m.status='active'
 where i.invitee_id=u and i.status='pending' and g.status='active' and g.created_by=i.inviter_id
  and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(i.inviter_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=i.inviter_id) or (b.blocker_id=i.inviter_id and b.blocked_id=u))
  and not exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=u)
  and (p_before is null or (i.created_at,i.id)<(p_before,p_before_id))
 order by i.created_at desc,i.id desc limit 25;
end; $$;

create function public.respond_to_group_invitation(p_invitation_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); inviter uuid; group_id uuid; invite public.community_group_invitations%rowtype; g public.community_groups%rowtype;
begin
 if u is null or p_invitation_id is null or p_accept is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select i.inviter_id,i.group_id into inviter,group_id from public.community_group_invitations i where i.id=p_invitation_id and i.invitee_id=u;
 if inviter is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,inviter) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select * into g from public.community_groups cg where cg.id=group_id for update;
 select * into invite from public.community_group_invitations i where i.id=p_invitation_id and i.invitee_id=u for update;
 if not found or invite.status<>'pending' then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_accept then
  if g.id is null or g.status<>'active' or g.created_by<>inviter or not app_private.user_passes_platform_gate(inviter)
   or not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=inviter and m.role='owner' and m.status='active')
   or not exists(select 1 from public.profiles p where p.user_id=u and p.lga_id=g.lga_id)
   or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=inviter) or (b.blocker_id=inviter and b.blocked_id=u))
   or exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u) then
    raise exception 'Action not permitted' using errcode='42501';end if;
  insert into public.community_group_memberships(group_id,user_id,role,status) values(g.id,u,'member','active');
 end if;
 update public.community_group_invitations i set status=case when p_accept then 'accepted' else 'declined' end,resolved_at=pg_catalog.now() where i.id=p_invitation_id;
end; $$;
revoke all on function public.invite_to_own_group(uuid,uuid) from public,anon,authenticated;
revoke all on function public.list_own_group_invitations(timestamptz,uuid) from public,anon,authenticated;
revoke all on function public.respond_to_group_invitation(uuid,boolean) from public,anon,authenticated;
grant execute on function public.invite_to_own_group(uuid,uuid) to authenticated;
grant execute on function public.list_own_group_invitations(timestamptz,uuid) to authenticated;
grant execute on function public.respond_to_group_invitation(uuid,boolean) to authenticated;
-- Block enforcement across existing group members/content, concurrency and
-- direct API tests, invitation abuse limits, notifications, and owner controls
-- must be reviewed before enabling. No client table access is granted.
