# UwayFinance native iOS client

SwiftUI client for the internal Uway finance workflow. This repository contains only the native iOS frontend; the Fastify/PostgreSQL backend is deployed separately on Alibaba Cloud and is accessed over HTTPS.

Current marketing version: `0.16.1` (build `16`), targeting backend app `0.16.1`, API contract `20260721_014` and finance schema `20260721_011_verified_account_email`. The native authentication flow negotiates username/phone/email login, SMS-gated pending registration followed by a purpose-isolated email confirmation link, debounced username availability and enumeration-resistant email password recovery. The validator cross-checks the live workspace contract and fails closed on version, route, capability, tenant-isolation or verification-safety drift. The Profile screen reads `CFBundleShortVersionString` from the built app bundle, so the displayed version follows Xcode build settings rather than hardcoded UI text.

## Implemented stage

- Native `TabView` with 工作台、账目、待处理、月结、我的.
- Unified native login/registration/password-recovery screen. Login sends the frozen `identifier` field for username, phone or email and falls back to the historical `username` alias only when an old capability response lacks the identity contract. All login failures render the same “账号或密码错误”.
- Registration consumes one SMS challenge and receives a short-lived pending-registration ID. No user, organization, account book or session exists until the one-time email link is confirmed. The native pending screen can safely resend by pending ID; it does not invent polling or assume that Safari's HttpOnly cookie is shared with the app. Password-reset codes remain purpose-isolated.
- Password recovery preserves the server's known/unknown-email indistinguishable response, challenge TTL/resend timer and provider-unavailable state. Confirmation clears the entire local session scope because the server revokes every old session.
- Login and recovery password fields retain accessible visibility actions. Registration uses one accessible eye button on the password row to control both password and confirmation fields. Passwords, SMS/password-reset codes, identifiers, provider credentials and email-link tokens remain transient and are never written to logs, preferences or plaintext credential storage.
- Account transitions use a monotonic session generation and serialized authentication transport. Logout, 401 and account switching clear legacy state, revisions, unsaved/conflict snapshots, account-book evidence coverage, view-local V2 stores and temporary evidence previews; a slow response for user A cannot replace user B.
- Startup capability negotiation through `GET /api/capabilities`. Only the published and client-supported `legacy_state_v1` mode is used; 404, missing endpoints and old servers safely fall back to that same mode.
- Import analysis availability is negotiated at runtime. `provider_not_configured` produces a visible disabled state and the client does not send `/api/import-analysis` requests; old servers without capabilities are treated as unknown rather than assumed available.
- A separate, compiled `FinanceResourceAPI` supports V2 context and cursor-based business-record list/create/update contracts. It is intentionally not injected into `AppSession` while capabilities still prefer only `legacy_state_v1`, so existing screens cannot write through the shadow API.
- A separate `CutoverReadinessAPI` can read the server's shadow reconciliation report, exact-cent summaries, blockers and opaque difference pages. It has no write method and is not injected into `AppSession` or any business screen.
- A separate GET-only `DashboardMetricsAPI` decodes the governed Finance V2 shadow read model, including signed decimal-string money, classification coverage, trace origins/reasons and non-mutation safety flags. It is not an `AppSession` dependency or a source of raw ledger facts.
- A separate `ClassificationReviewAPI` and native workbench expose pending/accepted/rejected queues, AI suggestions and authenticated manual confirm/correct/reject actions. Pages are limited to 10 records with an opaque cursor stack; all amounts decode from decimal strings into integer cents.
- Classification retries retain the same request body and `Idempotency-Key`. A `409` refreshes server versions while preserving local reason/correction drafts, and `503` AI unavailability leaves manual review available. Model review never auto-confirms; deterministic strong rules may be accepted and Harness rejection fails closed.
- Account-book classification preference memory is capability-gated and isolated behind `ClassificationPreferenceAPI`. The native review flow can list active/revoked/invalidated observations with opaque cursor pagination and revoke an active observation using a required reason, stable `Idempotency-Key` and `expectedVersion`. A 409 retains the reason, filter and cursor stack; switching account books clears all cached observations and drafts.
- Immutable business-record evidence is capability-gated behind `BusinessRecordEvidenceAPI`. One account-book coverage request feeds every ledger row without N+1 requests and is discarded on account-book/user change or failure. Rows with active evidence show `查看附件（N）`; JPEG/PNG/WebP/PDF opens directly in Quick Look while HEIC/HEIF remains available through `查看原件`. Detail rows show type, upload time, uploader and full SHA-256. `required_missing` drives the same missing-material state as ledger risk, exact `not_required` hides upload controls without hiding history, and a coverage failure is shown as unknown rather than complete.
- Preference-memory v2 decodes `learningState=shadow|provisional|active` while preserving the existing account-book list/revoke UI and all v0.12/v0.13 compatibility. It still requires `modelCanAccept=false` and `writesBusinessRecords=false`; no new semantic-learning write UI was added.
- V2 writes use commands that retain one stable `Idempotency-Key` across retries. Updates always carry `expectedVersion`; `409 VERSION_CONFLICT` remains distinguishable from generic server failures.
- Current `/api/state` read/write compatibility, debounced sync status and pull-to-refresh. The backend may mirror those writes into Finance Domain V2, but `AppSession` does not use V2 resources, classification review, document or OCR APIs as its synchronization source.
- Every 0.16.1 state write is conditional: the client stores the last fetched/saved `updatedAt`, sends it as quoted `If-Match`, and uses `"0"` for a first empty-ledger write. A conflict never refreshes over local edits; automatic saves pause behind a visible “其他设备已更新，需要核对” state until the user explicitly confirms “保留本机修改并重试” after a non-merge warning.
- Live `/api/health` status plus service app version, optional finance schema, API contract version and active sync-mode display; 0.8.x responses without `financeSchemaVersion` remain decodable. Failed saves keep their local snapshot and expose a one-tap retry instead of overwriting it with a refresh.
- Exact-cent network/domain boundary: current JSON number amounts remain compatible, while Swift Codable converts them to integer cents before round-tripping state and import payloads.
- “记一笔” `Form`, workbench cash summary, recent activity and a Swift Charts cash forecast.
- Ledger results and workbench recent activity share one business-date-descending order; records on the same date retain their source sequence instead of being reordered by ID.
- Ledger fixed region: page brief, date filter, status filter and period totals stay fixed; only year/month/day ledger content scrolls. Month headings are not sticky.
- Pending summary stays fixed while the task list scrolls; resolving a task changes the underlying record and updates every count.
- All native scrolling containers keep scrolling, pull-to-refresh, VoiceOver actions and input focus while hiding visual scroll indicators. Risk and classification-review rows can deep-link by `recordId` to the matching local ledger detail/edit screen without resetting the source filter or review draft; missing, forbidden and subsequently deleted records fail with explicit messages.
- Native CSV import flow with UTF-8/GB18030 parsing, duplicate and company-ownership gates, live AI Harness analysis, authenticated human review, provenance fields and one-batch state sync. Reviewer identity always comes from the authenticated server session.
- The older `DocumentAPI` remains only an OCR reservation; live record evidence uses the frozen `/api/v2/business-record-evidence*` contract and never invents document/OCR endpoints.

