# UwayFinance iOS API contract

The backend is deployed independently on Alibaba Cloud and is not part of this frontend repository. `ContractSnapshots/backend-api-v0.14.0.json` is the checked-in iOS 0.14.0 baseline used by Windows and macOS CI; it targets backend app 0.14.0, API contract `20260715_010` and schema `20260715_007_multi_tenant_registration`. The root checkout contains the delegated registration contract but its mainline changes are not yet committed, so `backendBaselineCommit` remains null; full-workspace validation cross-checks the actual root files instead of claiming a frozen commit.

## Classification-review capability handshake

`GET /api/health` returns the database/migration-ready response including `status`, `version` and `financeSchemaVersion: "20260715_007_multi_tenant_registration"`. The schema field remains optional in Swift so an installed client can still connect to a 0.8.x backend that omits it. iOS then requests `GET /api/capabilities`, whose current `apiContractVersion` is `20260715_010`. The server also exposes `GET /api/live` for process liveness and `GET /api/ready` for database/migration readiness; iOS intentionally continues using compatibility `/api/health`.

The capabilities response is the machine-readable source of truth. `financeResources.available=true` with `cutoverState=shadow` means the context and business-record slice can be compiled and contract-tested, not that the active app should cut over. Because `preferredMode` and `availableModes` still contain only `legacy_state_v1`, `AppSession` continues exclusively through `/api/state`. If capabilities are missing or invalid, old 0.8/0.9 fallback remains available.

## Connected in the first native build

The app uses the existing Fastify session cookie through `URLSession` and `HTTPCookieStorage`.

| Method | Path | Swift boundary |
| --- | --- | --- |
| GET | `/api/health` | `FinanceAPI.health()` |
| GET | `/api/capabilities` | `FinanceAPI.capabilities()` |
| POST | `/api/auth/login` | `FinanceAPI.login(...)` |
| POST | `/api/auth/registration-code` | `FinanceAPI.requestRegistrationCode(...)` |
| POST | `/api/auth/register` | `FinanceAPI.register(...)` |
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
| GET | `/api/v2/classification-preferences` | `ClassificationPreferenceAPI.list(...)` — account-book scoped |
| POST | `/api/v2/classification-preferences/:observationId/revoke` | `ClassificationPreferenceAPI.revoke(...)` — reason + idempotency + expected version |
| GET | `/api/v2/business-record-evidence` | `BusinessRecordEvidenceAPI.list(...)` — record/account-book scoped |
| GET | `/api/v2/business-record-evidence-coverage` | `BusinessRecordEvidenceAPI.coverage(...)` — account-book coverage map |
| POST | `/api/v2/business-record-evidence` | `BusinessRecordEvidenceAPI.upload(...)` — multipart + idempotency |
| GET | `/api/v2/business-record-evidence/:evidenceId/content` | `BusinessRecordEvidenceAPI.content(...)` — verified immutable bytes |
| POST | `/api/v2/business-record-evidence/:evidenceId/revoke` | `BusinessRecordEvidenceAPI.revoke(...)` — reason + version + idempotency |
| POST | `/api/audit-events` | `FinanceAPI.audit(...)` |

## Multi-tenant registration and session isolation

Registration is capability-gated. iOS enables it only when `features.registration` publishes `available=true`, the exact two endpoints, `phoneVerification=sms_webhook`, `createsIsolatedOrganizationAndAccountBook=true` and `sessionCookie=http_only_secure_same_site_strict`. Missing or unavailable capabilities disable the flow with an explanation; the client never fabricates a verification code or falls back to an insecure local registration path.

The code request body is `{phone}` and its `202` response supplies the challenge TTL and resend interval. The registration body is `{username,password,phone,challengeId,code}` and its `201` response supplies the authenticated user plus the new organization/account-book IDs. Password and code remain transient and are sent only in a JSON body over HTTPS; they are absent from URLs, logs, `UserDefaults` and plaintext Keychain storage. The server owns code validity, rate limiting and SMS delivery.

The client recognizes all frozen errors without erasing the form: `INVALID_PHONE`, `INVALID_REGISTRATION_INPUT`, `WEAK_PASSWORD`, `INVALID_REGISTRATION_CODE`, `REGISTRATION_CODE_RATE_LIMITED`, `REGISTRATION_IDENTITY_CONFLICT`, `SMS_PROVIDER_UNAVAILABLE` and `SMS_DELIVERY_FAILED`. Server TTL expiry clears the local challenge/code and requires a fresh SMS request.

Each login/register/logout starts a new session generation. Responses may update UI/state only while their generation and expected user remain current, and live authentication requests are serialized so an older slow cookie response cannot land after a newer identity request. Account switch, logout or `401` clears `/api/state`, revision, unsaved/conflict snapshots, all account-book coverage/V2 view caches and temporary preview files before another identity can render. No cache key is shared across authenticated users even when an account-book ID string happens to match.

`PUT /api/state` remains the compatibility bridge and now provides whole-state optimistic concurrency. Capabilities advertise `conflictControl=optional_if_match`, `versionSource=updatedAt`, `etagHeader=ETag` and `conditionalWriteHeader=If-Match`. Older clients may temporarily omit the header, but iOS 0.14.0 never does.

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

## Account-book classification preference memory

