-- Draft moderation and admin records. Default-deny; no client-facing policies.
create table public.admin_roles (
  id uuid primary key default gen_random_uuid(),
  role_key text not null unique check (role_key ~ '^[a-z][a-z0-9_]{1,49}$'),
  description text not null
);
create table public.admin_role_assignments (
  user_id uuid not null references auth.users(id) on delete restrict,
  role_id uuid not null references public.admin_roles(id) on delete restrict,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role_id)
);
create index admin_role_assignments_role_idx on public.admin_role_assignments(role_id);
create table public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete restrict,
  reported_post_id uuid references public.posts(id) on delete restrict,
  reported_comment_id uuid references public.comments(id) on delete restrict,
  reason text not null check (length(trim(reason)) between 1 and 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  check (num_nonnulls(reported_user_id, reported_post_id, reported_comment_id) = 1)
);
create index user_reports_status_created_idx on public.user_reports(status, created_at);
create index user_reports_reporter_idx on public.user_reports(reporter_id, created_at desc);
create table public.moderation_records (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.user_reports(id) on delete restrict,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (length(trim(action)) between 1 and 100),
  justification text not null check (length(trim(justification)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index moderation_records_report_idx on public.moderation_records(report_id, created_at);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (length(trim(action)) between 1 and 100),
  target_type text not null check (length(trim(target_type)) between 1 and 100),
  target_id text,
  outcome text not null check (outcome in ('success', 'failure')),
  created_at timestamptz not null default now()
);
create index audit_logs_actor_created_idx on public.audit_logs(actor_id, created_at desc);
create index audit_logs_created_idx on public.audit_logs(created_at desc);
alter table public.admin_roles enable row level security;
alter table public.admin_role_assignments enable row level security;
alter table public.user_reports enable row level security;
alter table public.moderation_records enable row level security;
alter table public.audit_logs enable row level security;
revoke all on public.admin_roles, public.admin_role_assignments, public.user_reports,
  public.moderation_records, public.audit_logs from anon, authenticated;
-- No authorization or audit-writing workflow exists yet. Deletion, retention,
-- separation of duties and MFA enforcement require review before enabling access.
