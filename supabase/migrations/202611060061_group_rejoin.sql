-- Development-only, opt-in rejoining by fresh owner invitation plus consent.
-- Existing 'removed' records are intentionally NOT converted: their origin is
-- ambiguous. Only new voluntary leaves become 'left'; removed stays blocked.
alter table public.community_group_memberships drop constraint community_group_memberships_status_check;
alter table public.community_group_memberships add constraint community_group_memberships_status_check check(status in ('active','removed','left'));
create index group_invitation_decline_cooldown_idx on public.community_group_invitations(group_id,invitee_id,resolved_at desc) where status='declined';

create or replace function public.leave_joined_group(p_group_id uuid)
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
 update public.community_group_memberships m set status='left'
  where m.group_id=p_group_id and m.user_id=u and m.role='member' and m.status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 -- A future invitation still requires the member's explicit consent.
end; $$;

drop function public.find_group_invitee(uuid,text);
create function public.find_group_invitee(p_group_id uuid,p_handle text)
returns table (user_id uuid,handle text,display_name text,is_rejoin boolean)
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); target uuid; handle_clean text:=pg_catalog.lower(pg_catalog.btrim(p_handle)); g public.community_groups%rowtype; attempts integer;
begin
 if u is null or p_group_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 if handle_clean is null or handle_clean !~ '^[a-z0-9_]{3,30}$' then raise exception 'Invalid username' using errcode='22023';end if;
 select p.user_id into target from public.profiles p where p.handle=handle_clean;
 perform 1 from public.profiles p where p.user_id in (u,target) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select * into g from public.community_groups cg where cg.id=p_group_id and cg.created_by=u and cg.status='active' for update;
 if not found or not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active') then raise exception 'Action not permitted' using errcode='42501';end if;
 delete from app_private.group_invite_lookup_attempts a where a.user_id=u and a.created_at<pg_catalog.now()-interval '1 day';
 select count(*) into attempts from app_private.group_invite_lookup_attempts a where a.user_id=u and a.created_at>pg_catalog.now()-interval '1 minute';
 if attempts>=12 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into app_private.group_invite_lookup_attempts(user_id) values(u);
 return query select p.user_id,p.handle,p.display_name,exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=target and gm.role='member' and gm.status='left') from public.profiles p
 join public.user_privacy_settings s on s.user_id=p.user_id
 where p.user_id=target and target<>u and p.lga_id=g.lga_id and p.handle=handle_clean
  and s.profile_visibility='public' and s.contact_permission='members'
  and app_private.user_passes_platform_gate(target)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=target) or (b.blocker_id=target and b.blocked_id=u))
  and not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=target and (m.role<>'member' or m.status<>'left'));
end; $$;
revoke all on function public.find_group_invitee(uuid,text) from public,anon,authenticated;
grant execute on function public.find_group_invitee(uuid,text) to authenticated;

create or replace function public.invite_to_own_group(p_group_id uuid,p_invitee_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.community_groups%rowtype; sent_count integer; inserted_count integer;
begin
 if u is null or p_group_id is null or p_invitee_id is null or u=p_invitee_id then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in (u,p_invitee_id) order by p.user_id for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 select * into g from public.community_groups where id=p_group_id and created_by=u and status='active' for update;
 if not found or not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active') then raise exception 'Action not permitted' using errcode='42501';end if;
 if not app_private.user_passes_platform_gate(p_invitee_id)
  or not exists(select 1 from public.profiles p join public.user_privacy_settings s on s.user_id=p.user_id where p.user_id=p_invitee_id and p.lga_id=g.lga_id and s.profile_visibility='public' and s.contact_permission='members')
  or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p_invitee_id) or (b.blocker_id=p_invitee_id and b.blocked_id=u))
  or exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=p_invitee_id and (m.role<>'member' or m.status<>'left')) then return;end if;
 -- Limit repeated unwanted re-invitations after a decline; no-op avoids disclosures.
 if exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=p_invitee_id and m.role='member' and m.status='left')
 and exists(select 1 from public.community_group_invitations i where i.group_id=g.id and i.invitee_id=p_invitee_id and i.status='declined' and i.resolved_at>pg_catalog.clock_timestamp()-interval '7 days') then return;end if;
 -- The locked caller profile serializes concurrent invitations from this owner.
 delete from app_private.group_invitation_sends s where s.user_id=u and s.created_at < pg_catalog.now()-interval '1 day';
 select count(*) into sent_count from app_private.group_invitation_sends s where s.user_id=u and s.created_at>pg_catalog.now()-interval '1 hour';
 if sent_count>=20 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.community_group_invitations(group_id,inviter_id,invitee_id) values(g.id,u,p_invitee_id) on conflict do nothing;
 get diagnostics inserted_count = row_count;
 if inserted_count=1 then insert into app_private.group_invitation_sends(user_id) values(u);end if;