The iOS import flow currently accepts CSV files up to 5MB and 30 rows per batch. The 30-row boundary deliberately matches the backend import-analysis rate limit; failed, pending-review and rejected rows never enter `/api/state`. XLSX and receipt OCR are still outside the active backend boundary and are not presented as working features.

## Generate and open on macOS

Requirements: Xcode 16+, XcodeGen, iOS 17+ simulator.

```bash
cd /path/to/uway-finance-ios
brew install xcodegen
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

Then select the `UwayFinance` scheme and run. The public Alibaba Cloud API endpoint is assembled from `UWAY_API_SCHEME` and `UWAY_API_HOST` in `UwayFinance/Resources/Info.plist`; no API key or password belongs in the project. A future staging build can replace those two values before compilation without changing the networking layer.

## Validate without Xcode

From the repository root on Windows:

```powershell
node scripts/validate-contracts.mjs
```

On macOS, additionally run:

```bash
xcodegen generate --spec project.yml
xcodebuild -project UwayFinance.xcodeproj -scheme UwayFinance -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Build from Windows through GitHub Actions

The repository workflow `.github/workflows/ios-ci.yml` runs on GitHub's `macos-26` runner. It:

1. validates the iOS/API fixtures;
2. installs XcodeGen and generates `UwayFinance.xcodeproj`;
3. selects the newest available iPhone simulator instead of hardcoding a device model;
4. builds the app and runs XCTest without signing;
5. packages the real `UwayFinance.app` simulator build as `UwayFinance-simulator.zip` and records its SHA-256;
6. after XCTest passes, builds a clean unsigned `iphoneos` app and packages it as `UwayFinance-unsigned.ipa` for local signing only;
7. uploads the simulator build, unsigned device build and `.xcresult`/build logs for 14 days.

