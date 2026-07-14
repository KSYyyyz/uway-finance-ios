# UwayFinance native iOS client

SwiftUI client for the internal Uway finance workflow. This repository contains only the native iOS frontend; the Fastify/PostgreSQL backend is deployed separately on Alibaba Cloud and is accessed over HTTPS.

Current marketing version: `0.10.2`, compatible with the `20260714_004` API contract and `20260714_002_finance_resource_api` schema. The Profile screen reads `CFBundleShortVersionString` from the built app bundle, so the displayed version follows Xcode build settings rather than a hardcoded UI value.

## Implemented stage

- Native `TabView` with 工作台、账目、待处理、月结、我的.
- Native login and HttpOnly-cookie session restoration.
- Startup capability negotiation through `GET /api/capabilities`. Only the published and client-supported `legacy_state_v1` mode is used; 404, missing endpoints and old servers safely fall back to that same mode.
- Import analysis availability is negotiated at runtime. `provider_not_configured` produces a visible disabled state and the client does not send `/api/import-analysis` requests; old servers without capabilities are treated as unknown rather than assumed available.
- A separate, compiled `FinanceResourceAPI` supports V2 context and cursor-based business-record list/create/update contracts. It is intentionally not injected into `AppSession` while capabilities still prefer only `legacy_state_v1`, so existing screens cannot write through the shadow API.
- A separate `CutoverReadinessAPI` can read the server's shadow reconciliation report, exact-cent summaries, blockers and opaque difference pages. It has no write method and is not injected into `AppSession` or any business screen.
- A separate GET-only `DashboardMetricsAPI` decodes the governed Finance V2 shadow read model, including signed decimal-string money, classification coverage, trace origins/reasons and non-mutation safety flags. It is not an `AppSession` dependency or a source of raw ledger facts.
- V2 writes use commands that retain one stable `Idempotency-Key` across retries. Updates always carry `expectedVersion`; `409 VERSION_CONFLICT` remains distinguishable from generic server failures.
- Current `/api/state` read/write compatibility, debounced sync status and pull-to-refresh. The backend may mirror those writes into Finance Domain V2, but the iOS client does not call unavailable resource, metric, workflow, classification, document or OCR APIs.
- Live `/api/health` status plus service app version, optional finance schema, API contract version and active sync-mode display; 0.8.x responses without `financeSchemaVersion` remain decodable. Failed saves keep their local snapshot and expose a one-tap retry instead of overwriting it with a refresh.
- Exact-cent network/domain boundary: current JSON number amounts remain compatible, while Swift Codable converts them to integer cents before round-tripping state and import payloads.
- “记一笔” `Form`, workbench cash summary, recent activity and a Swift Charts cash forecast.
- Ledger fixed region: page brief, date filter, status filter and period totals stay fixed; only year/month/day ledger content scrolls. Month headings are not sticky.
- Pending summary stays fixed while the task list scrolls; resolving a task changes the underlying record and updates every count.
- Native CSV import flow with UTF-8/GB18030 parsing, duplicate and company-ownership gates, live AI Harness analysis, authenticated human review, provenance fields and one-batch state sync. Reviewer identity always comes from the authenticated server session.
- Explicit `DocumentAPI` boundary for attachment upload and OCR jobs.

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
5. uploads the `.xcresult` bundle and build log for 14 days.

It runs for iOS or checked-in contract-snapshot changes and can also be started manually with `workflow_dispatch`. `ContractSnapshots/backend-api-v0.10.2.json` is the standalone frontend contract baseline; when the repository is located inside the full Uway workspace, the validator additionally cross-checks the local backend resource routes, capability factory, read-only metrics/cutover implementations and Finance Domain schema constant. No Apple signing secret is required for this simulator job.

## Current backend boundary

The 0.10.2 backend also exposes governed dashboard metrics from `finance_v2_shadow_read_model`. Capabilities still publish only `legacy_state_v1` in `preferredMode` and `availableModes`; production UI and `AppSession` continue through `/api/state`. Metrics are read-only, raw records are not merged, deterministic grouping does not claim AI classification, and no report enables client writes. Delete, workflow, AI classification, attachment and OCR remain unavailable. Import analysis is operational only when `features.importAnalysis.available` is true.
