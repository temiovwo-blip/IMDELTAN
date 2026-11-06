-- Draft self-only management for private text notes; not a general post editor.
-- Client roles never receive direct UPDATE/DELETE permission.
create function public.edit_own_private_text_post(p_post_id uuid,p_body text)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); body_clean text:=pg_catalog.btrim(p_body);
begin
  if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id=u for update;
  if not found or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  if body_clean is null or pg_catalog.length(body_clean) not between 1 and 5000 then raise exception 'Invalid post' using errcode='22023'; end if;
  update public.posts p set body=body_clean,updated_at=pg_catalog.now()
    where p.id=p_post_id and p.author_id=u and p.audience='private' and p.status='active' and p.community_id is null;
  if not found then raise exception 'Action not permitted' using errcode='42501'; end if;
end; $$;
create function public.delete_own_private_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
  if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501'; end if;
  perform 1 from public.profiles p where p.user_id=u for update;
  if not found or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501'; end if;
  -- Remove live text and hide the record; this does not erase logs, backups or WAL.
  update public.posts p set body='',status='deleted',updated_at=pg_catalog.now()
    where p.id=p_post_id and p.author_id=u and p.audience='private' and p.status='active' and p.community_id is null;
  if not found then raise exception 'Action not permitted' using errcode='42501'; end if;
end; $$;
revoke all on function public.edit_own_private_text_post(uuid,text) from public,anon,authenticated;
revoke all on function public.delete_own_private_text_post(uuid) from public,anon,authenticated;
grant execute on function public.edit_own_private_text_post(uuid,text) to authenticated;
grant execute on function public.delete_own_private_text_post(uuid) to authenticated;
-- Storage deletion, retention, audit, direct API and concurrent behavior require review.
