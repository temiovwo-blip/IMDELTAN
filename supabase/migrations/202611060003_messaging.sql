-- Draft messaging metadata; not end-to-end encrypted, no client grants or policies.
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  conversation_type text not null default 'direct' check (conversation_type in ('direct', 'group')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);
create index conversation_participants_user_idx on public.conversation_participants(user_id, status);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null,
  sender_id uuid not null,
  body text not null default '',
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (conversation_id, sender_id) references public.conversation_participants(conversation_id, user_id) on delete restrict
);
create index messages_conversation_created_idx on public.messages(conversation_id, created_at desc, id);
create index messages_sender_idx on public.messages(sender_id);
create table public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  object_key text not null unique check (length(object_key) > 0),
  media_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  created_at timestamptz not null default now()
);
create index message_attachments_message_idx on public.message_attachments(message_id);
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
revoke all on public.conversations, public.conversation_participants, public.messages, public.message_attachments from anon, authenticated;
-- Active membership, blocked users, authorized creation and object access require
-- trusted workflows and policies; these remain unimplemented and default-deny.
