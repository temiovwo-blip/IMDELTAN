# IMDELTAN — clean-slate database architecture

Status: initial design; implementation and security review pending. This design does not depend on an earlier IMDELTAN database. Production access and registration remain closed until legal and security approval.

## Boundaries and principles

Supabase Auth is the authoritative identity provider. Application entities use UUID primary keys, `timestamptz` timestamps, foreign keys and explicit deletion rules. Public client access is denied by default. Every exposed table must have RLS enabled and policies tested using anonymous, authenticated, blocked and administrative identities. Private service operations are not exposed to the browser. Admin authorization is checked against server-controlled role assignments, not editable user metadata.

A newly authenticated identity is not automatically an eligible platform user. Protected application access requires an active account, adult eligibility and acceptance of all current mandatory policies. These gates must be enforced in database policies and trusted operations, including against direct API access. Public sign-up and provider-specific automatic account creation remain disabled until approval and verified end-to-end. Existing eligible users must still be able to authenticate when registration is closed; verify provider behavior and supported Auth hooks in staging before configuring production. Self-declared age is not proof of identity.

## Logical entities and purpose

All application-user references point to `auth.users(id)` unless otherwise stated. The eventual migrations will make types, cascading behavior and check constraints explicit.

### Identity, eligibility and preferences

- `profiles`: one-to-one with an Auth user; display name, handle, biography, picture references, optional LGA, account state and timestamps. Unique normalized handle. No authentication secrets.
- `user_eligibility`: one-to-one user record for eligibility outcome, method/version and verification time. Minimize date-of-birth retention; do not treat self-attestation as documentary proof.
- `user_privacy_settings`: one-to-one user preferences for profile, content and contact visibility, with restrictive defaults.
- `languages`: supported language codes and labels.
- `user_language_preferences`: user-to-language preferences and ordering, unique per user/language.
- `lgas`: authoritative LGA reference with stable code, name and state; reference data must be reviewed before import.
- `ethnic_groups`: optional reviewed reference values, not inferred from LGA or other attributes.
- `ethnic_group_consents`: user consent and withdrawal events, purpose, policy version and timestamp. Sensitive data access and retention require legal review. Consent is optional and withdrawal must be actionable.
- `user_ethnic_groups`: optional current user-to-group selection, separately protected and removable on withdrawal; never expose through a public profile by default.

### Social graph and content

- `friend_requests`: directional sender and recipient, status and timestamps; no self-requests; at most one pending request per unordered user pair, enforced transactionally.
- `friendships`: accepted relationship between two users with canonical UUID ordering and unique pair; no self-friendship. Accepting a request updates both records atomically.
- `user_blocks`: directional blocker and blocked user, unique pair and no self-block. Block checks apply to profiles, feeds, notifications, messaging and interactions, with explicit exceptions for safety and moderation.
- `posts`: author, text, audience, optional community, lifecycle state and timestamps. Community posts are posts linked to a community, not duplicate records. Audience and membership checks compose.
- `post_media`: ordered post attachments and references to validated storage objects; unique position within a post. Never accept arbitrary client-supplied bucket paths as proof of ownership.
- `videos`: media record, upload and processing state, duration and generated playback metadata. Associated with post media; validated transitions performed by trusted processing.
- `comments`: post, author, optional parent comment, body and lifecycle fields. Parent must belong to the same post, enforced by a composite foreign key or equivalent trusted constraint; maximum reply depth is a product decision.
- `reactions`: actor and reaction associated with exactly one post or comment. Use exclusive-target check constraints and partial uniqueness indexes.
- `saved_posts`: user-to-post bookmark, unique per pair; accessible only to its owner.

### Communities

- `communities`: name, description, visibility, lifecycle status and creator.
- `community_memberships`: community/user membership, role and status, unique pair. Enforce at least one owner through transactional workflows and controlled deletion, not a simple row check.

### Messaging and notifications

- `conversations`: conversation type and lifecycle metadata.
- `conversation_participants`: user membership and per-user read state, unique conversation/user. Participants may not add themselves to arbitrary conversations.
- `messages`: conversation, sender, body and timestamps. Sender must be an active participant; RLS prevents access by nonparticipants. This design does not provide end-to-end encryption.
- `message_attachments`: message-linked validated private storage object metadata; access follows conversation membership and message visibility.
- `notifications`: recipient, type, safe reference, timestamps and read state. Client may update only permitted fields, never forge arbitrary notifications.

### Safety, administration and compliance

