# UwayFinance iOS API contract

The backend is deployed independently on Alibaba Cloud and is not part of this frontend repository. `ContractSnapshots/backend-api-v0.10.2.json` is the checked-in 0.10.2 baseline used by Windows and macOS CI; the full workspace validator also cross-checks it against local backend sources when they are present.

## Backend 0.10.2 capability handshake

`GET /api/health` returns `status`, `version` and `financeSchemaVersion: "20260714_002_finance_resource_api"`. The schema field remains optional in Swift so an installed client can still connect to a 0.8.x backend that omits it. iOS then requests `GET /api/capabilities`, whose `apiContractVersion` is `20260714_004`.

The capabilities response is the machine-readable source of truth. `financeResources.available=true` with `cutoverState=shadow` means the context and business-record slice can be compiled and contract-tested, not that the active app should cut over. Because `preferredMode` and `availableModes` still contain only `legacy_state_v1`, `AppSession` continues exclusively through `/api/state`. If capabilities are missing or invalid, old 0.8/0.9 fallback remains available.

## Connected in the first native build

The app uses the existing Fastify session cookie through `URLSession` and `HTTPCookieStorage`.

| Method | Path | Swift boundary |
| --- | --- | --- |
| GET | `/api/health` | `FinanceAPI.health()` |
| GET | `/api/capabilities` | `FinanceAPI.capabilities()` |
| POST | `/api/auth/login` | `FinanceAPI.login(...)` |
| GET | `/api/auth/me` | `FinanceAPI.currentUser()` |
| POST | `/api/auth/logout` | `FinanceAPI.logout()` |
| GET | `/api/state` | `FinanceAPI.fetchState()` |
| PUT | `/api/state` | `FinanceAPI.saveState(...)` |
| GET | `/api/v2/context` | `FinanceResourceAPI.context(...)` — shadow only |
| GET | `/api/v2/business-records` | `FinanceResourceAPI.listBusinessRecords(...)` — shadow only |
| POST | `/api/v2/business-records` | `FinanceResourceAPI.createBusinessRecord(...)` — shadow only |
| PATCH | `/api/v2/business-records/:recordId` | `FinanceResourceAPI.updateBusinessRecord(...)` — shadow only |
| GET | `/api/v2/cutover-readiness` | `CutoverReadinessAPI.readiness(...)` — read-only diagnostics |
| GET | `/api/v2/dashboard-metrics` | `DashboardMetricsAPI.metrics(...)` — governed shadow read model |
| POST | `/api/audit-events` | `FinanceAPI.audit(...)` |

`PUT /api/state` remains a compatibility bridge. It is suitable for the current single-user pilot but does not provide record-level conflict protection.

Legacy state and import JSON keep their existing numeric `amount` keys. Swift decodes them through `MoneyAmount` into signed 64-bit integer cents and encodes a decimal JSON number on write. The existing UI may temporarily consume a compatibility `Double`, but network/domain state has an exact-cent projection and no new financial model should introduce a raw `Double` boundary. The negotiated future V2 boundary is `decimal_string`; `MoneyAmount` already accepts decimal strings and converts them losslessly to cents.

The V2 client encodes every amount as a decimal string and decodes it into the same integer-cent model. List requests preserve the opaque cursor and optional account-book/direction/finance-status filters. Create/update commands retain a stable `Idempotency-Key` across retries; update bodies require `expectedVersion`. A `409 VERSION_CONFLICT` response is mapped to a dedicated `APIError.versionConflict(expectedVersion:currentVersion:)` so future UI can refresh instead of silently overwriting.

`financeResources.cutoverReadiness` is optional so 0.8/0.9/0.10.0 responses remain decodable. In 0.10.1 it advertises cursor pagination, zero-difference and zero-shadow-only requirements, and `clientWritesEnabled=false`. The corresponding client is GET-only. It decodes snapshot digests, exact-cent summaries, blockers and paginated difference metadata; `403 CUTOVER_READINESS_FORBIDDEN` and `400 INVALID_CUTOVER_CURSOR` remain recognizable server errors. It does not update `AppSession`, replace `/api/state`, or overwrite locally unsynchronized changes.

