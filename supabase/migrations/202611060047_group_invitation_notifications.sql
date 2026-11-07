-- Development-only in-app notices. No push, email, profile text, or backfill.
create unique index notifications_one_group_invitation_idx on public.notifications(recipient_id,reference_id)
 where event_type='group_invitation_received' and reference_type='group_invitation';
create index notifications_group_invitation_cursor_idx on public.notifications(recipient_id,created_at desc,id desc)
 where event_type='group_invitation_received' and reference_type='group_invitation';
create function app_private.notify_group_invitation_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='pending' then
  insert into public.notifications(recipient_id,event_type,reference_type,reference_id) values(new.invitee_id,'group_invitation_received','group_invitation',new.id)
  on conflict(recipient_id,reference_id) where event_type='group_invitation_received' and reference_type='group_invitation' do nothing;
 end if;
 return new;
end; $$;
revoke all on function app_private.notify_group_invitation_insert() from public,anon,authenticated;
create trigger group_invitation_notification_after_insert after insert on public.community_group_invitations
 for each row execute function app_private.notify_group_invitation_insert();

create function public.list_own_group_invitation_notifications(p_before timestamptz default null,p_before_id uuid default null)
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
 and not exists(select 1 from public.community_group_memberships gm where gm.group_id=g.id and gm.user_id=u)
 and (p_before is null or (n.created_at,n.id)<(p_before,p_before_id))
 order by n.created_at desc,n.id desc limit 30;
end; $$;
create function public.mark_own_group_invitation_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.notifications n set read_at=coalesce(n.read_at,pg_catalog.now()) where n.id=p_notification_id and n.recipient_id=u and n.event_type='group_invitation_received' and n.reference_type='group_invitation';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.list_own_group_invitation_notifications(timestamptz,uuid),public.mark_own_group_invitation_notification_read(uuid) from public,anon,authenticated;
grant execute on function public.list_own_group_invitation_notifications(timestamptz,uuid),public.mark_own_group_invitation_notification_read(uuid) to authenticated;