- `user_reports`: reporter, target type/reference, reason and review status; access limited to reporter's permitted view and authorized reviewers. Validate targets using concrete foreign keys or trusted server logic.
- `moderation_records`: report or target, decision, action, actor, justification and timestamps; restricted access and retention.
- `admin_roles`: named role definitions and permissions. Changes controlled by privileged workflows.
- `admin_role_assignments`: server-controlled user-to-role assignments, with grantor and timestamps. Admin access requires role and appropriate MFA assurance.
- `audit_logs`: actor, action, target, result, time and minimal context. Append-only for application roles; retention and external export are operational requirements. Never store tokens, passwords or message bodies.
- `policy_versions`: policy identifier, version, content reference/hash, effective state and dates. Publishing is a privileged audited action.
- `policy_acceptances`: user, policy version, acceptance time and minimal evidence. A unique user/version constraint supports idempotency; a new mandatory version requires renewed acceptance.

## Access policy matrix

| Resource | Read | Write |
|---|---|---|
| Eligibility, privacy, preferences, saved posts | Owner; narrowly scoped authorized staff where justified | Owner for allowed preference fields; eligibility through trusted workflow |
| Profiles | According to privacy, blocks and account status | Owner for permitted fields; admin state changes through privileged workflow |
| Posts, comments, reactions and media | Only if audience, community membership and block checks pass | Eligible authorized users; owners or designated moderators for permitted actions |
| Friendship, request and block records | Relevant participants, subject to privacy rules | Authorized participant via validated transitions |
| Communities and memberships | According to community visibility and membership | Eligible users and community roles under defined rules |
| Conversations, messages and attachments | Active authorized participants only | Authorized participants; attachment creation follows validated upload |
| Reports and moderation | Reporter limited to own submissions; authorized staff for case details | Eligible reporter for submission; authorized staff for decisions |
| Roles and audit | Authorized administrators only | Trusted privileged operations; no client role self-grant |
| Policy versions and acceptance | Published policy readable as needed; acceptance owner/authorized staff | Publication privileged; acceptance bound to authenticated user |

The access matrix is a specification, not proof of protection. Implement policies with explicit SQL privileges and adversarial integration tests. Restrict `SECURITY DEFINER` functions, set a fixed search path, validate callers and avoid accidental RLS bypass. Test views and storage object policies independently.

## Indexes, triggers and operational rules

Index all frequently joined foreign keys, recipient/status/date inbox lookups, author/date and community/date feeds, comment post/date, message conversation/date, report status/date and audit actor/date. Add partial unique indexes for pending requests and mutually exclusive reaction targets. Validate query plans and avoid redundant indexes.

Use minimal, reviewed triggers for timestamps, safe profile initialization and audit events. Multi-row state changes such as accepting a friend request and last-owner transfers must be atomic. Notification fan-out and media processing must be idempotent and retryable; avoid expensive work in database triggers.

Deletion must distinguish user-initiated removal, moderation holds, policy retention and object cleanup. Auth identity deletion, database rows, media originals, derived files and eventual backup expiry must be covered by a tested deletion runbook. Exact retention periods require legal approval.

## Storage and recovery

Create new buckets for profile pictures, cover pictures, post images, community images, video uploads and message attachments. Default to private storage. Object access must reflect application authorization; signed URLs are short-lived and revocation may not be immediate. Validate content and size server-side, quarantine untrusted uploads, strip metadata as appropriate and track processing and deletion states. Public bucket use requires explicit privacy approval because individual object access cannot be reliably restricted after publication.

Use managed database backups appropriate to the paid plan, decide whether point-in-time recovery is required, and separately back up storage objects and relevant configuration. Restore database and media into an isolated environment on a schedule and measure RPO/RTO. Do not assume database backups include storage object contents. Secrets are restored from the provider's secret manager, never from Git.

## Deployment and launch gates

Development uses local or isolated resources; preview uses isolated temporary resources and synthetic data; staging and production use separate new projects and credentials. Version reviewed migrations in a new GitHub repository, test migrations from an empty database and restore upgrades, and deploy through environment-scoped CI with approval gates. No old migrations, credentials, records or resources are reused or modified.

Before production registration opens: legal approval of policies, age/consent and retention; security review and RLS/storage penetration tests; provider configuration and direct endpoint testing; MFA and account recovery testing; restore drill; abuse and incident response readiness; and explicit business approval.

## Open decisions

Hosting and GitHub ownership; geographic region; language list and authoritative LGA reference; product visibility defaults; video limits and processing provider; SMS/email/CAPTCHA providers; policy versions and legal basis; retention and backup targets; admin role definitions; actual upload and user volumes; separate Android application ID and signing custody.

