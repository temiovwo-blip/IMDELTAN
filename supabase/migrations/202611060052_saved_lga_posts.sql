-- Development-only saved LGA text posts. The save is private to its owner.
-- No media, cross-LGA access, permanent archive, or production approval.
create table public.saved_lga_text_posts(
 user_id uuid not null references auth.users(id) on delete restrict,
 post_id uuid not null references public.lga_text_posts(id) on delete restrict,
 created_at timestamptz not null default pg_catalog.now(),
 primary key(user_id,post_id)
);
create index saved_lga_text_posts_cursor_idx on public.saved_lga_text_posts(user_id,created_at desc,post_id desc);
alter table public.saved_lga_text_posts enable row level security;
revoke all on public.saved_lga_text_posts from public,anon,authenticated;
create function public.save_visible_lga_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();author uuid;n int;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select t.author_id into author from public.lga_text_posts t where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id in(u,author) order by p.user_id for update;
 perform 1 from public.lga_text_posts t where t.id=p_post_id for update;
 if not app_private.can_view_lga_post(u,p_post_id) then raise exception 'Action not permitted' using errcode='42501';end if;
 if exists(select 1 from public.saved_lga_text_posts s where s.user_id=u and s.post_id=p_post_id) then return;end if;
 select count(*) into n from public.saved_lga_text_posts s where s.user_id=u;
 if n>=300 then raise exception 'Saved post limit reached' using errcode='P0001';end if;
 insert into public.saved_lga_text_posts(user_id,post_id) values(u,p_post_id);
end; $$;
create function public.list_own_saved_lga_text_posts(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,author_id uuid,author_name text,body text,saved_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select t.id,t.author_id,coalesce(nullif(pg_catalog.btrim(p.display_name),''),'Community member'),t.body,s.created_at
 from public.saved_lga_text_posts s join public.lga_text_posts t on t.id=s.post_id join public.profiles p on p.user_id=t.author_id
 where s.user_id=u and app_private.can_view_lga_post(u,t.id)
 and (p_before is null or (s.created_at,s.post_id)<(p_before,p_before_id)) order by s.created_at desc,s.post_id desc limit 20;
end; $$;
create function public.remove_own_saved_lga_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Idempotent and does not reveal whether another person's saved item exists.
 delete from public.saved_lga_text_posts s where s.user_id=u and s.post_id=p_post_id;
end; $$;
revoke all on function public.save_visible_lga_text_post(uuid),public.list_own_saved_lga_text_posts(timestamptz,uuid),public.remove_own_saved_lga_text_post(uuid) from public,anon,authenticated;
grant execute on function public.save_visible_lga_text_post(uuid),public.list_own_saved_lga_text_posts(timestamptz,uuid),public.remove_own_saved_lga_text_post(uuid) to authenticated;
-- Redacted unavailable items let the owner free space without exposing posts
-- hidden by blocks, removal, account eligibility or LGA changes.
create function public.list_own_unavailable_saved_lga_text_posts(p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,saved_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if (p_before is null)<>(p_before_id is null) then raise exception 'Invalid cursor' using errcode='22023';end if;
 return query select s.post_id,s.created_at from public.saved_lga_text_posts s
 where s.user_id=u and not app_private.can_view_lga_post(u,s.post_id)
 and (p_before is null or (s.created_at,s.post_id)<(p_before,p_before_id)) order by s.created_at desc,s.post_id desc limit 20;
end; $$;
revoke all on function public.list_own_unavailable_saved_lga_text_posts(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_own_unavailable_saved_lga_text_posts(timestamptz,uuid) to authenticated;
