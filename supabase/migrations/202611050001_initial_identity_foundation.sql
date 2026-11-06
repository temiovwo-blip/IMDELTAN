-- Clean-slate foundation only. Not a complete schema or launch-ready security model.
-- Apply only to a newly created IMDELTAN environment after review.
-- Intentionally no client access policies: application tables remain default-deny.

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  handle text unique,
  display_name text,
  biography text,
  account_state text not null default 'pending'
    check (account_state in ('pending', 'active', 'suspended', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint handle_format check (handle is null or handle ~ '^[a-z0-9_]{3,30}$')
);

create table public.user_eligibility (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'eligible', 'ineligible', 'revoked')),
  verification_method text,
  verification_version text,
  verified_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint eligibility_verification check (status <> 'eligible' or (verification_method is not null and verification_version is not null and verified_at is not null))
);

create table public.user_privacy_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile_visibility text not null default 'private' check (profile_visibility in ('private', 'friends', 'public')),
  contact_permission text not null default 'friends' check (contact_permission in ('nobody', 'friends', 'members')),
  updated_at timestamptz not null default now()
);

create table public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version text not null,
  content_url text not null,
  content_sha256 text not null check (content_sha256 ~ '^[a-f0-9]{64}$'),
  mandatory boolean not null default true,
  published_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  unique (policy_key, version),
  check (retired_at is null or (published_at is not null and retired_at >= published_at))
);
create unique index policy_versions_one_current_per_key on public.policy_versions (policy_key)
  where published_at is not null and retired_at is null;

create table public.policy_acceptances (
  user_id uuid not null references auth.users(id) on delete cascade,
  policy_version_id uuid not null references public.policy_versions(id) on delete restrict,
  accepted_at timestamptz not null default now(),
  primary key (user_id, policy_version_id)
);
create index policy_acceptances_version_idx on public.policy_acceptances (policy_version_id);

alter table public.profiles enable row level security;
alter table public.user_eligibility enable row level security;
alter table public.user_privacy_settings enable row level security;
alter table public.policy_versions enable row level security;
alter table public.policy_acceptances enable row level security;

-- Supabase default grants vary; explicitly deny API roles until reviewed policies exist.
revoke all on public.profiles, public.user_eligibility, public.user_privacy_settings,
  public.policy_versions, public.policy_acceptances from anon, authenticated;
