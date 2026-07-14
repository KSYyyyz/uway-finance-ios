# UwayFinance iOS API contract

The backend is deployed independently on Alibaba Cloud and is not part of this frontend repository. `ContractSnapshots/backend-api-v0.11.0.json` is the checked-in iOS 0.11.0 baseline used by Windows and macOS CI; it targets backend app 0.10.2 and the frozen API contract `20260714_007`. The full workspace validator also cross-checks it against local backend sources when they are present.

## Classification-review capability handshake

`GET /api/health` returns the database/migration-ready response including `status`, `version` and `financeSchemaVersion: "20260714_003_classification_review"`. The schema field remains optional in Swift so an installed client can still connect to a 0.8.x backend that omits it. iOS then requests `GET /api/capabilities`, whose current `apiContractVersion` is `20260714_007`. The server also exposes `GET /api/live` for process liveness and `GET /api/ready` for database/migration readiness; iOS intentionally continues using compatibility `/api/health`.

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
| GET | `/api/v2/classification-reviews` | `ClassificationReviewAPI.list(...)` — max 10, opaque cursor |
| POST | `/api/v2/classification-reviews/:recordId/analyze` | `ClassificationReviewAPI.analyze(...)` — idempotent AI suggestion |
| POST | `/api/v2/classification-reviews/:recordId/decision` | `ClassificationReviewAPI.decide(...)` — authenticated human decision |
| POST | `/api/audit-events` | `FinanceAPI.audit(...)` |

`PUT /api/state` remains the compatibility bridge and now provides whole-state optimistic concurrency. Capabilities advertise `conflictControl=optional_if_match`, `versionSource=updatedAt`, `etagHeader=ETag` and `conditionalWriteHeader=If-Match`. Older clients may temporarily omit the header, but iOS 0.11.0 never does.

`GET /api/state` still returns `{ data, updatedAt }` and the same revision as a quoted `ETag`. iOS stores `updatedAt` as its current `StateRevision`; a missing value for an empty ledger maps to revision `0`. Every write sends `If-Match: "<revision>"`, including `If-Match: "0"` on the first empty-ledger write. A successful save must return a new `updatedAt`; the client never invents a revision locally.

`409 STATE_VERSION_CONFLICT` carries `details.currentUpdatedAt`. `AppSession` keeps the local state and `unsavedSnapshot`, cancels automatic retry and shows “其他设备已更新，需要核对”. Pull-to-refresh and generic retry cannot overwrite the local snapshot while this state is active. “处理冲突” opens an explicit confirmation explaining that remote content will not be merged; only “保留本机修改并重试” fetches the latest envelope to obtain its revision without assigning its data, then conditionally retries the latest local snapshot with that revision.

Legacy state and import JSON keep their existing numeric `amount` keys. Swift decodes them through `MoneyAmount` into signed 64-bit integer cents and encodes a decimal JSON number on write. The existing UI may temporarily consume a compatibility `Double`, but network/domain state has an exact-cent projection and no new financial model should introduce a raw `Double` boundary. The negotiated future V2 boundary is `decimal_string`; `MoneyAmount` already accepts decimal strings and converts them losslessly to cents.

The V2 client encodes every amount as a decimal string and decodes it into the same integer-cent model. List requests preserve the opaque cursor and optional account-book/direction/finance-status filters. Create/update commands retain a stable `Idempotency-Key` across retries; update bodies require `expectedVersion`. A `409 VERSION_CONFLICT` response is mapped to a dedicated `APIError.versionConflict(expectedVersion:currentVersion:)` so future UI can refresh instead of silently overwriting.

`financeResources.cutoverReadiness` is optional so 0.8/0.9/0.10.0 responses remain decodable. In 0.10.1 it advertises cursor pagination, zero-difference and zero-shadow-only requirements, and `clientWritesEnabled=false`. The corresponding client is GET-only. It decodes snapshot digests, exact-cent summaries, blockers and paginated difference metadata; `403 CUTOVER_READINESS_FORBIDDEN` and `400 INVALID_CUTOVER_CURSOR` remain recognizable server errors. It does not update `AppSession`, replace `/api/state`, or overwrite locally unsynchronized changes.

`features.unifiedDashboardMetrics` remains decodable when older servers send only `{ available: false }`. It advertises `/api/v2/dashboard-metrics`, decimal-string money and `finance_v2_shadow_read_model`; `rawRecordsMerged=false`. The GET-only client decodes overview, trend, groups, trace provenance, classification coverage and safety flags. Metrics errors never refresh or replace `AppSession` state.

## Classification review boundary

`features.classificationReview` is optional for compatibility with 0.10.2 and older responses. When available it publishes the three endpoints, cursor pagination, a default page size of 10, `Idempotency-Key`, the concurrency fields `expectedRecordVersion` and `expectedClassificationVersion`, and decisions `confirm/correct/reject`. The current server body field is `normalizedItemName`; the client intentionally does not send the older prompt vocabulary `accept` or `normalizedGroupName`.

List and analysis amounts are decimal strings decoded through `V2DecimalAmount` into exact integer cents. The client stores the server cursor as an opaque string and keeps a local previous-page cursor stack. Analysis results preserve `accepted/review/rejected`: a deterministic strong rule may produce accepted, model review always needs an explicit human decision, and rejected remains fail closed. `modelCanAccept=false`, `writesBusinessRecords=false`, `rawBusinessRecordChanged=false` and the Import Harness boundary are enforced independently of display state.

Analyze and decision commands retain one stable request body and idempotency key across network, timeout and 503 retries. Decisions carry both expected versions. On `VERSION_CONFLICT`, `CLASSIFICATION_VERSION_CONFLICT` or source change, the store reloads current server versions but keeps the user's local reason, taxonomy and normalized-name draft. A 503 disables only the AI suggestion path; manual review remains available. A 403 becomes a read-only unavailable state.

This workflow is not an `AppSession` data source. `AppSession` still reads and writes only `/api/state`; neither suggestions nor decisions replace locally unsynchronized state or mutate the raw `BusinessRecord` facts.

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
