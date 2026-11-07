# Synthetic-only Android test build — local draft

This document describes an unfinished local build path, **not an APK, deployment, authorization approval, or public-release plan**. Current installed APK is unchanged. Public registration stays closed. Do not use real users, personal information or sensitive data in social drafts.

## Build isolation

Customer `src/main.js` enables draft social screens only when the explicit social flag is `true` **and** the app is either running on the local development server or built with `imdeltan-synthetic-apk` mode. A standard production build excludes checked draft code even when the social flag is set. Standard builds refuse a non-production `NODE_ENV` to prevent accidental Vite development behavior.

The dedicated `npm run build:synthetic-web` command produces **web assets only**, not an APK. Its mode is build-only and requires all of the following configuration in the local build environment:

- `IMDELTAN_SYNTHETIC_ONLY_CONFIRM=SYNTHETIC-ONLY-ISOLATED-PROJECT`.
- `IMDELTAN_SYNTHETIC_PROJECT_REF` must equal `uxfyhpukeqttrvcfemts`, the dedicated **synthetic-only** Supabase project, never the existing shared dev project or production/old infrastructure.
- `VITE_SUPABASE_URL` exactly matches `https://<that-ref>.supabase.co`.
- `VITE_SUPABASE_PUBLISHABLE_KEY` is a publishable key for that project, never an admin/service/secret key.
- `VITE_ENABLE_SOCIAL_DRAFTS=true`.

The configuration is pinned to the dedicated synthetic project ref and exact URL and rejects all other targets, missing confirmation, non-publishable keys and missing flag. A ref allowlist cannot prove the project continues to contain only synthetic data, or that an arbitrary publishable key belongs to it. Verify ownership, isolation, account/data inventory and billing implications before creating fixtures or building. Do not paste credentials into chat. A client flag or banner is not a security control; server access rules and controlled data remain mandatory.

A distinct in-app warning identifies synthetic mode and tells testers not to use real accounts or personal data. The first local Android packaging test used a fictional project ref and key before the target pin was added. The latest local web-mode tests use the dedicated project ref with a fake key and do not contact Supabase. Neither establishes actual service security.

## Remaining before an APK can be delivered

1. Maintain the newly created `imdeltan-synthetic-test` as a genuinely synthetic-only project, verify free-plan allowance and billing before any extra cost, and keep staging/production and old infrastructure separate. Signup is disabled and a read-only check found zero auth users, public tables, storage buckets or applied migrations. Recheck before any fixtures or changes.
2. Complete a reviewed development-only migration and fixture plan. Synthetic terms/policy fixtures, if used, must be unmistakably test-only, stay in the isolated test project, and never be represented as legal policies; public signup must remain closed. Provision and delete synthetic identities through a controlled process without exposing credentials.
3. Review and device-test the new **native Android** guardrails. Locally, the synthetic flag sets app ID `com.imdeltan.community.dev.synthetic` and label `IMDELTAN Synthetic Test`; a generated web marker and Gradle checks reject mismatched debug assets/property and reject synthetic release builds. This is protection against mistakes, not tampering. A fictional-target debug APK built locally with the distinct identity and marker, but it is not useful for signing in and has not been installed on a phone. Confirm signing and side-by-side installation on a device before handing over a genuine test APK. The ordinary debug app remains `com.imdeltan.community.dev`.
4. Test real two-user JWT/REST/RPC authorization, cross-user isolation, private data and storage objects/signed URLs using synthetic fixtures, with positive controls and cleanup. The existing signed-in harness remains unrun against a real service. Evaluate retention, abuse and safety on actual service behavior.
5. Build and verify the debug APK from the reviewed source and target, then run phone/device testing. The existing debug APK does not contain these newer drafts.

## Evidence

Local tests compile the synthetic web mode using the dedicated project ref and a fake key, verify the warning, marker and selected draft modules, and reject missing confirmation, any other/mismatched project, the current dev project and non-publishable keys. Standard builds are separately checked to exclude named draft RPCs and generated draft chunks, even with the social flag set. Mocked UI tests cover synthetic navigation and opt-in behavior. Before the current project pin was added, a locally built fictional-target debug APK had the distinct synthetic ID/label and marker; `apksigner` verified v1/v2 signatures but reported META-INF v1-signature warnings that require review before any release. Local Android checks rejected mismatched assets and synthetic release combinations, and an ordinary debug APK retained the original ID and no marker. CI steps are added locally but have not run on GitHub. These tests do not establish that all draft code is absent, prove a project is isolated, test Android installation, perform real JWT/API testing, or authorize launch.
