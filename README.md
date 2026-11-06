# IMDELTAN — clean-slate rebuild

This repository is a new foundation, independent of previous projects and infrastructure. No old data, credentials or migrations are imported.

## Current status

The initial architecture and a deliberately default-deny identity/policy migration are drafted. This is not a functioning application or a production-ready backend. The migration has not yet been run or verified against Supabase. No deployment or registration has been enabled.

- `docs/database-architecture.md`: proposed entities, security and operational design.
- `supabase/migrations/`: new migrations, starting with the identity foundation.
- `.env.example`: names and descriptions only. Never put real secrets in this file or in Git.

## Safety and release constraints

Use new, isolated Supabase projects and environment-specific credentials. Never connect this repository to the old project. Service-role credentials are server-side secrets only. Public registration remains closed until legal and security approval, endpoint-level testing and explicit release approval. Existing infrastructure must remain untouched.

The initial migration creates RLS-enabled tables and revokes application-role access. Features, reviewed policies, eligibility enforcement, authentication configuration, storage, tests, backup workflows and deployment infrastructure remain to be implemented. Do not apply to a production environment without review and successful isolated testing.

Android is a separate new application (Option B); its application ID and signing custody remain to be established with the owner.
