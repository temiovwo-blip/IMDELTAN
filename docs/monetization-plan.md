# IMDELTAN monetization plan — working draft

This is a product proposal, not an implemented billing system, financial forecast, legal approval or promise of revenue. No payment provider has been selected and no paid feature has been deployed. Public registration remains closed until the relevant safety and legal gates are met.

## Strategy

Keep core community participation free. Build trusted, useful Delta LGA communities first, and introduce transparent ways for legitimate local businesses to reach interested people. Test demand with consenting synthetic or explicitly approved business participants in an appropriate isolated development environment. Do not represent an unbuilt feature as available.

## Candidate revenue streams

1. **Business listings and sponsored placements (first candidate):** a business requests a listing; moderation verifies and approves it; clearly labelled sponsored placements appear in an appropriate community or business directory. Initially use a simple fixed placement period and transparent published price, subject to research. No guaranteed impressions or sales. Organic and paid content must be distinguishable. No user-generated ad is shown until reviewed; provide report/remove controls and record decisions.
2. **Optional business tools (later):** paid business profile enhancements, offers or basic aggregate performance reporting only when real demand is demonstrated. Define exactly what is free, paid, measurable and cancellable before charging.
3. **Optional member subscription (later):** consider nonessential convenience features only after checking demand. Basic safety, blocking, reporting, accessibility and privacy must not be paywalled. Avoid promising specific perks before they exist.
4. **Transaction-related fees (later/conditional):** only if a real marketplace or booking product is built, with clear transaction terms, refunds, dispute handling, fraud controls, taxes and legal/payment-provider review. No escrow, wallet, stored balances or financial service is assumed.

Do not sell private messages or sensitive personal data. Avoid targeting by inferred ethnicity or other sensitive traits; LGA affiliation itself may reveal sensitive context, and contextual selection must undergo privacy and legal review. Self-declaration is not age verification. Avoid ad tracking and minors' profiling until legally reviewed. Do not treat community trust as consent to advertising.

## Validation and implementation order

1. Validate community value, moderation readiness and a measurable growth/retention baseline; interview prospective businesses and users without collecting unnecessary personal data.
2. Research Nigerian and relevant regional requirements with qualified counsel/accounting support: advertising, privacy/consent, consumer protection, taxes, payments, refunds and business verification. Review provider contracts and age requirements. Do not assume which laws apply without review.
3. Specify a small opt-in business listing and advertising flow: roles, permissions, moderation, prohibited categories, complaints, expiry, labelling and accessible display. Define pricing only after research; differentiate projected assumptions from actual results.
4. Build the feature behind server-side authorization and an off-by-default development gate with synthetic-only fixtures, tests and audit events. Review abuse, impersonation, fraud, inappropriate content and trust/safety costs. A frontend flag is not security.
5. Design billing only after a provider is chosen: backend-created invoices/payment sessions, server-verified signed webhooks, idempotency, reconciliation, chargebacks, refund paths, financial reporting, least-privilege credentials and audit trails. Never trust a browser success redirect as proof of payment, store card data, or log secrets. Test provider sandbox separately from development and production credentials. Do not activate live charges before legal/security/operational review.
6. Run a limited approved pilot with clear participant consent, pricing and support, then measure actual value and costs. Public release requires separate production readiness, independent security/legal assessment, and operational support.

## Metrics and financial model

Monitor retention and engagement, number of verified businesses, paid renewals, gross revenue, payment fees, support/moderation and hosting expenses, refunds, complaints and net contribution. Distinguish business listing views from validated paid conversions and do not claim causation from unverified analytics. Forecast in low/base/high scenarios using explicit assumptions; figures must be validated and no income or investment return is guaranteed.

## Open decisions

Which business categories and LGAs to pilot; whether sponsors can self-serve or require manual review; ad rejection and refund policy; pricing and tax treatment; applicable payment provider and supported settlements; policy for high-risk ads; permitted analytics; accessibility; appeals, fraud detection and staffing. These decisions are not yet implemented or approved.

## Founder revenue planner prototype

`prototypes/business-revenue-planner.html` is a standalone, offline-only planning calculator—not app billing, a business listing feature or a forecast. Default values are deliberately labelled illustrative. It calculates gross revenue, percentage and fixed payment deductions, specified monthly costs, estimated amount left before tax, and the number of paying businesses needed to break even. It assumes one payment per business, calculates percentage fees and refunds independently on gross, and does not automatically include taxes, chargebacks, per-refund fees or annual expenses. Percentages, decimal precision and input ranges are validated; monetary calculations and break-even use exact integer-based arithmetic before display. Entries are not intentionally transmitted or saved. No real or projected revenue has been verified. The prototype and its tests are local-only, not in the installed app or GitHub as of this entry. Consult an accountant/legal adviser and research real costs before relying on scenarios.