## Local social draft additions (migrations 032–052; not deployed)

These are development designs, not guarantees of production behavior. All direct tables named below are RLS-enabled and client table grants are revoked; reviewed `SECURITY DEFINER` RPCs bind operations to `auth.uid()`, fixed search paths and platform eligibility checks. Explicit controls and simulated-role tests do not replace actual signed-in Supabase API, storage and provider tests.

- `lga_text_posts`: each text post references one author and LGA, has active/deleted/removed state and a bounded body. Partial LGA/time/UUID index supports newest-first pages; author/time index supports the basic rate limit. Display requires current same-LGA eligibility and block checks. A post removed from the feed does not imply erasure from backups or moderation records.
- `lga_post_comments` and `lga_post_likes`: comments reference one LGA post and author; likes use post/user as a composite primary key for one like per user. Feed/author indexes support page and rate lookups. Both are filtered for eligibility, LGA and two-way blocks. Comment/report and post/report foreign keys have restrictive deletion; limits and moderation remain drafts.
- `private_group_text_posts`: each post references a private LGA group and author, with bounded text, status and timestamps. Partial group/time/UUID and author/time indexes support access patterns. Only eligible active group members can view, subject to owner/group eligibility, same-LGA and blocks; former members' posts are currently hidden. These rules are provisional. Group reporting is separate from LGA reporting.
- `user_reports` carries exactly one concrete target, including LGA post, LGA comment, direct message or private-group post. Partial unique indexes prevent duplicate open reports per reporter/target and target indexes support moderation lookups. Moderator queues and actions require a server-checked role and MFA assurance. Group/message report queues expose the reported item, not the full group or conversation; reviewer-read auditing and operational access controls remain open.
- `saved_lga_text_posts` uses owner/post composite primary key and a user/time/post index for private paging. An owner can save only a currently visible LGA text post; a 300-item local-draft bound applies. Visible entries recheck current LGA, eligibility and blocks. A separate redacted unavailable list returns only IDs and timestamps, allowing owners to remove inaccessible saves without exposing content. Saved items are references, not independent permanent copies; unblocking could make an unremoved reference visible again.
- `notifications` uses restricted trigger-produced event references and recipient-scoped RPCs for friend requests, direct messages and group invitations. Partial unique and recipient/cursor indexes support the three types; notifications contain no message bodies. Current draft uses manual refresh, read/dismiss controls and no backfill, push or delivery guarantee. Dismissal deletes a notice only, not its underlying object. Notification data requires an approved retention/cleanup policy.
- For draft direct messages, a restricted pair table uniquely relates two sorted user IDs to one conversation. Message read/send requires current friendship, active participants and two-way block checks. The explicitly opened blocked-message safety view shows only messages received from people the viewer personally blocked, including messages hidden by a sender; it cannot send or reopen the thread. These messages are **not end-to-end encrypted**.
- A sender's message removal is a soft hide and intentionally retains content for safety reporting. For LGA posts/comments and private group posts, author deletion hides the item and redacts its active body only if no report exists; reported text remains for moderator review. Existing database/backups, audit, legal hold and report retention require legal and privacy decisions and a tested erasure workflow. Never describe these draft operations as guaranteed permanent deletion.

All user-facing social drafts require Vite DEV plus explicit opt-in and are absent from normal production customer builds. That switch is not an access-control boundary. The migrations and UI after 031 are local and require reviewed GitHub synchronization and controlled dev deployment before real-service tests; never apply directly to production or any old project.

### Local draft post editing (migration 053)

LGA and private-group text posts record a nullable `edited_at` timestamp. Author-only edit RPCs lock the relevant profile/post (and group/owner for group posts), validate current visibility and deny edits once any report exists, preventing subsequent changes to evidence. Feed and saved-list RPCs include an edited marker. No prior-body version history or edit throttling exists, so text changed before a report is not retained by this feature; moderation, retention and abuse policy decisions remain open.

### Local private-group likes and comments (054–055)

Private-group post likes are unique per user/post; summaries recheck the caller and count only eligible current members who can view the post and are not blocked by the caller, without returning identities. The current UI makes one summary request per post; batching and abuse resistance need review. Group comments have UUID/time keyset paging, server-side current group access and bilateral-block filtering, and a 20/hour author cap. The author's deletion redacts unreported bodies but retains bodies with reports; this is not guaranteed erasure from backups. Group-comment reports have duplicate-open prevention and a 10/hour cap, are isolated from generic report queues/actions, and use a dedicated MFA/role-gated moderator queue and audited, justified removal/triage. No comment replies, attachments, reviewer-read audit, approved retention policy or moderation appeals are provided. All changes are local development drafts, not deployed to Supabase.