It runs for iOS or checked-in contract-snapshot changes and can also be started manually with `workflow_dispatch`. `ContractSnapshots/backend-api-v0.16.1.json` is the standalone frontend contract baseline; when the repository is located inside the full Uway workspace, the validator additionally cross-checks the local backend routes, identity/password policy, registration and recovery challenge isolation, capability factory, evidence immutability rules and Finance Domain schema constant. No Apple signing secret is required for this simulator job.

### Interact from Windows without Apple Developer membership

After a successful `iOS CI` run, open its **Artifacts** section and download `UwayFinance-simulator-<run number>`. Extract that GitHub artifact once, then upload the inner `UwayFinance-simulator.zip` to an iOS browser-simulator provider such as Appetize. Do not unzip the inner archive: it contains the unsigned iOS Simulator `.app` expected by the provider. The build uses the same public HTTPS API configuration verified by CI and is the real SwiftUI client, not the web prototype.

Use a dedicated test account, test account book and synthetic attachments on third-party cloud simulators. Browser simulators are suitable for navigation, API, state, accessibility and common photo-library flows, but physical camera, Face ID, HEIC/PDF import and device performance still require later Xcode Simulator or real-device validation.

### Optional Windows real-device sideload

This is a temporary internal-test route, not an Apple-supported distribution channel. After a successful `iOS CI` run, download `UwayFinance-device-unsigned-<run number>` from **Artifacts** and extract the GitHub wrapper once. The inner `UwayFinance-unsigned.ipa` is an unsigned real-device build; it cannot run until a local tool signs it for the connected iPhone.

For Sideloadly, download only from `https://sideloadly.io/`, follow its Windows prerequisite for Apple's non-Microsoft-Store iTunes and iCloud packages, connect and trust the unlocked iPhone by USB, then drag `UwayFinance-unsigned.ipa` into Sideloadly. Use a dedicated test-only Apple ID, complete two-factor authentication, and enable **Settings > Privacy & Security > Developer Mode** plus the developer trust prompt if iOS asks. A free Apple ID signature normally lasts seven days and must be refreshed; Sideloadly states that app-specific passwords only work in a paid-developer configuration, so do not use a personal primary Apple ID for this experiment.

Do not upload the IPA to online signing websites, do not store Apple credentials in this repository or GitHub Actions, and use only synthetic finance data until the TestFlight path is available. The CI artifact is intentionally unsigned and contains no provisioning profile, certificate or Apple credential.

## Current backend boundary

The backend still publishes only `legacy_state_v1` in `preferredMode` and `availableModes`; production state synchronization and `AppSession` continue through conditionally protected `/api/state`. `/api/live` reports process liveness, while `/api/ready` and compatibility `/api/health` require database and migration readiness. Classification review is a separate governed workflow: `modelCanAccept=false`, `writesBusinessRecords=false`, manual decisions use `confirm/correct/reject`, and raw operating facts remain unchanged. Preference memory comes only from explicit authenticated human decisions, remains account-book scoped and can only reorder closed candidates. Immutable evidence is available as a separate account-book-scoped resource, but its existence never becomes booking authority, an accepted import or a voucher. OCR remains unavailable. Import analysis is operational only when `features.importAnalysis.available` is true.

Authentication secrets exist only in transient SwiftUI state and JSON request bodies. Phone registration codes and password-reset codes remain separate. Registration email-link tokens travel in the browser fragment and are then posted in a JSON body; iOS never persists, logs or places them into a request URL. The server owns purpose isolation, HMAC digest storage, TTL, resend rotation, attempt limits and delivery failure. Historical v0.15.0 and earlier fixtures remain independent compatibility baselines.
