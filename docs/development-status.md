# Development status

Updated 2026-11-06. This is an incomplete development foundation, not a production-ready application. Public registration remains closed; do not invite testers yet. Adult self-declaration is not independent age verification. Legal and security approvals are required before launch.

## What exists

- The workspace contains draft migrations through 031 and early customer and administrator web apps. The customer app includes draft onboarding and private text notes. The admin app includes a draft report review flow and a challenge for an already-enrolled TOTP factor. Both need configuration, real-service integration, further features and review. Do not use real credentials, reports or personal data in these scaffolds.
- A disposable local PostgreSQL 17 database applied the exact migrations and passed the database workflow's selected behavioral checks with synthetic identities and simulated auth, claims and storage. These include onboarding status, private posts, report review with simulated MFA, block recording and the self-only block list. Static checks and both frontend builds have also passed.
- These tests are not a real Supabase/API test, an end-to-end test, a security audit or proof of production readiness. Blocks are only recorded: they are not enforced across profiles, feeds, requests, messaging or storage. Privacy settings are not enforced throughout. Report review does not itself remove content or suspend users. Admin MFA enrollment and recovery are not built.

## Environments and synchronization

- The new `imdeltan-dev` project is separate from old resources. At last check, signup, Google, phone and anonymous authentication were disabled; no migrations were permanently applied. Earlier limited SQL tests were rolled back. Do not apply drafts to production.
- GitHub is the intended source of truth. Workspace changes since migration 018—including migrations 019–031, apps, tests and workflow updates—have not yet been uploaded. Direct GitHub access is unavailable; batch reviewed synchronization to reduce manual work.
- Development, preview, staging and production separation, secure deployment, storage policies and validation, monitoring, backups and recovery still require implementation and verification. Never store privileged keys in frontend code or ask for passwords or keys in chat. Do not use old project resources.

## Next work

Continue building and testing the remaining social features, media, notification and messaging safety, full block and privacy enforcement, auth providers, administrator controls and mobile packaging. Run real-service integration and security tests before any tester invitation; complete legal and security launch gates before public signup. Treat every UI example and draft feature as non-production until verified.

## Development authentication connection

The local customer and administrator apps are configured with the new development project URL and its publishable (browser-safe) key, in Git-ignored `.env.local` files. No privileged key was put in frontend configuration. The real Supabase Auth settings endpoint responded; a synthetic signup attempt was refused with `signup_disabled`, and an invalid synthetic sign-in was rejected. This verifies connectivity and negative authentication checks only. No accounts were created. Application migrations have not been deployed; application RPCs and data flows are not connected end-to-end, and no real authenticated user, MFA flow, RLS, storage or app interaction has been tested. Never use real credentials or personal data in these previews. Public signup remains disabled.

## Android development

A Capacitor Android scaffold exists with a separate provisional development application ID. A debug APK compiled and its signature verified locally, but it has not been installed or tested on a device and is not for distribution. The build and SDK caches are temporary; the source and build workflow are in the workspace and not yet synced to GitHub. A separately managed release signing key and safe direct-install testing process remain to be established. See `docs/android-development.md`.

## Owner-only sign-in experiment

A debug Android APK configured with the new dev project public URL and publishable key is saved outside the repository for a limited owner sign-in attempt. It has not been installed on a device or verified with a successful login. It must not be shared as a tester or production build. Database migrations are still absent; onboarding and other data features will fail. Registration is closed. A private dev-only account must be created through the Dashboard to attempt sign-in. Use a unique temporary password, and do not send it in chat.

## Social graph draft

Migration 023 drafts sending and responding to friend requests and coordinates those operations with blocking using ordered profile locks. In the disposable PostgreSQL behavioral checks, duplicates, privacy, direct forgery, third-party acceptance, pending-account access, blocks, severing friendships, request cancellation, changed privacy and decline were tested. A block is still not enforced across discovery, content, messaging or storage. Real Supabase/API, concurrency, policy-race, rate limiting, abuse controls and a security review remain before use. This migration has not been deployed.

## Privacy interface draft

