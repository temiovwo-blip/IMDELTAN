-- Draft reference data and optional preferences. No reference data is imported.
create table public.languages (
  code text primary key check (code ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$'),
  display_name text not null check (length(trim(display_name)) between 1 and 120)
);
create table public.user_language_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  language_code text not null references public.languages(code) on delete restrict,
  preference_order integer not null check (preference_order > 0),
  primary key (user_id, language_code),
  unique (user_id, preference_order)
);
create index user_language_preferences_language_idx on public.user_language_preferences(language_code);
create table public.lgas (
  id uuid primary key default gen_random_uuid(),
  state_name text not null check (length(trim(state_name)) between 1 and 120),
  name text not null check (length(trim(name)) between 1 and 120),
  unique (state_name, name)
);
alter table public.profiles add column lga_id uuid references public.lgas(id) on delete set null;
create index profiles_lga_idx on public.profiles(lga_id) where lga_id is not null;
create table public.ethnic_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(trim(name)) between 1 and 120)
);
create table public.ethnic_group_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  policy_version_id uuid not null references public.policy_versions(id) on delete restrict,
  decision text not null check (decision in ('granted', 'withdrawn')),
  purpose text not null check (length(trim(purpose)) between 1 and 500),
  recorded_at timestamptz not null default now()
);
create index ethnic_consents_user_time_idx on public.ethnic_group_consents(user_id, recorded_at desc, id);
create index ethnic_consents_policy_idx on public.ethnic_group_consents(policy_version_id);
create table public.user_ethnic_groups (
  user_id uuid not null references auth.users(id) on delete cascade,
  ethnic_group_id uuid not null references public.ethnic_groups(id) on delete restrict,
  primary key (user_id, ethnic_group_id)
);
create index user_ethnic_groups_group_idx on public.user_ethnic_groups(ethnic_group_id);
alter table public.languages enable row level security;
alter table public.user_language_preferences enable row level security;
alter table public.lgas enable row level security;
alter table public.ethnic_groups enable row level security;
alter table public.ethnic_group_consents enable row level security;
alter table public.user_ethnic_groups enable row level security;
revoke all on public.languages, public.user_language_preferences, public.lgas,
  public.ethnic_groups, public.ethnic_group_consents, public.user_ethnic_groups from anon, authenticated;
-- Ethnicity is optional sensitive data. Consent enforcement, withdrawal cleanup,
-- retention and access require reviewed trusted workflows before any grant.
