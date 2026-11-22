# ChatKEY

ChatKEY is an independent product within the WOW MARKET product portfolio.

## Product direction
A unified API gateway that gives each customer a ChatKEY credential and routes requests to officially connected AI providers. Provider credentials remain server-side and are never exposed to customers.

## Current repository status
- Initial responsive Arabic product and dashboard interface added at `/chatkey/index.html`.
- The current page is a UI foundation only.
- No production API endpoint, customer authentication, real key issuance, provider routing, usage metering, billing, or payment processing is connected yet.
- The displayed plans and provider cards are proposals, not active services or live prices.

## Required production architecture
1. Backend API gateway (never store provider secrets in browser code).
2. Customer authentication and role-based access.
3. Hashed customer API keys, scoped permissions, rotation and revocation.
4. Provider adapters for approved official APIs.
5. Rate limiting, quotas, usage ledger and cost controls.
6. Billing provider, invoices, refunds and tax handling.
7. Admin console, audit logs, abuse monitoring and incident controls.

## Security baseline
- Never commit provider API secrets or customer keys to this repository.
- Store secrets in server-side environment variables or a managed secrets vault.
- Enforce per-customer quotas, request limits and spend caps.
- Do not claim a provider is live until its integration is tested end-to-end.