The customer app has a draft form for the existing own-privacy RPCs. DOM tests with a mocked client cover loading, saving and clearing on sign-out, including a late response after sign-out. The form explicitly warns that settings are not enforced throughout the app. No real Supabase privacy API or browser/device end-to-end testing has been performed.

## Private note management draft

Migration 025 adds guarded editing and removal of own private text notes, with live row text cleared on removal. Backups and database logs may retain old content; this is not complete erasure. Isolated PostgreSQL tests covered own edit/delete, blank input, other-user and pending-user denial, direct update denial and deleted-row invisibility. Mocked DOM tests checked safe text rendering and the edit/delete calls. No real Supabase or device end-to-end test has been performed.

## Profile interface draft

The customer app now includes a self-profile editor backed by existing self-read rules and the update-own-profile RPC. Mocked DOM tests cover loading, username normalization and conflicts, saving only intended fields, and clearing on sign-out. The backend remains undeployed, and real API, privacy enforcement, browser and Android end-to-end tests remain.

## Concurrent block/request test

The disposable PostgreSQL integration workflow now runs two real concurrent database sessions in both orders: block while a friend request is attempting to start, and a friend request followed by a block. The test checks that the second session actually waits on a database lock and that the resulting state has the block and no pending request. Both cases passed locally with simulated identities. This checks only those two races; it does not cover every policy, account, messaging, storage or Supabase/API race, and the migration remains undeployed.

## LGA communities and groups

Following the owner’s direction, migration 026 seeds 25 Delta LGA communities, adds a default-deny nested group table and self-only LGA selection, and requires a valid selection for pending-account activation. The customer draft includes an LGA selector and shows the selected LGA to its owner. Disposable PostgreSQL and mocked DOM checks passed; no real Supabase deployment or other-user profile visibility is enabled. Group creation/membership and community content remain unimplemented. No ethnicity is inferred from the LGA. See `docs/community-design.md`.

## Private group creation draft

Migration 027 adds default-deny group memberships and self-bound private group creation in the creator’s selected LGA, recording the owner atomically. The customer form and mocked DOM checks cover creation and safe rendering. The isolated database workflow tests the scope, privacy and denial paths. This does not yet add joining, invitations, group posts or moderation, and remains undeployed and unreviewed against real Supabase/API behavior.

## Group ownership controls draft

Migration 028 adds owner-only group name/description editing and archiving. Archiving hides a group from the active list but does not delete its data or implement restoration. Isolated PostgreSQL checks cover ownership, invalid input, direct-table denial and archived-state behavior; mocked UI tests cover the edit and archive controls. This remains undeployed and is not a real Supabase security test.

## Private group invitations draft

Migration 029 drafts same-LGA, owner-sent private group invitations with accept/decline, eligibility and block checks. The temporary same-LGA limit is not a final product decision. Local simulated database checks cover duplicates, access isolation, acceptance, blocks, archiving and decline; mocked DOM tests cover the recipient interface. Member search, an owner-facing invite UI, group content, abuse controls and block behavior among existing group members remain to be implemented and reviewed. No real Supabase deployment or API security testing has occurred.

## Joined groups draft

Migration 030 and the customer draft show eligible members their accepted groups and let them leave. Unavailable groups, including those whose owner is blocked, appear only as redacted memberships so members can leave without seeing group details. Rejoining after leaving, access when the member is suspended or no longer eligible, group content, full block enforcement, and real-service authorization still require design and review. Isolated PostgreSQL checks and mocked UI checks passed; the migration is not deployed.

## Group invitee lookup draft

Migration 031 adds exact-handle lookup for group owners, limited to eligible people in the same LGA with public-profile and member-contact settings. It excludes blocks and existing memberships, limits searches to 12 per minute per caller in the database, and rechecks target privacy at invitation time. Simulated PostgreSQL checks cover isolation, blocks, preference changes, same-LGA restrictions and the search limit. Mocked UI tests cover lookup and invitation from the owner’s group card. Direct invitation rate limits and broader abuse controls are still missing; do not expose this draft for real use. The same-LGA limit remains a temporary assumption. No real-service security testing or deployment has occurred.
