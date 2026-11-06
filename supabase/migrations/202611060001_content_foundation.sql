-- Draft social/content foundation. No client access is granted.
-- Apply only after review and isolated integration tests.
create table public.communities (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 120),
  description text,
  visibility text not null default 'private' check (visibility in ('public', 'private')),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now()
);
create table public.community_memberships (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  status text not null default 'pending' check (status in ('pending', 'active', 'removed')),
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_memberships_user_idx on public.community_memberships(user_id, status);
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete restrict,
  community_id uuid references public.communities(id) on delete restrict,
  body text not null default '',
  audience text not null default 'private' check (audience in ('private', 'friends', 'public', 'community')),
  status text not null default 'active' check (status in ('active', 'removed', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((community_id is not null and audience = 'community') or (community_id is null and audience <> 'community'))
);
create index posts_author_created_idx on public.posts(author_id, created_at desc);
create index posts_community_created_idx on public.posts(community_id, created_at desc) where community_id is not null;
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete restrict,
  parent_id uuid,
  body text not null check (length(trim(body)) > 0),
  status text not null default 'active' check (status in ('active', 'removed', 'deleted')),
  created_at timestamptz not null default now(),
  unique (post_id, id),
  foreign key (post_id, parent_id) references public.comments(post_id, id) on delete restrict,
  check (parent_id is null or parent_id <> id)
);
create index comments_post_created_idx on public.comments(post_id, created_at);
create index comments_parent_idx on public.comments(post_id, parent_id) where parent_id is not null;
create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  kind text not null check (length(trim(kind)) between 1 and 32),
  created_at timestamptz not null default now(),
  check ((post_id is not null) <> (comment_id is not null))
);
create unique index reactions_one_per_post on public.reactions(user_id, post_id) where post_id is not null;
create unique index reactions_one_per_comment on public.reactions(user_id, comment_id) where comment_id is not null;
create index reactions_post_idx on public.reactions(post_id) where post_id is not null;
create index reactions_comment_idx on public.reactions(comment_id) where comment_id is not null;
create table public.saved_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index saved_posts_post_idx on public.saved_posts(post_id);

alter table public.communities enable row level security;
alter table public.community_memberships enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.saved_posts enable row level security;
revoke all on public.communities, public.community_memberships, public.posts,
  public.comments, public.reactions, public.saved_posts from anon, authenticated;
