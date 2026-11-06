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
