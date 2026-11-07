-- Development only. Dismissing a notice deletes that notice record only; it
-- does not change the underlying message, friend request, or invitation.
create function public.dismiss_own_in_app_notification(p_notification_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_notification_id is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 delete from public.notifications n where n.id=p_notification_id and n.recipient_id=u and (
  (n.event_type='friend_request_received' and n.reference_type='friend_request') or
  (n.event_type='direct_message_received' and n.reference_type='direct_message') or
  (n.event_type='group_invitation_received' and n.reference_type='group_invitation')
 );
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.dismiss_own_in_app_notification(uuid) from public,anon,authenticated;
grant execute on function public.dismiss_own_in_app_notification(uuid) to authenticated;