`features.unifiedDashboardMetrics` remains decodable when older servers send only `{ available: false }`. In 0.10.2 it advertises `/api/v2/dashboard-metrics`, decimal-string money and `finance_v2_shadow_read_model`; `rawRecordsMerged=false`. The GET-only client decodes overview, five-period trend, category/same-type groups, trace provenance, classification coverage and safety flags. Negative `netCashFlow` uses the same signed integer-cent model. `features.aiClassification.available` remains false; `deterministicGroupingAvailable=true` does not grant a model permission to classify or write records. Metrics errors never refresh or replace `AppSession` state.

## Connected mainline import-analysis boundary

| Method | Path | Swift boundary |
| --- | --- | --- |
| POST | `/api/import-analysis` | `ImportAnalysisAPI.analyze(...)` |
| POST | `/api/import-analysis/:analysisId/decision` | `ImportAnalysisAPI.decide(...)` |

The request sends only a normalized record, source coordinates/fingerprints and explicit company-ownership evidence. The server owns candidate retrieval, locked-fact creation and threshold policy. The response preserves evidence references, `accepted/review/rejected`, issue codes and Harness confidence. The iOS client never receives model-provider credentials and never writes a Harness result directly into the ledger.

The review decision body is exactly `{ decision, reason }`; reviewer identity is derived from the authenticated server session and is never trusted from the phone.

The decision response keeps the Harness status vocabulary: an accepted human decision returns `status: "accepted"`, and a rejection returns `status: "rejected"`. Human provenance is represented separately by `resolution.decision` and `resolution.reviewer`; it is not encoded into `status`.

`features.importAnalysis` includes `{ available, reason, contract, decisions }`. With a configured provider it reports `available=true, reason=null`; otherwise it reports `available=false, reason="provider_not_configured"`. The native screen disables verification and checks the same capability again immediately before sending, so it does not call `/api/import-analysis` when unavailable. A server-side `503 IMPORT_AI_NOT_CONFIGURED` remains a defensive race-condition fallback; the client never falls back to an on-device or direct-provider call.

### Native import safety boundary

- The file picker accepts CSV only; parsing supports UTF-8 and GB18030, a 5MB file limit and a 30-row batch limit aligned with the server rate limit.
- Rows explicitly marked as personal are excluded. Rows without company evidence stay outside analysis until the user explicitly confirms company ownership or excludes them.
- Each analyzed row receives SHA-256 source and ownership fingerprints. Existing ledger fingerprints are sent only for server-side duplicate/evidence checks.
- `accepted` rows are the only rows appended to `/api/state`. `review` requires an authenticated decision and reason; `rejected` and failed rows remain outside the ledger.
- Imported records persist `importAnalysisId`, `sourceFingerprint` and either `harness_accepted` or `human_accepted`. The client sends one `record_csv_import` audit event for the committed batch.

## Reserved document and OCR boundary

`DocumentAPI` reserves a three-step workflow:

1. Create/upload a document with an idempotency key.
2. Start an OCR job by document ID.
3. Poll the OCR job and receive an optional analysis ID.

Proposed paths are centralized in `FutureAPIEndpoint`:

- `POST /api/documents`
- `POST /api/documents/:documentId/upload`
- `POST /api/documents/:documentId/ocr`
- `GET /api/ocr-jobs/:jobId`

Until Fastify implements them, `ReservedDocumentAPI` returns a visible “waiting for backend” error and does not drop user data.

## Contracts required for the next backend migration

Before cutover, mainline still needs zero-difference readiness in real operating data plus contracts for business-record deletion, periods, bank transactions, vouchers, reconciliation/workflow actions, documents and AI evidence/feedback. The current slice defines cursor pagination, decimal-string money, stable IDs, idempotency keys and `expectedVersion`; future UI must add conflict refresh/retry and role-error states before a V2 mode can enter `availableModes`. Existing screens continue to depend on `FinanceAPI`, while the shadow clients stay isolated behind `FinanceResourceAPI` and `CutoverReadinessAPI`.
