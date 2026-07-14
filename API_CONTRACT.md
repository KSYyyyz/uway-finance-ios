# UwayFinance iOS API contract

The backend is deployed independently on Alibaba Cloud and is not part of this frontend repository. `ContractSnapshots/backend-api-v0.9.0.json` is the checked-in 0.9.0 compatibility baseline used by Windows and macOS CI; the full workspace validator also cross-checks it against local backend sources when they are present.

## Backend 0.9.0 capability handshake

`GET /api/health` returns `status`, `version` and, on backend 0.9.0, `financeSchemaVersion: "20260714_001_finance_domain_v2"`. The schema field is optional in Swift so an installed client can still connect to a 0.8.x backend that omits it. iOS then requests `GET /api/capabilities`, whose current `apiContractVersion` is `20260714_001`.

The capabilities response is the machine-readable source of truth. iOS accepts a sync mode only when it is both implemented by the client and listed in `availableModes`; the current mode is `legacy_state_v1`. If the endpoint is missing, returns 404, cannot decode, or belongs to an older server, iOS safely retains `legacy_state_v1` and continues session restoration. Unknown capability state does not imply that import analysis is available. The server owns any Finance Domain V2 mirror, and `financeResources` remains unavailable. No organization, account-book, period, business-record, voucher, reconciliation, workflow or AI-evidence resource endpoint is called until mainline publishes and implements that contract.

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
| POST | `/api/audit-events` | `FinanceAPI.audit(...)` |

`PUT /api/state` remains a compatibility bridge. It is suitable for the current single-user pilot but does not provide record-level conflict protection.

Legacy state and import JSON keep their existing numeric `amount` keys. Swift decodes them through `MoneyAmount` into signed 64-bit integer cents and encodes a decimal JSON number on write. The existing UI may temporarily consume a compatibility `Double`, but network/domain state has an exact-cent projection and no new financial model should introduce a raw `Double` boundary. The negotiated future V2 boundary is `decimal_string`; `MoneyAmount` already accepts decimal strings and converts them losslessly to cents.

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

Before multi-device release, mainline must publish implemented resource paths and DTOs for organization/account-book context, periods, business records, bank transactions, vouchers, reconciliation/workflow actions, documents and AI evidence/feedback. The contract also needs pagination/cursors, decimal amount representation, stable IDs, idempotency keys, `expectedVersion` conflict checks, deletion semantics and authorization/role errors. UI code depends on `FinanceAPI`, not concrete URLs, so the eventual migration stays inside the repository/network layer.
