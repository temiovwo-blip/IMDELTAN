-- Draft exact-handle lookup for a group owner. Privacy-preserving defaults:
-- matching accounts must have a public profile and allow member contact.
-- No broad browse, fuzzy search, direct table access or email exposure.
create table app_private.group_invite_lookup_attempts (
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default pg_catalog.now()
);
create index group_invite_lookup_attempts_user_time_idx on app_private.group_invite_lookup_attempts(user_id,created_at);
revoke all on app_private.group_invite_lookup_attempts from public,anon,authenticated;

create function public.find_group_invitee(p_group_id uuid,p_handle text)
returns table (user_id uuid,handle text,display_name text)
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
 return query select p.user_id,p.handle,p.display_name from public.profiles p
 join public.user_privacy_settings s on s.user_id=p.user_id
 where p.user_id=target and target<>u and p.lga_id=g.lga_id and p.handle=handle_clean
  and s.profile_visibility='public' and s.contact_permission='members'
  and app_private.user_passes_platform_gate(target)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=target) or (b.blocker_id=target and b.blocked_id=u))
  and not exists(select 1 from public.community_group_memberships m where m.group_id=g.id and m.user_id=target);
end; $$;
revoke all on function public.find_group_invitee(uuid,text) from public,anon,authenticated;
grant execute on function public.find_group_invitee(uuid,text) to authenticated;

-- Recheck target privacy when the invitation is actually sent. The lookup
-- result is not authorization to invite later after a privacy change.
create or replace function public.invite_to_own_group(p_group_id uuid,p_invitee_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.community_groups%rowtype;
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
 insert into public.community_group_invitations(group_id,inviter_id,invitee_id) values(g.id,u,p_invitee_id) on conflict do nothing;
end; $$;
-- The replacement preserves existing execute grants. Lookup limiting alone is
-- not sufficient abuse prevention: direct invitation limits, cleanup jobs,
-- audit, legal review, production/API and cross-user concurrency tests remain.
