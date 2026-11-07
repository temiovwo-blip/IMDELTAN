-- Development-only: serialize reporting with blocks in both directions.
create or replace function public.report_lga_text_post(p_post_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); l uuid; author uuid; target public.lga_text_posts%rowtype; reason_clean text:=pg_catalog.btrim(p_reason); result_id uuid; recent int;
begin
 if u is null or p_post_id is null then raise exception 'Action not permitted' using errcode='42501';end if;
 select t.author_id into author from public.lga_text_posts t where t.id=p_post_id;
 if author is null then raise exception 'Action not permitted' using errcode='42501';end if;
 -- Lock both members in deterministic order, matching block_user.
 perform 1 from public.profiles p where p.user_id in (u,author) order by p.user_id for update;
 select p.lga_id into l from public.profiles p where p.user_id=u;
 if l is null or not app_private.user_passes_platform_gate(u) then raise exception 'Action not permitted' using errcode='42501';end if;
 if reason_clean is null or pg_catalog.length(reason_clean) not between 1 and 2000 then raise exception 'Invalid report' using errcode='22023';end if;
 select * into target from public.lga_text_posts t where t.id=p_post_id and t.status='active' for update;
 if not found or target.author_id=u or target.lga_id<>l
  or not app_private.user_passes_platform_gate(target.author_id)
  or not exists(select 1 from public.profiles p where p.user_id=target.author_id and p.lga_id=l)
  or exists(select 1 from public.user_blocks b where (b.blocker_id=u and b.blocked_id=target.author_id) or (b.blocker_id=target.author_id and b.blocked_id=u)) then
  raise exception 'Action not permitted' using errcode='42501';end if;
 select count(*) into recent from public.user_reports r where r.reporter_id=u and r.created_at>pg_catalog.now()-interval '1 hour';
 if recent>=10 then raise exception 'Please try again later' using errcode='P0001';end if;
 insert into public.user_reports(reporter_id,reported_lga_post_id,reason) values(u,p_post_id,reason_clean)
 on conflict (reporter_id,reported_lga_post_id) where reporter_id is not null and reported_lga_post_id is not null and status in ('open','reviewing')
 do nothing returning id into result_id;
 -- Do not expose the existing report ID to callers.
 return result_id;
end; $$;

