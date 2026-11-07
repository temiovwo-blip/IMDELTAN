-- Development draft: preserve reported LGA post/comment evidence when the
-- author deletes the item. Unreported items are redacted. Not data erasure:
-- reported text, records and backups require an approved retention policy.
create or replace function public.delete_own_lga_text_post(p_post_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.lga_text_posts t where t.id=p_post_id and t.author_id=u and t.status='active' for update;
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_text_posts t set status='deleted',body=case when exists(select 1 from public.user_reports r where r.reported_lga_post_id=t.id) then t.body else '[deleted]' end,deleted_at=pg_catalog.now() where t.id=p_post_id;
end; $$;
create or replace function public.delete_own_lga_post_comment(p_comment_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_comment_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.profiles p where p.user_id=u for update;
 if not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 perform 1 from public.lga_post_comments c where c.id=p_comment_id and c.author_id=u and c.status='active' for update;
 if not found then raise exception 'Action not permitted' using errcode='42501';end if;
 update public.lga_post_comments c set status='deleted',body=case when exists(select 1 from public.user_reports r where r.reported_lga_comment_id=c.id) then c.body else '[deleted]' end,deleted_at=pg_catalog.now() where c.id=p_comment_id;
end; $$;
