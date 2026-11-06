# IMDELTAN security and database test plan

Status: planned, except where explicitly noted. Public registration stays disabled. No customer or admin application is ready for use.

## Completed limited smoke checks

- The identity/policy migration's equivalent SQL was executed against `imdeltan-dev` in an explicit rolled-back transaction; creation, RLS flags and selected client grants were checked.
- The social/content migration's equivalent SQL was executed against `imdeltan-dev` in an explicit rolled-back transaction; six RLS flags, anonymous SELECT and authenticated INSERT privileges were checked. The test did not exercise client requests or real row access.
- Python static guardrails run locally and on GitHub Actions. They check migration text and do not establish runtime security.

These checks do not apply or record migrations and are not approval for production deployment.

## Required before applying migrations to shared environments

1. Execute the exact migration files in a disposable, isolated PostgreSQL/Supabase test environment, in sequence, and verify deterministic fresh installs. Assert migration history and transactional failure behavior.
2. Check every exposed table has RLS, no unexpected policies, and no privileges for `anon` or `authenticated`; verify against actual JWT/API requests as well as PostgreSQL role checks.
3. Verify check constraints, foreign keys, unique indexes and realistic deletion behavior with synthetic users and data; verify comments cannot cross posts. Test nested comment deletion, cycles on update, and define whether replies have a maximum depth. Make the write interface prevent cycles.
4. Test public/private/friends/community visibility, ownership, membership, blocks, account suspension, current policy acceptance and adult eligibility once those features and policies exist. Negative tests must cover direct Supabase API and storage access, not just the UI.
5. Verify authorization and MFA assurance for every admin workflow, and forbid client role assignment or alteration of server-controlled state. Test abuse of SECURITY DEFINER functions and explicit SQL grants.
6. Test auth signup closure through all enabled providers, recovery, OTP, CAPTCHA, rate limits and MFA, including direct endpoints; re-test after configuration changes.
7. Test storage object access and signed-URL behavior, upload validation, size limits, object cleanup and backup restoration.
8. Test simultaneous requests for friendship, duplicate reactions and owner transfers. Audit transactional invariants, deletion and retention decisions.
9. Run dependency scanning, secret scanning, linting and integration tests on pull requests. Stage a clean restore and document results before any production launch.

## Safe test data and access

Use synthetic users and no production data. Never log or commit passwords, tokens, service keys, SMS codes or sensitive personal information. Test projects and credentials must be separate from any old infrastructure. Any migration applied to development must be traceable to the reviewed GitHub file and migration history; do not run draft SQL directly in production.
