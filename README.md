# UwayFinance native iOS client

SwiftUI client for the internal Uway finance workflow. This repository contains only the native iOS frontend; the Fastify/PostgreSQL backend is deployed separately on Alibaba Cloud and is accessed over HTTPS.

Current marketing version: `0.8.0`. The Profile screen reads `CFBundleShortVersionString` from the built app bundle, so the displayed version follows Xcode build settings rather than a hardcoded UI value.

## Implemented stage

- Native `TabView` with 工作台、账目、待处理、月结、我的.
- Native login and HttpOnly-cookie session restoration.
- Current `/api/state` read/write compatibility, debounced sync status and pull-to-refresh.
- “记一笔” `Form`, workbench cash summary, recent activity and a Swift Charts cash forecast.
- Ledger fixed region: page brief, date filter, status filter and period totals stay fixed; only year/month/day ledger content scrolls. Month headings are not sticky.
- Pending summary stays fixed while the task list scrolls; resolving a task changes the underlying record and updates every count.
- Mainline import-analysis request/result/decision models and live client for both active endpoints; reviewer identity comes from the authenticated session.
- Explicit `DocumentAPI` boundary for attachment upload and OCR jobs.

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

It runs for iOS or checked-in contract-snapshot changes and can also be started manually with `workflow_dispatch`. `ContractSnapshots/backend-api-v0.8.0.json` is the standalone frontend contract baseline; when the repository is located inside the full Uway workspace, the validator additionally cross-checks the local backend source. No Apple signing secret is required for this simulator job.

## Current backend boundary

The main backend implements both import-analysis endpoints. Analysis requires the server-side classifier configuration and can return `503 IMPORT_AI_NOT_CONFIGURED` when that service is unavailable. Attachment/OCR endpoints are not exposed yet; the native client keeps them behind `DocumentAPI` so backend activation does not require a screen rewrite.
