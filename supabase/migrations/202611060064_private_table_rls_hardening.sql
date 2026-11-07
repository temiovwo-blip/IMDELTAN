-- Development-only defence in depth. These app_private tables already revoke
-- direct client grants, but lacked RLS. Enable it without adding any client
-- policies; table owners / bypass roles remain privileged, so this does not
-- replace careful SECURITY DEFINER review or real-service authorization tests.
-- Do not FORCE RLS: the existing owner-executed internal functions need access.
alter table app_private.group_invite_lookup_attempts enable row level security;
alter table app_private.group_invitation_sends enable row level security;
alter table app_private.direct_conversation_pairs enable row level security;
alter table app_private.friend_lookup_attempts enable row level security;
alter table app_private.friend_request_sends enable row level security;
revoke all on app_private.group_invite_lookup_attempts, app_private.group_invitation_sends,
 app_private.direct_conversation_pairs, app_private.friend_lookup_attempts,
 app_private.friend_request_sends from public, anon, authenticated;
