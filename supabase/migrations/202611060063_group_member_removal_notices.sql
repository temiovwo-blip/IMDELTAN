-- Development-only notice of owner-initiated membership removal. No push,
-- email, automatic backfill, appeal system or approved retention policy.
create table app_private.group_member_removal_events(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.community_groups(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default pg_catalog.clock_timestamp()
);
create index group_member_removal_events_recipient_idx on app_private.group_member_removal_events(recipient_id,created_at desc,id desc);
alter table app_private.group_member_removal_events enable row level security;
revoke all on app_private.group_member_removal_events from public,anon,authenticated;
create unique index notifications_group_member_removal_idx on public.notifications(recipient_id,reference_id) where event_type='group_membership_removed' and reference_type='group_member_removal';
create index notifications_group_member_removal_cursor_idx on public.notifications(recipient_id,created_at desc,id desc) where event_type='group_membership_removed' and reference_type='group_member_removal';

create or replace function public.remove_own_private_group_member(p_group_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();event_id uuid;
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
 insert into app_private.group_member_removal_events(group_id,recipient_id) values(p_group_id,p_member_id) returning id into event_id;
 insert into public.notifications(recipient_id,event_type,reference_type,reference_id) values(p_member_id,'group_membership_removed','group_member_removal',event_id);
end; $$;

create or replace function public.dismiss_own_in_app_notification(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 delete from public.notifications n where n.id=p_notification_id and n.recipient_id=u and (
  (n.event_type='friend_request_received' and n.reference_type='friend_request') or
  (n.event_type='direct_message_received' and n.reference_type='direct_message') or
  (n.event_type='group_invitation_received' and n.reference_type='group_invitation') or
  (n.event_type='group_membership_removed' and n.reference_type='group_member_removal')
 );
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;


create function public.list_own_group_removal_notifications(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,created_at timestamptz,read_at timestamptz,group_name text)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select n.id,n.created_at,n.read_at,
  case when g.status='active' and g.visibility='private' and vp.lga_id=g.lga_id and ownerp.lga_id=g.lga_id
   and app_private.user_passes_platform_gate(g.created_by)
   and exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=g.created_by and m.role='owner' and m.status='active')
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=g.created_by) or (b.blocker_id=g.created_by and b.blocked_id=u))
   then g.name else null::text end
 from public.notifications n join app_private.group_member_removal_events e on e.id=n.reference_id and e.recipient_id=n.recipient_id
 join public.community_groups g on g.id=e.group_id join public.profiles vp on vp.user_id=u join public.profiles ownerp on ownerp.user_id=g.created_by
 where n.recipient_id=u and n.event_type='group_membership_removed' and n.reference_type='group_member_removal'
 and (p_before is null or (n.created_at,n.id)<(p_before,p_before_id)) order by n.created_at desc,n.id desc limit 30;
end; $$;
create function public.mark_own_group_removal_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.notifications n set read_at=coalesce(n.read_at,pg_catalog.clock_timestamp()) where n.id=p_notification_id and n.recipient_id=u and n.event_type='group_membership_removed' and n.reference_type='group_member_removal';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.list_own_group_removal_notifications(timestamptz,uuid),public.mark_own_group_removal_notification_read(uuid) from public,anon,authenticated;
grant execute on function public.list_own_group_removal_notifications(timestamptz,uuid),public.mark_own_group_removal_notification_read(uuid) to authenticated;