### Batched private-group like summaries (migration 056)

The development group feed requests one bounded batch of at most 20 visible post IDs per page rather than issuing an initial summary request for each card. The security-definer RPC checks the caller's platform gate, independently rechecks current visibility of every requested post, omits inaccessible and unknown IDs, and counts only currently eligible, able-to-view, unblocked likers; it returns no liker identities. Duplicates collapse, empty arrays return no rows, and malformed or oversized arrays fail. The existing one-post summary remains in use after a like toggle. This lowers request count, not necessarily database work: counting still checks visibility per liker and has not been load-tested. Counts can become stale as membership/blocks change, and existing clients must refresh to recheck. This migration and UI are local development drafts only.

### Local group comment editing (migration 057)

An author may edit an active private-group comment only while they can currently view its parent group post. The RPC takes profile, group, post and comment locks in a consistent order and refuses edits after any report, without disclosing the reason; the comment list returns nullable `edited_at`. Report-first preserves the pre-report body; edit-first means the reported evidence is the new body. There is no prior-version retention or edit rate limit. The authorization and safety behavior remains a local draft pending real-service testing and legal/security review.

### Local LGA comments and like batching (058–059)

The author of an active LGA text comment may edit it only while currently able to view its parent post, and only if it has never been reported; `edited_at` is included in the comment list. Lock ordering covers relevant profiles, parent post and comment, preserving report-first evidence. No earlier-body history or edit throttling is provided. The bounded 20-ID LGA like-summary RPC checks caller eligibility and each post, omits unavailable IDs and uses the same liker eligibility, LGA and viewer-block filtering as the original single-post summary without exposing identities. The customer draft requests one batch per page and rechecks an individual summary after a toggle. The batching saves requests but still computes per-liker eligibility, is not load-tested, and open-screen counts may be stale. Both migrations are development-only and not deployed.

### Shared local text-edit limit (060)

A provisional 20-successful-edits-per-rolling-hour quota spans LGA and private-group posts/comments. The four existing author-only edit RPCs validate current access and report-evidence protection, then call an inaccessible private helper; profile-row locking serializes a user's edits even across content types. A transactionally inserted event stores the user and wall-clock time, not the edited content or target. Failed/rolled-back requests consume no quota. Expired events are pruned only when the user next edits; inactive-user records need an approved retention/cleanup policy. Cascading this event table on auth deletion does not implement general account erasure. The threshold is provisional, history is still not versioned, and this is not comprehensive rate limiting or production security approval.

### Local group rejoining (061)

New voluntary leaves transition a member from `active` to `left`; ambiguous preexisting `removed` rows remain removed and cannot be reactivated by invitation. A new owner invitation and explicit recipient acceptance can reactivate a `left` member after current group, eligibility, LGA, privacy-at-send and block checks. Rejoining updates `joined_at`, and existing posts/comments/likes may be visible again; no history is erased. An invitee who declines a rejoin invitation has a provisional seven-day per-group repeat-invitation cooldown. New notices and list results preserve the same scope filters. The opt-in development client provides visibility warnings, while normal builds hide this flow; the client flag is not a server-side authorization boundary. Legacy membership repair, harassment handling, moderation, policies and real-service security testing remain unresolved.

### Local owner membership controls (062)

A current, gated private-group owner may page through active eligible members in the same LGA who are not blocked by or blocking the owner; the response contains user ID, display name and join time. This owner-only membership disclosure is a provisional privacy decision, not general member discovery. Owner removal uses profile/group locks, validates the same owner/target scope, transitions active `member` to `removed`, cancels pending invitations and writes an audit record naming actor, group and target. Removed members cannot use the voluntary-`left` rejoin path, and their previously authored material is filtered from current group views but retained in the database and backups. Blocked/ineligible/out-of-LGA members cannot be listed or removed by this draft control; no notice, appeals or restoration path is implemented. The UI is explicitly development-only; this is not production approval.

### Local owner-removal notices (063)

Successful group-owner removal atomically inserts a private removal event and recipient-scoped notification; neither stores comment/post text or a reason. The recipient's list exposes a group name only if the active private group, current eligible owner, same-LGA profiles and bilateral block checks pass; otherwise it returns a generic notice. Mark-read and clear operate only on the recipient's notice; clearing does not change membership or delete the underlying event. There is no push, email, backfill, reason, appeal or restoration. The event and audit retention/cleanup policy, and general account erasure, remain unresolved; the feature is local and development-only.
