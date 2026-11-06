-- Draft private group creation inside the caller's selected LGA community.
-- Discovery, invitations, joining, posting, moderation and cross-LGA policies
-- are deliberately not enabled by this migration.
create table public.community_group_memberships (
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','moderator','member')),
  status text not null default 'active' check (status in ('active','removed')),
  joined_at timestamptz not null default now(),
  primary key (group_id,user_id)
);
create unique index community_group_one_owner_idx on public.community_group_memberships(group_id)
  where role='owner' and status='active';
create index community_group_memberships_user_idx on public.community_group_memberships(user_id,status,group_id);
alter table public.community_group_memberships enable row level security;
revoke all on public.community_group_memberships from public,anon,authenticated;

create function public.create_group_in_own_lga(p_name text,p_description text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); lga uuid; clean_name text:=pg_catalog.btrim(p_name);
  clean_description text:=pg_catalog.btrim(p_description); new_id uuid;
begin
 if u is null then raise exception 'Action not permitted' using errcode='42501'; end if;
 select p.lga_id into lga from public.profiles p where p.user_id=u for update;
 if not found or not app_private.user_passes_platform_gate(u) or lga is null
    or not exists(select 1 from public.lga_communities c where c.lga_id=lga) then
   raise exception 'Action not permitted' using errcode='42501'; end if;
 if clean_name is null or pg_catalog.length(clean_name) not between 1 and 120
    or clean_description is null or pg_catalog.length(clean_description)>1000 then
   raise exception 'Invalid group details' using errcode='22023'; end if;
 insert into public.community_groups(lga_id,created_by,name,description,visibility,status)
   values(lga,u,clean_name,clean_description,'private','active') returning id into new_id;
 insert into public.community_group_memberships(group_id,user_id,role,status)
   values(new_id,u,'owner','active');
 return new_id;
end; $$;

create function public.list_own_created_groups(p_after timestamptz default null,p_after_id uuid default null)
returns table (id uuid,lga_name text,name text,description text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
 if (p_after is null) <> (p_after_id is null) then raise exception 'Invalid cursor' using errcode='22023'; end if;
 return query select g.id,l.name,g.name,g.description,g.created_at
 from public.community_groups g join public.lgas l on l.id=g.lga_id
 join public.community_group_memberships m on m.group_id=g.id and m.user_id=u and m.role='owner' and m.status='active'
 where g.created_by=u and g.status='active' and (p_after is null or (g.created_at,g.id)<(p_after,p_after_id))
 order by g.created_at desc,g.id desc limit 25;
end; $$;
revoke all on function public.create_group_in_own_lga(text,text) from public,anon,authenticated;
revoke all on function public.list_own_created_groups(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.create_group_in_own_lga(text,text) to authenticated;
grant execute on function public.list_own_created_groups(timestamptz,uuid) to authenticated;
-- Rate limits, name abuse prevention, ownership transfer, disclosure rules,
-- audit, actual Supabase APIs, and policy/account-state races need review.
