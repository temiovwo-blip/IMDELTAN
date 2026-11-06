-- Draft social graph. No client access until reviewed authorization is implemented.
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (sender_id <> recipient_id),
  check ((status = 'pending' and resolved_at is null) or (status <> 'pending' and resolved_at is not null))
);
create unique index friend_requests_pending_pair_idx
  on public.friend_requests (least(sender_id, recipient_id), greatest(sender_id, recipient_id))
  where status = 'pending';
create index friend_requests_recipient_idx on public.friend_requests(recipient_id, status, created_at desc);
create index friend_requests_sender_idx on public.friend_requests(sender_id, status, created_at desc);

create table public.friendships (
  user_low uuid not null references auth.users(id) on delete cascade,
  user_high uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low < user_high)
);
create index friendships_user_high_idx on public.friendships(user_high, user_low);

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks(blocked_id, blocker_id);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.user_blocks enable row level security;
revoke all on public.friend_requests, public.friendships, public.user_blocks from anon, authenticated;
-- Accepting a request, enforcing blocks and handling simultaneous requests require
-- trusted atomic workflows, not yet implemented. No client policies are provided.
