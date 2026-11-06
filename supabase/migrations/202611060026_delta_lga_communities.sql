-- Draft: the 25 Delta local government communities and nested groups.
-- No client access to group data is enabled. No ethnicity is inferred or collected.
insert into public.lgas(state_name,name) values
 ('Delta','Aniocha North'),('Delta','Aniocha South'),('Delta','Bomadi'),('Delta','Burutu'),
 ('Delta','Ethiope East'),('Delta','Ethiope West'),('Delta','Ika North East'),('Delta','Ika South'),
 ('Delta','Isoko North'),('Delta','Isoko South'),('Delta','Ndokwa East'),('Delta','Ndokwa West'),
 ('Delta','Okpe'),('Delta','Oshimili North'),('Delta','Oshimili South'),('Delta','Patani'),
 ('Delta','Sapele'),('Delta','Udu'),('Delta','Ughelli North'),('Delta','Ughelli South'),
 ('Delta','Ukwuani'),('Delta','Uvwie'),('Delta','Warri North'),('Delta','Warri South'),('Delta','Warri South West')
on conflict (state_name,name) do nothing;

create table public.lga_communities (
  lga_id uuid primary key references public.lgas(id) on delete restrict,
  created_at timestamptz not null default now()
);
insert into public.lga_communities(lga_id) select id from public.lgas where state_name='Delta' and name in (
 'Aniocha North','Aniocha South','Bomadi','Burutu','Ethiope East','Ethiope West','Ika North East','Ika South',
 'Isoko North','Isoko South','Ndokwa East','Ndokwa West','Okpe','Oshimili North','Oshimili South','Patani',
 'Sapele','Udu','Ughelli North','Ughelli South','Ukwuani','Uvwie','Warri North','Warri South','Warri South West');
create table public.community_groups (
  id uuid primary key default gen_random_uuid(),
  lga_id uuid not null references public.lga_communities(lga_id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 120),
  description text not null default '' check (length(description)<=1000),
  visibility text not null default 'private' check (visibility in ('public','private')),
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now()
);
create index community_groups_lga_status_idx on public.community_groups(lga_id,status,created_at desc,id);
alter table public.lga_communities enable row level security;
alter table public.community_groups enable row level security;
revoke all on public.lga_communities,public.community_groups from public,anon,authenticated;

-- Pending users may select an LGA during onboarding; active users may update
-- their selection only after passing the usual current-policy/eligibility gate.
create function public.list_delta_lgas()
returns table (id uuid,name text) language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); state text;
begin
 select p.account_state into state from public.profiles p where p.user_id=u;
 if u is null or state is null or state not in ('pending','active') or
    (state='active' and not app_private.user_passes_platform_gate(u)) then
    raise exception 'Action not permitted' using errcode='42501'; end if;
 return query select l.id,l.name from public.lgas l join public.lga_communities c on c.lga_id=l.id
   where l.state_name='Delta' order by l.name;
end; $$;
create function public.get_own_lga()
returns table (id uuid,name text) language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); state text;
begin
 select p.account_state into state from public.profiles p where p.user_id=u;
 if u is null or state is null or state not in ('pending','active') or
    (state='active' and not app_private.user_passes_platform_gate(u)) then
    raise exception 'Action not permitted' using errcode='42501'; end if;
 return query select l.id,l.name from public.profiles p join public.lgas l on l.id=p.lga_id
   join public.lga_communities c on c.lga_id=l.id where p.user_id=u and l.state_name='Delta';
end; $$;
create function public.set_own_lga(p_lga_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); state text;
begin
 select p.account_state into state from public.profiles p where p.user_id=u for update;
 if u is null or state is null or state not in ('pending','active') or
    (state='active' and not app_private.user_passes_platform_gate(u)) then
    raise exception 'Action not permitted' using errcode='42501'; end if;
 if p_lga_id is null or not exists(select 1 from public.lgas l join public.lga_communities c on c.lga_id=l.id where l.id=p_lga_id and l.state_name='Delta') then
    raise exception 'Invalid local government' using errcode='22023'; end if;
 update public.profiles set lga_id=p_lga_id,updated_at=pg_catalog.now() where user_id=u;
end; $$;
revoke all on function public.list_delta_lgas() from public,anon,authenticated;
revoke all on function public.get_own_lga() from public,anon,authenticated;
revoke all on function public.set_own_lga(uuid) from public,anon,authenticated;
grant execute on function public.list_delta_lgas() to authenticated;
grant execute on function public.get_own_lga() to authenticated;
grant execute on function public.set_own_lga(uuid) to authenticated;

-- The database, not just the form, requires a valid LGA before activation.
create function app_private.require_lga_for_activation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.account_state='pending' and new.account_state='active' and not exists (
   select 1 from public.lgas l join public.lga_communities c on c.lga_id=l.id
   where l.id=new.lga_id and l.state_name='Delta'
 ) then raise exception 'Action not permitted' using errcode='42501'; end if;
 return new;
end; $$;
revoke all on function app_private.require_lga_for_activation() from public,anon,authenticated;
create trigger profile_requires_lga_for_activation before update of account_state on public.profiles
for each row execute function app_private.require_lga_for_activation();
-- Group creation/membership, LGA display privacy, migration of existing active
-- accounts, rate limits, legal and direct API/concurrency review remain unresolved.
