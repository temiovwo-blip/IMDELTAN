# Authentication and onboarding security design

Status: design only; not implemented. Public registration is disabled. Legal and security approval is required before opening it. The `imdeltan-dev` project is a clean development environment, not production.

## Purpose

Supabase Auth provides identities and session issuance. The application separately decides whether a signed-in person can use the service. Neither possessing a valid access token nor seeing an enabled button is sufficient to access protected data.

## Account state machine

1. **Unregistered:** No platform identity. Public creation is disabled. Avoid claiming that disabled UI or a single provider toggle is enough: test the direct email, OTP and Google endpoints.
2. **Pending:** A test account or authorized invitation has authenticated, but cannot access protected application features. The user can only perform narrowly scoped onboarding actions after those actions are implemented and reviewed.
3. **Eligible and policy-complete:** A trusted onboarding operation has recorded an approved adult eligibility outcome, and acceptance exists for every currently required policy version. Admin-controlled account state is active.
4. **Suspended/revoked:** Database authorization denies protected access even if an old token has not expired. Terminate sessions where possible and audit the action.
5. **Deleted:** Account and related data are handled under an approved deletion and retention policy. Do not promise immediate removal from immutable backups.

Self-declaration establishes an assertion, not proof of identity. Never claim a date-of-birth field verifies age beyond the method used. The exact method, retention period and policy version are legal and product decisions.

## Required gate

Every protected read, write, server operation, and storage access must enforce all of: authenticated identity, active account, valid eligibility, current required policy acceptance, resource-specific permission, and applicable block/membership rules. An implementation must define an explicit fail-closed behavior if required policy versions or configuration are absent. When policy versions change or users are suspended, authorization must check current server-side state—not stale user-editable token claims.

Onboarding access requires carefully limited exceptions so people can accept policies without already being policy-complete. Privileged flags, role grants, eligibility outcomes and acceptance records must not be directly writable by clients without narrow trusted validation.

## Providers, registration and recovery

- Email/password: require confirmed email, suitable password policy, generic recovery responses, secure redirect allowlist and transactional email provider.
- Google: configure a new OAuth client for this project, restrict origins and callbacks, and test nonce/state handling. Verify that sign-in cannot create unauthorized accounts while registration is closed.
- Email OTP and SMS OTP: verify expected authentication and account-creation behavior with `shouldCreateUser`-equivalent settings where applicable. Add provider configuration, retry limits and cost controls. Protect against phone-number changes and SIM-swap risk; SMS alone is not sufficient recovery for privileged accounts.
- Recovery: avoid account enumeration; notify on security-sensitive changes; require recent authentication or additional factors for changes where supported. Define a manual recovery escalation, identity checks and audit trail before launch.
- CAPTCHA and rate limits: configure supported Auth endpoints and upstream controls, verify direct endpoint behavior and avoid relying exclusively on a bypassable application gateway.
- MFA: require verified MFA assurance for administrative operations, not merely an enrolled factor; offer customer TOTP. Define factor-loss and recovery procedures.
- Sessions: short-lived access tokens and securely managed refresh tokens, token rotation, revocation and reauthentication after risk events. Review native and browser storage separately.

## Audit and privacy

Log security events and decisions without passwords, OTPs, recovery links, bearer tokens, sensitive document images or full message bodies. Limit access and retention. The draft audit table is not currently append-only for all privileged database operators; tamper resistance, external log export and operational controls remain unimplemented.

## Security tests before access is enabled

Test from both browser and direct APIs, with anonymous users, pending users, valid users, blocked users, administrators at different MFA assurance levels and suspended users. Verify no protected data leaks through SQL tables, views, functions, storage objects or signed URLs. Test the current-policy transition and eligibility revocation with existing sessions. Test provider account creation while registration is disabled, rate limits, CAPTCHA, email confirmation, password recovery and MFA recovery. Test concurrency, replay and audit events. Independent security and legal review are required before public registration.
