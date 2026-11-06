# IMDELTAN — independent rebuild

IMDELTAN is a clean-slate social platform under development. It must not connect to or alter the earlier project, data, credentials or infrastructure. The owner chose a separate Android identity and signing arrangement (Option B).

## Current state

The repository contains draft Supabase migrations, customer and administrator web apps, a development Android wrapper, design previews and automated checks. The new development Supabase Auth service has been reached using only its publishable client key, but the application migrations have not yet been applied there and end-to-end app flows are not verified. Local PostgreSQL integration tests simulate parts of Supabase; they are not a security audit. Public registration remains closed. Do not use real credentials, personal content or reports in development previews.

The product direction includes 25 Delta State LGA communities and groups within them. A person selects their LGA in account setup; no ethnicity is inferred. Some features are only drafts and many visible feed items are examples. See `docs/development-status.md` and `docs/community-design.md` for specifics and outstanding safety work.

## Structure

- `apps/customer/`: customer web and Android development scaffold.
- `apps/admin/`: admin web scaffold.
- `supabase/migrations/`: ordered database migrations; none are production-approved.
- `supabase/config.toml`: local CLI configuration, not proof of remote configuration.
- `tests/` and `.github/workflows/`: static, UI, build and simulated-database checks.
- `docs/`: architecture, safety, design and development status.
- `.env.example`: variable names and descriptions only.

## Guardrails

Use new, isolated environments with environment-specific configuration. Never place a service-role key or private signing material in frontend code, Git or chat. Public registration requires legal and security approvals. Adult self-declaration is not independent proof of age. The development-only migration preview workflow requires manual invocation and runs `supabase db push --dry-run`; it does not deploy changes. Never deploy drafts to production or invite testers using real data before the documented safety and testing gates are met.

See `docs/android-development.md` for direct-install APK preparation and `docs/security-test-plan.md` for test scope and limitations.
