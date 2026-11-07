-- Read-only counts only. This SQL cannot identify the connected project.
-- Caller MUST independently verify the target is uxfyhpukeqttrvcfemts.
-- A clean result is not proof the project contains no other sensitive data.
SELECT (SELECT count(*) FROM auth.users) AS auth_users,
       (SELECT count(*) FROM public.policy_versions WHERE mandatory AND published_at IS NOT NULL AND published_at <= now() AND retired_at IS NULL) AS current_mandatory_policies,
       (SELECT count(*) FROM public.policy_versions) AS policy_versions,
       (SELECT count(*) FROM public.profiles) AS profiles,
       (SELECT count(*) FROM public.posts) AS posts,
       (SELECT count(*) FROM public.lgas WHERE state_name='Delta') AS delta_lgas,
       (SELECT count(*) FROM public.lga_communities) AS lga_communities,
       (SELECT count(*) FROM storage.objects) AS stored_objects;
