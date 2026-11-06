# IMDELTAN customer app — early development

This is incomplete and not production-ready. The feed and navigation are illustrative; posts, communities, messages and safety controls are not implemented. Registration remains closed. This is not an Android or iOS application.

Run `npm ci` and `npm run dev`. Sign-in remains disabled unless `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` are provided through an approved environment-specific configuration workflow. Use only public values for the new project; never put a service-role key in the browser or Git.

Email/password sign-in is an unreviewed draft. Google, OTP, CAPTCHA, recovery, MFA, onboarding, data access and direct API tests remain incomplete. Auth tokens currently use browser sessionStorage; this does not protect against XSS. Production session design, security headers, CSP, redirect configuration, authorization and security review remain required. The migrations are not applied to the development project.

A draft private-text-post interface and accompanying SQL migration are present, but depend on migrations, onboarding and policies that have not been deployed. Never use them for real or sensitive data. They need comprehensive integration, RLS, moderation and security review. The public sample feed remains illustrative.

An onboarding interface draft now calls draft SQL operations for self-declared adult eligibility and acceptance of required policies. It does not verify policy document integrity, independently verify age, or establish legal compliance. Policy links and consent wording need legal and security review. Do not connect real accounts or use real user information.

## Local development connection (2026-11-06)

The Git-ignored local configuration now contains the new development project URL and its publishable key. Authentication connectivity and rejection of a synthetic signup and invalid login were checked against the real service. This does not establish successful sign-in, MFA, database authorization or end-to-end application functionality. The migrations have not been applied; do not use actual accounts or personal data. Public signup remains disabled. Only public browser-safe values are in local frontend configuration.