`features.classificationPreferenceMemory` is optional so 0.11.0 and older capability responses remain decodable. v0.14 adds optional `learningState` with the closed values `shadow`, `provisional` and `active`; its absence preserves v0.12/v0.13 compatibility. The current fixture uses the safest rollout state `shadow`, pending confirmation by the still-v0.13 local mainline. No state grants model acceptance or raw-record write authority. iOS enables the native entry only when the server publishes the exact account-book scope, authenticated-human-decision source, three-observation / 0.8 consistency thresholds, active/revoked/invalidated lifecycle, closed-candidate-reordering-only effect, `Idempotency-Key`, `expectedVersion`, `modelCanAccept=false` and `writesBusinessRecords=false`.

`GET /api/v2/classification-preferences` always includes the selected `accountBookId`, lifecycle state, maximum 10-row UI page and an opaque cursor. The response must repeat the same account book on the envelope and every observation, and must declare `accountBookScoped=true`, `modelCanAccept=false` and `writesBusinessRecords=false`. Any account-book mismatch clears cached observations, cursors, revoke drafts and pending commands rather than displaying cross-book data.

`POST /api/v2/classification-preferences/:observationId/revoke` sends exactly `accountBookId`, `expectedVersion` and a required reason with a stable idempotency key. Network retries reuse the same key and body. `409 CLASSIFICATION_PREFERENCE_VERSION_CONFLICT` and `CLASSIFICATION_PREFERENCE_NOT_ACTIVE` refresh only the current preference page while retaining the reason draft, selected lifecycle filter and opaque previous-page stack; the user must inspect the new version and explicitly retry. A successful response must declare recomputation from active immutable events and preserve both non-writing safety flags.

Preference observations are not an `AppSession` data source, are never cached across account books, and cannot write raw operating facts, vouchers or arbitrary taxonomy values. Their only permitted effect is server-side reordering of an already closed candidate set based on explicit authenticated and audited human decisions.

## Immutable business-record evidence

`features.documentUpload` remains backward compatible with historical `{available:false}` values, but iOS exposes the native flow only when the server publishes the exact five endpoints, six accepted media types, `maxBytes=10000000`, `contentImmutability=database_trigger_and_sha256`, lifecycle `active/revoked`, `deletion=false`, `accountBookScoped=true` and `Idempotency-Key`.

Before reading evidence, the detail store resolves `/api/v2/context`; every list, coverage, upload and revoke request then carries the selected `accountBookId`. The ledger uses one account-book coverage request for all visible rows and never makes one request per record. Its cache is scoped by authenticated user and selected account book, clears on either change, and discards stale values when coverage fails. List requests also carry `recordExternalId` and `includeRevoked`. A record or account-book change clears cached evidence, selected bytes, form values, revoke reasons and pending idempotency commands. A response containing another record ID fails closed.

Multipart upload writes `accountBookId`, `recordExternalId`, `evidenceType` and `note` before the `file` part. The command owns one stable boundary, body and `Idempotency-Key`; transport retries reuse them only while file, type and note are unchanged. A different logical upload creates a new key. PhotosPicker and the document picker feed the same content-signature validator, and unsupported or over-10MB content remains local with a visible error.

Coverage decodes active evidence/image/invoice/payment/contract counts, `requirementState` and missing required types. Only active evidence contributes to counts. `required_missing` feeds the ledger's missing-material state; exact `not_required` hides the upload control while preserving active/revoked history. A failed coverage request remains visibly unknown and cannot render a complete conclusion. Ledger rows with active attachments show `查看附件（N）` and load the evidence view directly.

Content viewing uses the authenticated byte endpoint and verifies returned length and SHA-256 against list metadata plus ETag when present before writing a temporary Quick Look file. JPEG, PNG, WebP and PDF may auto-preview from the ledger shortcut; HEIC/HEIF and any other non-inline type use an explicit original action. Metadata displays evidence type, upload time, authenticated uploader ID and the full SHA-256. `EVIDENCE_INTEGRITY_MISMATCH` fails closed. Temporary previews are removed when Quick Look closes or the evidence view exits.

Revocation sends `accountBookId`, `expectedVersion`, a 3–1000 character reason and a stable idempotency key. Network retry preserves the same command. `409 EVIDENCE_VERSION_CONFLICT` reloads server state without clearing the reason or current `includeRevoked` filter; the user must inspect the new version and explicitly retry. Success is accepted only with `contentDeleted=false` and `contentImmutable=true`.

Evidence remains separate from `AppSession` and `/api/state`. Neither a file, its metadata nor future OCR may accept an import, mutate a raw `BusinessRecord`, post a voucher or revoke evidence through AI authority.

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

## Reserved OCR boundary

The legacy `DocumentAPI` now reserves only a future OCR workflow. It is not used for the live v0.13 evidence endpoints:

1. Create/upload a document with an idempotency key.
2. Start an OCR job by document ID.
3. Poll the OCR job and receive an optional analysis ID.

Proposed paths are centralized in `FutureAPIEndpoint`:

- `POST /api/documents`
- `POST /api/documents/:documentId/upload`
- `POST /api/documents/:documentId/ocr`
- `GET /api/ocr-jobs/:jobId`

Until Fastify freezes OCR endpoints, `ReservedDocumentAPI` returns a visible “waiting for backend” error and does not drop user data. No native UI presents these proposed routes as working.

## Contracts required for the next backend migration

Before cutover, mainline still needs zero-difference readiness in real operating data plus contracts for business-record deletion, periods, bank transactions, vouchers, reconciliation/workflow actions, OCR and reviewed AI extraction. Existing screens continue to depend on `FinanceAPI`; evidence is a separate governed resource, while shadow clients stay isolated from `AppSession`.
