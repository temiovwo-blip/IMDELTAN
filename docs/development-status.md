# Development status

The clean development project is `imdeltan-dev`; it is not staging or production. Registration is disabled. Google and phone providers are disabled. Do not enable public registration until legal and security approvals and launch testing are complete.

The first migration is a default-deny draft. On 2026-11-06, an equivalent SQL sequence was exercised in an explicit transaction against the new development project, checking creation, RLS flags on five tables, and selected client privilege revocations; the transaction was rolled back. It is not applied and no migrations were recorded. This was a limited smoke test, not a full security or functional review: SQL constraints, all table privileges and denial paths, onboarding, policies, storage, and concurrency still need comprehensive automated integration tests. The offline tests in `tests/` are additional structural checks, not security verification.

GitHub is the source of truth. The workspace cannot push directly to GitHub; reviewed files must be committed through an authorized GitHub workflow. Do not apply draft migrations to production. Do not use old project resources or production credentials. Auth configuration, media buckets, applications, CI deployment, backups, monitoring and most schema remain incomplete.
