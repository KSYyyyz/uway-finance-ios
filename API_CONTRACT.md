# UwayFinance iOS API contract

The backend is deployed independently on Alibaba Cloud and is not part of this frontend repository. `ContractSnapshots/backend-api-v0.8.0.json` is the checked-in v0.8.0 compatibility baseline used by Windows and macOS CI; the full workspace validator also cross-checks it against local backend sources when they are present.

## Connected in the first native build

The app uses the existing Fastify session cookie through `URLSession` and `HTTPCookieStorage`.

| Method | Path | Swift boundary |
| --- | --- | --- |
| GET | `/api/health` | `FinanceAPI.health()` |
| POST | `/api/auth/login` | `FinanceAPI.login(...)` |
| GET | `/api/auth/me` | `FinanceAPI.currentUser()` |
| POST | `/api/auth/logout` | `FinanceAPI.logout()` |
| GET | `/api/state` | `FinanceAPI.fetchState()` |
| PUT | `/api/state` | `FinanceAPI.saveState(...)` |
| POST | `/api/audit-events` | `FinanceAPI.audit(...)` |

`PUT /api/state` remains a compatibility bridge. It is suitable for the current single-user pilot but does not provide record-level conflict protection.

## Connected mainline import-analysis boundary

| Method | Path | Swift boundary |
| --- | --- | --- |
| POST | `/api/import-analysis` | `ImportAnalysisAPI.analyze(...)` |
| POST | `/api/import-analysis/:analysisId/decision` | `ImportAnalysisAPI.decide(...)` |

The request sends only a normalized record, source coordinates/fingerprints and explicit company-ownership evidence. The server owns candidate retrieval, locked-fact creation and threshold policy. The response preserves evidence references, `accepted/review/rejected`, issue codes and Harness confidence. The iOS client never receives model-provider credentials and never writes a Harness result directly into the ledger.

The review decision body is exactly `{ decision, reason }`; reviewer identity is derived from the authenticated server session and is never trusted from the phone.

The decision response keeps the Harness status vocabulary: an accepted human decision returns `status: "accepted"`, and a rejection returns `status: "rejected"`. Human provenance is represented separately by `resolution.decision` and `resolution.reviewer`; it is not encoded into `status`.

If the server-side classifier is not configured, analysis returns `503` with `IMPORT_AI_NOT_CONFIGURED`; the client surfaces the server message and does not fall back to an on-device or direct-provider call.

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

## Next backend migration

Before multi-device release, replace whole-state writes with cursor-based record resources, idempotency keys and `expectedVersion` conflict checks. UI code depends on `FinanceAPI`, not concrete URLs, so the migration stays inside the repository/network layer.
