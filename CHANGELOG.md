# Changelog

## 0.14.0 - 2026-07-16

- Finalize build 12 against finance schema `20260716_009_immutable_evidence_links`; verify that native evidence flows remain account-book scoped while the database makes evidence associations and linked scope immutable.
- Target backend app `0.14.0`, API `20260715_011` and schema `20260715_008_account_book_import_analysis` in build 11 without rewriting any historical fixture.
- Scope import analysis and decisions to the authenticated account book, reuse identical canonical requests on retry, and preserve local previews/review drafts on 409 conflicts.
- Add capability-gated SMS registration with login/register switching, server-driven challenge TTL/resend countdown, password confirmation, Chinese server-error mapping and VoiceOver/keyboard semantics. Passwords and codes remain transient JSON-body values and are never logged, persisted or put in URLs; no fake-code fallback exists.
- Serialize live authentication requests and add a monotonic session generation so a slow user-A response cannot overwrite user B. Account switch, `401` and logout clear legacy state/revision/conflict drafts, account-book caches, view-local stores and temporary evidence previews.
- Decode semantic preference-memory `learningState` (`shadow`, `provisional`, `active`) while keeping v0.12/v0.13 responses compatible and preserving `modelCanAccept=false` / `writesBusinessRecords=false`. Existing preference list/revoke UI is unchanged.
- Decode active evidence/image/invoice/payment/contract counts, requirement state and missing required types. Revoked evidence never contributes to active counts.
- Add one account-book-scoped coverage cache for ledger rows, clear it across user/account-book boundaries and discard stale conclusions on request failure. This avoids N+1 requests and never turns an unknown response into “材料齐全”.
- Show `查看附件（N）` on ledger rows, directly preview verified JPEG/PNG/WebP/PDF, retain an original-view action for HEIC/HEIF, and display type, upload time, uploader and full SHA-256. Temporary preview files are removed on dismissal/exit.
- Hide upload controls only for an authoritative `not_required` result while retaining attachment history; unify `required_missing` with the ledger material/risk state. Existing idempotency, 409 draft retention, account isolation, immutable bytes and AI non-writing boundaries remain unchanged.

## 0.13.0 - 2026-07-15

- Align the native client with backend app `0.13.0`, API `20260715_009`, schema `20260715_005_immutable_record_evidence` and frozen mainline commit `7bd702c`, while retaining v0.12.0 and earlier fixtures unchanged.
- Negotiate the exact immutable-evidence capability and fail closed unless all list, coverage, multipart upload, content, revoke, media, size, lifecycle, deletion, account-book and idempotency fields match.
- Add account-book-resolved evidence coverage/listing to every record detail, native PhotosPicker/file import, verified Quick Look originals and reasoned mark-revoked flow.
- Preserve selected bytes, type, note, revoke reason and logical idempotency command across network/409 failures; clear all evidence state on record or account-book changes.
- Verify content length, SHA-256 and ETag before preview. Revocation never deletes bytes, and attachment presence never authorizes AI acceptance, `BusinessRecord` mutation or voucher posting.
- Publish a tested simulator bundle for browser interaction and a separate unsigned `iphoneos` IPA for guarded local Windows signing; neither artifact contains Apple credentials, certificates or provisioning profiles.

## 0.12.0 - 2026-07-15

- Hide visual scroll indicators across every SwiftUI scrolling container without changing pull-to-refresh, keyboard focus or accessibility scrolling.
- Deep-link workbench risk, pending and classification-review records to the matching ledger detail/edit flow by stable `recordId`; preserve filters and review drafts, and distinguish missing, forbidden and deleted states.
- Negotiate API contract `20260715_008`, finance schema `20260715_004_account_book_preference_memory` and the optional account-book preference-memory capability while retaining all historical fixtures.
- Add an account-book-scoped preference list and auditable revoke flow using opaque cursors, required reasons, stable idempotency keys and expected-version concurrency.
- Preserve revoke drafts, filters and pagination on 409; clear every observation, cursor, draft and pending command when the account book changes.
- Keep preference effects limited to closed-candidate reordering. AI cannot accept, write `BusinessRecord`, post vouchers or learn from anything other than authenticated human decisions.

## 0.11.0 - 2026-07-14

- Align the current health, capabilities and contract snapshot with the formally frozen backend app version 0.11.0 while retaining dedicated 0.10.2 compatibility fixtures and tests.
- Negotiate API contract `20260714_007`, optional classification-review/closed-set AI capabilities and legacy-state conditional-write metadata while preserving 0.10.2 and older capability decoding.
- Add exact-decimal classification-review DTOs and authenticated list/analyze/decision clients with opaque cursor pagination, stable idempotency keys and dual record/classification version checks.
- Add the native classification-review workbench for pending/accepted/rejected queues, manual confirm/correct/reject decisions and fail-closed Harness handling.
- On `409`, refresh current server versions without overwriting local reason/correction drafts; offline, timeout and `503` retries reuse the identical command and key.
- Keep `AppSession` exclusively on `/api/state`; classification suggestions and decisions never rewrite raw `BusinessRecord` facts or bypass Import Harness status boundaries.
- Send the last fetched/saved `updatedAt` as quoted `If-Match` on every `/api/state` write (`"0"` for an empty ledger). A `STATE_VERSION_CONFLICT` pauses automatic saves, preserves the local unsaved snapshot and requires an explicit user action before fetching the latest revision and retrying.

## 0.10.2 - 2026-07-14

- Decode governed dashboard-metrics and deterministic-grouping capabilities while keeping 0.10.1 and older capability responses compatible.
- Add a GET-only `/api/v2/dashboard-metrics` client with exact signed decimal money, traceable grouping and explicit safety DTOs.
- Preserve `/api/state` as the only `AppSession` data source; metrics failures cannot replace an unsaved legacy snapshot and no V2 write path is enabled.

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
