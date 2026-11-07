-- Development draft: cap successful group invitations across groups at 20/hour per sender.
-- Profile row lock serializes sends. This is not comprehensive anti-abuse protection.
create table app_private.group_invitation_sends (
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default pg_catalog.now()
);
create index group_invitation_sends_user_time_idx on app_private.group_invitation_sends(user_id,created_at);
revoke all on app_private.group_invitation_sends from public,anon,authenticated;

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
  or exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=p_invitee_id) then return;end if;
 -- The locked caller profile serializes concurrent invitations from this owner.
 delete from app_private.group_invitation_sends s where s.user_id=u and s.created_at < pg_catalog.now()-interval '1 day';
 select count(*) into sent_count from app_private.group_invitation_sends s where s.user_id=u and s.created_at>pg_catalog.now()-interval '1 hour';
 if sent_count>=20 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.community_group_invitations(group_id,inviter_id,invitee_id) values(g.id,u,p_invitee_id) on conflict do nothing;
 get diagnostics inserted_count = row_count;
 if inserted_count=1 then insert into app_private.group_invitation_sends(user_id) values(u);end if;
end; $$;

-- Failed/no-op requests are not limited here. Add edge controls and monitoring before release.
