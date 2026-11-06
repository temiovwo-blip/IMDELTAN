# IMDELTAN administrator app — early scaffold

This is an incomplete, unreviewed development app. Do not deploy to real users or use real reports. A draft email/password sign-in, already-enrolled TOTP MFA challenge and report-list/review interface are implemented but remain unconfigured and untested against Supabase. MFA enrollment and recovery, stronger session management, role management, other moderation actions, rate limits, monitoring and direct API security tests remain incomplete.

Run `npm ci` and `npm run dev`. Only the new environment's public `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` may be supplied via approved configuration. Never put server credentials in frontend code. Administrative privileges must be enforced by reviewed server-side rules, never only by this interface. The initial migrations are not applied to the development project.

## Local development connection (2026-11-06)

The Git-ignored local configuration now contains the new development project URL and its publishable key. Authentication connectivity and rejection of a synthetic signup and invalid login were checked against the real service. This does not establish successful sign-in, MFA, database authorization or end-to-end application functionality. The migrations have not been applied; do not use actual accounts or personal data. Public signup remains disabled. Only public browser-safe values are in local frontend configuration.