end; $$;

drop function public.list_own_group_invitations(timestamptz,uuid);
create function public.list_own_group_invitations(p_before timestamptz default null,p_before_id uuid default null)
returns table (id uuid,group_id uuid,group_name text,lga_name text,inviter_id uuid,created_at timestamptz,is_rejoin boolean)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select i.id,g.id,g.name,l.name,i.inviter_id,i.created_at,exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=u and gm.role='member' and gm.status='left')
 from public.community_group_invitations i join public.community_groups g on g.id=i.group_id
 join public.lgas l on l.id=g.lga_id join public.profiles p on p.user_id=u
 join public.community_group_memberships m on m.group_id=g.id and m.user_id=i.inviter_id and m.role='owner' and m.status='active'
 where i.invitee_id=u and i.status='pending' and g.status='active' and g.created_by=i.inviter_id
  and p.lga_id=g.lga_id and app_private.user_passes_platform_gate(i.inviter_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=i.inviter_id) or (b.blocker_id=i.inviter_id and b.blocked_id=u))
  and not exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=u and (gm.role<>'member' or gm.status<>'left'))
  and (p_before is null or (i.created_at,i.id)<(p_before,p_before_id))
 order by i.created_at desc,i.id desc limit 25;
end; $$;
revoke all on function public.list_own_group_invitations(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_own_group_invitations(timestamptz,uuid) to authenticated;

create or replace function public.respond_to_group_invitation(p_invitation_id uuid,p_accept boolean)
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
   or exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=u and (m.role<>'member' or m.status<>'left')) then
    raise exception 'Action not permitted' using errcode='42501';end if;
  insert into public.community_group_memberships(group_id,user_id,role,status,joined_at) values(g.id,u,'member','active',pg_catalog.clock_timestamp())
  on conflict on constraint community_group_memberships_pkey do update set status='active',joined_at=excluded.joined_at
  where public.community_group_memberships.role='member' and public.community_group_memberships.status='left';
  if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 end if;
 update public.community_group_invitations i set status=case when p_accept then 'accepted' else 'declined' end,resolved_at=pg_catalog.now() where i.id=p_invitation_id;
end; $$;

create or replace function public.list_own_group_invitation_notifications(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,created_at timestamptz,read_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select n.id,n.created_at,n.read_at from public.notifications n
 join public.community_group_invitations i on i.id=n.reference_id and i.invitee_id=n.recipient_id
 join public.community_groups g on g.id=i.group_id
 join public.profiles p on p.user_id=u
 join public.community_group_memberships m on m.group_id=g.id and m.user_id=i.inviter_id and m.role='owner' and m.status='active'
 where n.recipient_id=u and n.event_type='group_invitation_received' and n.reference_type='group_invitation'
 and i.status='pending' and g.status='active' and g.created_by=i.inviter_id and p.lga_id=g.lga_id
 and app_private.user_passes_platform_gate(i.inviter_id)
 and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=i.inviter_id) or (b.blocker_id=i.inviter_id and b.blocked_id=u))
 and not exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=u and (gm.role<>'member' or gm.status<>'left'))
 and (p_before is null or (n.created_at,n.id)<(p_before,p_before_id))
 order by n.created_at desc,n.id desc limit 30;
end; $$;
