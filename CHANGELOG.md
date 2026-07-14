# Changelog

## 0.10.1 - 2026-07-14

- Decode the optional `financeResources.cutoverReadiness` capability while preserving 0.8, 0.9 and 0.10.0 capability fixtures.
- Add an isolated read-only `/api/v2/cutover-readiness` client with exact-cent summaries, opaque cursor pagination and recognizable permission/cursor failures.
- Keep `AppSession` exclusively on `/api/state`; readiness reports cannot enable V2 writes or replace local unsynchronized state.

## 0.10.0 - 2026-07-14

- Add a compiled and tested shadow client for `/api/v2/context` and the list/create/update business-record resource slice without changing the active `AppSession` data source.
- Decode cursor pages and V2 decimal-string money through the existing exact-cent `MoneyAmount` domain model.
- Require stable `Idempotency-Key` commands for create/update, require `expectedVersion` for updates, and expose `409 VERSION_CONFLICT` as a recognizable client error.
- Decode the expanded `financeResources` capability (`cutoverState: shadow`) while keeping `legacy_state_v1` as the only negotiated sync mode.
- Preserve 0.8.x health/capability fallback and the 0.9.0 import-provider availability gate.

## 0.9.0 - 2026-07-14

- Accept the optional `financeSchemaVersion` returned by backend 0.9.0 while remaining compatible with 0.8.x health responses.
- Negotiate the real `GET /api/capabilities` contract and safely fall back to `legacy_state_v1` when an older server returns 404 or does not expose the endpoint.
- Treat `features.importAnalysis.available/reason` as runtime truth. When the provider is not configured, disable AI verification, explain the state and prevent analysis requests.
- Treat Finance Domain V2 as a server-side mirror while `financeResources` is unavailable; iOS continues to read and write through `/api/state` and does not probe future feature endpoints.
- Preserve legacy JSON amount fields while converting network/domain amounts to integer cents at the Codable boundary.
- Show the detected finance schema and active compatibility mode in Profile.
- Keep Import Harness decisions restricted to `accepted`, `review` and `rejected`; accepted analysis still does not directly create a formal V2 business record or voucher.

## 0.8.0 - 2026-07-13

- Added the first native SwiftUI client, session restoration, state sync, CSV import analysis and reserved OCR/document boundaries.
