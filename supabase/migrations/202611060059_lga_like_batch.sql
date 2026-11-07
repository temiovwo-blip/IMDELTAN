-- Development-only bounded LGA like summaries, equivalent to the single RPC.
create function public.get_lga_post_like_summaries(p_post_ids uuid[])
returns table(post_id uuid,like_count bigint,liked_by_me boolean)
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if p_post_ids is null or pg_catalog.cardinality(p_post_ids)>20 or coalesce(pg_catalog.array_ndims(p_post_ids),1)<>1 then raise exception 'Invalid post list' using errcode='22023';end if;
 if pg_catalog.array_position(p_post_ids,null::uuid) is not null then raise exception 'Invalid post list' using errcode='22023';end if;
 return query select ids.id,summary.like_count,summary.liked_by_me
 from (select distinct x.id from pg_catalog.unnest(p_post_ids) as x(id)) ids
 cross join lateral (
  select pg_catalog.count(*) as like_count,coalesce(pg_catalog.bool_or(l.user_id=u),false) as liked_by_me
  from public.lga_post_likes l join public.profiles p on p.user_id=l.user_id join public.lga_text_posts t on t.id=l.post_id
  where l.post_id=ids.id and p.lga_id=t.lga_id and app_private.user_passes_platform_gate(p.user_id)
  and not exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=u))
 ) summary where app_private.can_view_lga_post(u,ids.id);
end; $$;
revoke all on function public.get_lga_post_like_summaries(uuid[]) from public,anon,authenticated;
grant execute on function public.get_lga_post_like_summaries(uuid[]) to authenticated;
