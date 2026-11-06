-- Draft: eligible users can create and read only their own private text posts.
-- Community, friends/public visibility, editing, media and moderation are not enabled.
create policy eligible_user_reads_own_private_posts on public.posts
  for select to authenticated
  using (author_id = auth.uid() and audience = 'private' and status = 'active'
    and app_private.current_user_passes_platform_gate());
grant select (id, author_id, body, audience, status, created_at, updated_at) on public.posts to authenticated;

create function public.create_own_private_text_post(p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  clean_body text := pg_catalog.btrim(p_body);
  new_post_id uuid;
begin
  if current_user_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id=current_user_id for update;
  if not found or not app_private.user_passes_platform_gate(current_user_id) then
    raise exception 'Action not permitted' using errcode='42501';
  end if;
  if clean_body is null or pg_catalog.length(clean_body) not between 1 and 5000 then
    raise exception 'Invalid post' using errcode='22023';
  end if;
  insert into public.posts (author_id,body,audience,status)
    values (current_user_id,clean_body,'private','active') returning id into new_post_id;
  return new_post_id;
end;
$$;
revoke all on function public.create_own_private_text_post(text) from public, anon, authenticated;
grant execute on function public.create_own_private_text_post(text) to authenticated;
-- Direct INSERT/UPDATE/DELETE are not granted. Production release requires
-- direct API, auth, rate-limit, moderation, policy-race and abuse review.
