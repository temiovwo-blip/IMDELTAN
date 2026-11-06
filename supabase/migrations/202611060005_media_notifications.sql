-- Draft metadata only; no storage buckets or access policies are created here.
create table public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  position integer not null check (position >= 0),
  object_key text not null unique check (length(object_key) > 0),
  media_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  status text not null default 'pending' check (status in ('pending', 'ready', 'rejected', 'deleted')),
  created_at timestamptz not null default now(),
  unique (post_id, position)
);
create table public.videos (
  id uuid primary key default gen_random_uuid(),
  post_media_id uuid not null unique references public.post_media(id) on delete cascade,
  processing_status text not null default 'pending' check (processing_status in ('pending', 'processing', 'ready', 'failed')),
  duration_seconds integer check (duration_seconds is null or duration_seconds > 0),
  created_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (length(trim(event_type)) between 1 and 100),
  reference_type text,
  reference_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check ((reference_type is null) = (reference_id is null))
);
create index notifications_recipient_created_idx on public.notifications(recipient_id, created_at desc);
create index notifications_unread_idx on public.notifications(recipient_id, created_at desc) where read_at is null;
alter table public.post_media enable row level security;
alter table public.videos enable row level security;
alter table public.notifications enable row level security;
revoke all on public.post_media, public.videos, public.notifications from anon, authenticated;
-- Ownership, validated uploads, object access and notification creation require
-- trusted services and tested RLS policies before access can be enabled.
