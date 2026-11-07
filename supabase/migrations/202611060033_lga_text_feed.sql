-- Development draft: same-LGA text feed. No direct table access, media, comments,
-- reactions, discovery, automated moderation, or production-readiness claim.
create table public.lga_text_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete restrict,
 lga_id uuid not null references public.lgas(id) on delete restrict,
 body text not null check (pg_catalog.length(pg_catalog.btrim(body)) between 1 and 5000),
 status text not null default 'active' check (status in ('active','deleted','removed')),
 created_at timestamptz not null default pg_catalog.now(),
 deleted_at timestamptz
);
create index lga_text_posts_feed_idx on public.lga_text_posts(lga_id,created_at desc,id desc) where status='active';
create index lga_text_posts_author_time_idx on public.lga_text_posts(author_id,created_at desc);
alter table public.lga_text_posts enable row level security;
revoke all on public.lga_text_posts from public,anon,authenticated;

create function public.create_lga_text_post(p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); l uuid; clean text:=pg_catalog.btrim(p_body); new_id uuid; recent int;
begin
 if u is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select p.lga_id into l from public.profiles p where p.user_id=u for update;
 if l is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if clean is null or pg_catalog.length(clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023';end if;
 select count(*) into recent from public.lga_text_posts p where p.author_id=u and p.created_at>pg_catalog.now()-interval '1 hour';
 if recent>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.lga_text_posts(author_id,lga_id,body) values(u,l,clean) returning id into new_id;
 return new_id;
end; $$;

create function public.list_lga_text_posts(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); l uuid;
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 select p.lga_id into l from public.profiles p where p.user_id=u;
 if l is null then raise exception 'Action not permitted' using errcode='42501';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,t.created_at
 from public.lga_text_posts t join public.profiles p on p.user_id=t.author_id
 where t.lga_id=l and t.status='active' and p.lga_id=t.lga_id
  and app_private.user_passes_platform_gate(t.author_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=t.author_id) or (b.blocker_id=t.author_id and b.blocked_id=u))
  and (p_before is null or (t.created_at,t.id)<(p_before,p_before_id))
 order by t.created_at desc,t.id desc limit 20;
end; $$;

create function public.delete_own_lga_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_text_posts set status='deleted',body='[deleted]',deleted_at=pg_catalog.now() where id=p_post_id and author_id=u and status='active';
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
end; $$;
revoke all on function public.create_lga_text_post(text),public.list_lga_text_posts(timestamptz,uuid),public.delete_own_lga_text_post(uuid) from public,anon,authenticated;
grant execute on function public.create_lga_text_post(text),public.list_lga_text_posts(timestamptz,uuid),public.delete_own_lga_text_post(uuid) to authenticated;
