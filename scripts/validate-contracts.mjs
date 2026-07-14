import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const workspace = path.resolve(root, '..', '..')
const expectedMarketingVersion = '0.10.2'
const expectedAPIContractVersion = '20260714_004'
const expectedFinanceSchemaVersion = '20260714_002_finance_resource_api'
const workflowPath = path.join(root, '.github', 'workflows', 'ios-ci.yml')
const contractSnapshotPath = path.join(root, 'ContractSnapshots', 'backend-api-v0.10.2.json')

const requiredFiles = [
  'project.yml',
  'ContractSnapshots/backend-api-v0.10.2.json',
  'UwayFinance/App/UwayFinanceApp.swift',
  'UwayFinance/Networking/APIEndpoint.swift',
  'UwayFinance/Networking/FinanceAPI.swift',
  'UwayFinance/Networking/ImportAnalysisAPI.swift',
  'UwayFinance/Networking/DocumentAPI.swift',
  'UwayFinance/Networking/FinanceResourceAPI.swift',
  'UwayFinance/Networking/CutoverReadinessAPI.swift',
  'UwayFinance/Networking/DashboardMetricsAPI.swift',
  'UwayFinance/Models/BackendContract.swift',
  'UwayFinance/Models/FinanceResourceModels.swift',
  'UwayFinance/Models/CutoverReadinessModels.swift',
  'UwayFinance/Models/DashboardMetricsModels.swift',
  'UwayFinance/Models/MoneyAmount.swift',
  'UwayFinance/Models/RecordImportPipeline.swift',
  'UwayFinance/State/RecordImportSession.swift',
  'UwayFinance/Views/RecordImportView.swift',
  'UwayFinance/Views/LedgerView.swift',
  'UwayFinance/Resources/Info.plist',
  'UwayFinance/Resources/Assets.xcassets/Contents.json',
  'UwayFinance/Resources/Assets.xcassets/AccentColor.colorset/Contents.json',
  'UwayFinance/Resources/Assets.xcassets/BrandGreen.colorset/Contents.json',
  'UwayFinanceTests/Fixtures/state-envelope.json',
  'UwayFinanceTests/AppConfigurationTests.swift',
  'UwayFinanceTests/AppSessionTests.swift',
  'UwayFinanceTests/BackendContractTests.swift',
  'UwayFinanceTests/MoneyAmountTests.swift',
  'UwayFinanceTests/FinanceResourceAPITests.swift',
  'UwayFinanceTests/CutoverReadinessAPITests.swift',
  'UwayFinanceTests/DashboardMetricsAPITests.swift',
  'UwayFinanceTests/RecordImportPipelineTests.swift',
  'UwayFinanceTests/Fixtures/harness-result.json',
  'UwayFinanceTests/Fixtures/import-analysis-request.json',
  'UwayFinanceTests/Fixtures/import-decision-response.json',
  'UwayFinanceTests/Fixtures/health-v0.8.1.json',
  'UwayFinanceTests/Fixtures/health-v0.9.0.json',
  'UwayFinanceTests/Fixtures/capabilities-v0.9.0.json',
  'UwayFinanceTests/Fixtures/capabilities-v0.9.0-import-disabled.json',
  'UwayFinanceTests/Fixtures/health-v0.10.0.json',
  'UwayFinanceTests/Fixtures/capabilities-v0.10.0.json',
  'UwayFinanceTests/Fixtures/health-v0.10.1.json',
  'UwayFinanceTests/Fixtures/capabilities-v0.10.1.json',
  'UwayFinanceTests/Fixtures/cutover-readiness-zero-v0.10.1.json',
  'UwayFinanceTests/Fixtures/cutover-readiness-differences-v0.10.1.json',
  'UwayFinanceTests/Fixtures/cutover-readiness-forbidden-v0.10.1.json',
  'UwayFinanceTests/Fixtures/cutover-readiness-invalid-cursor-v0.10.1.json',
  'UwayFinanceTests/Fixtures/health-v0.10.2.json',
  'UwayFinanceTests/Fixtures/capabilities-v0.10.2.json',
  'UwayFinanceTests/Fixtures/dashboard-metrics-v0.10.2.json',
  'UwayFinanceTests/Fixtures/dashboard-metrics-negative-v0.10.2.json',
  'UwayFinanceTests/Fixtures/dashboard-metrics-forbidden-v0.10.2.json',
  'UwayFinanceTests/Fixtures/dashboard-metrics-invalid-period-v0.10.2.json',
  'UwayFinanceTests/Fixtures/finance-context-v0.10.0.json',
  'UwayFinanceTests/Fixtures/business-records-page-v0.10.0.json',
  'UwayFinanceTests/Fixtures/business-record-response-v0.10.0.json',
  'UwayFinanceTests/Fixtures/version-conflict-v0.10.0.json',
  'CHANGELOG.md',
]

for (const file of requiredFiles) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`missing ${file}`)
}
if (!fs.existsSync(workflowPath)) throw new Error('missing .github/workflows/ios-ci.yml')

const fixtures = [
  'state-envelope.json',
  'harness-result.json',
  'import-analysis-request.json',
  'import-decision-response.json',
  'health-v0.8.1.json',
  'health-v0.9.0.json',
  'capabilities-v0.9.0.json',
  'capabilities-v0.9.0-import-disabled.json',
  'health-v0.10.0.json',
  'capabilities-v0.10.0.json',
  'health-v0.10.1.json',
  'capabilities-v0.10.1.json',
  'cutover-readiness-zero-v0.10.1.json',
  'cutover-readiness-differences-v0.10.1.json',
  'cutover-readiness-forbidden-v0.10.1.json',
  'cutover-readiness-invalid-cursor-v0.10.1.json',
  'health-v0.10.2.json',
  'capabilities-v0.10.2.json',
  'dashboard-metrics-v0.10.2.json',
  'dashboard-metrics-negative-v0.10.2.json',
  'dashboard-metrics-forbidden-v0.10.2.json',
  'dashboard-metrics-invalid-period-v0.10.2.json',
  'finance-context-v0.10.0.json',
  'business-records-page-v0.10.0.json',
  'business-record-response-v0.10.0.json',
  'version-conflict-v0.10.0.json',
]
for (const fixture of fixtures) {
  JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', fixture), 'utf8'))
}

const decisionResponse = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-decision-response.json'), 'utf8'))
if (decisionResponse.status !== 'accepted') throw new Error('accepted human decision must keep Harness status accepted')
if (decisionResponse.resolution?.decision !== 'accept' || !decisionResponse.resolution?.reviewer) {
  throw new Error('human decision provenance must remain in resolution.decision/reviewer')
}

const contractSnapshot = JSON.parse(fs.readFileSync(contractSnapshotPath, 'utf8'))
if (contractSnapshot.version !== expectedMarketingVersion) throw new Error('backend contract snapshot version mismatch')
if (contractSnapshot.apiContractVersion !== expectedAPIContractVersion) {
  throw new Error('backend contract snapshot API contract version mismatch')
}
if (contractSnapshot.financeSchemaVersion !== expectedFinanceSchemaVersion) {
  throw new Error('backend contract snapshot finance schema mismatch')
}
if (contractSnapshot.syncMode !== 'legacy_state_v1') {
  throw new Error('iOS must remain on the legacy-state compatibility path')
}
const resourceSnapshot = contractSnapshot.capabilities?.financeResources
if (contractSnapshot.capabilities?.financeDomainV2Mirror !== true
    || resourceSnapshot?.available !== true
    || resourceSnapshot?.cutoverState !== 'shadow'
    || resourceSnapshot?.cutoverReadiness?.available !== true
    || resourceSnapshot?.cutoverReadiness?.endpoint !== '/api/v2/cutover-readiness'
    || resourceSnapshot?.cutoverReadiness?.pagination !== 'cursor'
    || resourceSnapshot?.cutoverReadiness?.requiresZeroDifferences !== true
    || resourceSnapshot?.cutoverReadiness?.requiresZeroShadowOnlyRecords !== true
    || resourceSnapshot?.cutoverReadiness?.clientWritesEnabled !== false
    || resourceSnapshot?.businessRecords?.delete !== false
    || resourceSnapshot?.businessRecords?.pagination !== 'cursor'
    || resourceSnapshot?.businessRecords?.idempotencyHeader !== 'Idempotency-Key'
    || resourceSnapshot?.businessRecords?.concurrencyControl !== 'expectedVersion') {
  throw new Error('V2 shadow resource capabilities do not match the 0.10.2 backend boundary')
}
const metricsSnapshot = contractSnapshot.capabilities?.unifiedDashboardMetrics
if (metricsSnapshot?.available !== true
    || metricsSnapshot?.endpoint !== '/api/v2/dashboard-metrics'
    || metricsSnapshot?.moneyEncoding !== 'decimal_string'
    || metricsSnapshot?.source !== 'finance_v2_shadow_read_model'
    || metricsSnapshot?.rawRecordsMerged !== false
    || metricsSnapshot?.classificationStates?.join(',') !== 'accepted,review,unclassified'
    || contractSnapshot.capabilities?.aiClassification?.available !== false
    || contractSnapshot.capabilities?.aiClassification?.deterministicGroupingAvailable !== true) {
  throw new Error('dashboard metrics snapshot must remain governed, read-only and deterministic')
}
if (contractSnapshot.capabilities?.importAnalysis?.availability !== 'runtime'
    || contractSnapshot.capabilities?.importAnalysis?.reasonWhenUnavailable !== 'provider_not_configured') {
  throw new Error('import-analysis capability must remain runtime-negotiated')
}
if (!['accepted', 'review', 'rejected'].every((status) => contractSnapshot.decisionStatuses.includes(status))) {
  throw new Error('backend contract snapshot must preserve Harness three-state status')
}
if (contractSnapshot.money?.legacyStateEncoding !== 'json_number'
    || contractSnapshot.money?.financeV2Encoding !== 'decimal_string'
    || contractSnapshot.money?.databasePrecision !== 18
    || contractSnapshot.money?.databaseScale !== 2) {
  throw new Error('backend contract snapshot money boundary mismatch')
}

const capabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.10.2.json'), 'utf8'))
const healthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-v0.10.2.json'), 'utf8'))
if (healthFixture.version !== expectedMarketingVersion
    || healthFixture.financeSchemaVersion !== expectedFinanceSchemaVersion) {
  throw new Error('0.10.2 health fixture version/schema mismatch')
}
if (capabilitiesFixture.apiContractVersion !== expectedAPIContractVersion
    || capabilitiesFixture.sync?.preferredMode !== 'legacy_state_v1'
    || capabilitiesFixture.sync?.availableModes?.join(',') !== 'legacy_state_v1') {
  throw new Error('capabilities fixture must publish only legacy_state_v1')
}
if (capabilitiesFixture.features?.importAnalysis?.available !== true
    || capabilitiesFixture.features?.importAnalysis?.reason !== null) {
  throw new Error('configured import-analysis fixture must report available=true/reason=null')
}
const disabledCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.9.0-import-disabled.json'), 'utf8'))
if (disabledCapabilitiesFixture.features?.importAnalysis?.available !== false
    || disabledCapabilitiesFixture.features?.importAnalysis?.reason !== 'provider_not_configured') {
  throw new Error('unconfigured import-analysis fixture must expose provider_not_configured')
}
if (capabilitiesFixture.sync?.financeResources?.available !== true
    || capabilitiesFixture.sync?.financeResources?.cutoverState !== 'shadow'
    || capabilitiesFixture.sync?.financeResources?.cutoverReadiness?.clientWritesEnabled !== false
    || capabilitiesFixture.sync?.financeResources?.businessRecords?.moneyEncoding !== 'decimal_string') {
  throw new Error('0.10.2 capabilities fixture must preserve read-only readiness and the shadow resource slice')
}
const oldCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.10.0.json'), 'utf8'))
if ('cutoverReadiness' in (oldCapabilitiesFixture.sync?.financeResources ?? {})) {
  throw new Error('0.10.0 fallback fixture must prove cutoverReadiness is optional')
}
const zeroReadinessFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'cutover-readiness-zero-v0.10.1.json'), 'utf8'))
if (zeroReadinessFixture.differences?.total !== 0
    || zeroReadinessFixture.readiness?.businessRecordReadCutoverEligible !== true
    || zeroReadinessFixture.readiness?.businessRecordWriteCutoverEligible !== false
    || zeroReadinessFixture.readiness?.fullFinanceCutoverEligible !== false) {
  throw new Error('zero-difference readiness fixture must never enable writes')
}
const differenceReadinessFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'cutover-readiness-differences-v0.10.1.json'), 'utf8'))
if (differenceReadinessFixture.differences?.total !== 2
    || !differenceReadinessFixture.differences?.page?.nextCursor
    || !differenceReadinessFixture.readiness?.blockers?.some((item) => item.code === 'LEGACY_V2_DIFFERENCES')
    || !differenceReadinessFixture.readiness?.blockers?.some((item) => item.code === 'V2_SHADOW_ONLY_RECORDS')) {
  throw new Error('difference readiness fixture must preserve blockers and opaque pagination')
}
const forbiddenReadinessFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'cutover-readiness-forbidden-v0.10.1.json'), 'utf8'))
const invalidCursorFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'cutover-readiness-invalid-cursor-v0.10.1.json'), 'utf8'))
if (forbiddenReadinessFixture.code !== 'CUTOVER_READINESS_FORBIDDEN'
    || invalidCursorFixture.code !== 'INVALID_CUTOVER_CURSOR') {
  throw new Error('cutover readiness error fixtures must keep recognizable server codes')
}
const oldMetricsCapability = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.10.1.json'), 'utf8')).features?.unifiedDashboardMetrics
if (oldMetricsCapability?.available !== false || 'endpoint' in oldMetricsCapability) {
  throw new Error('0.10.1 fixture must prove dashboard capability details are optional')
}
const metricsFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'dashboard-metrics-v0.10.2.json'), 'utf8'))
const negativeMetricsFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'dashboard-metrics-negative-v0.10.2.json'), 'utf8'))
if (metricsFixture.metricDefinition?.moneyEncoding !== 'decimal_string'
    || metricsFixture.safety?.rawBusinessRecordsMerged !== false
    || metricsFixture.safety?.modelWritesBusinessRecords !== false
    || metricsFixture.safety?.reviewSuggestionsAffectRawFacts !== false
    || negativeMetricsFixture.overview?.netCashFlow !== '-1830.00') {
  throw new Error('dashboard metrics fixtures must preserve exact money and non-mutation safety')
}
const forbiddenMetricsFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'dashboard-metrics-forbidden-v0.10.2.json'), 'utf8'))
const invalidPeriodMetricsFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'dashboard-metrics-invalid-period-v0.10.2.json'), 'utf8'))
if (forbiddenMetricsFixture.code !== 'DASHBOARD_METRICS_FORBIDDEN'
    || invalidPeriodMetricsFixture.code !== 'INVALID_DASHBOARD_METRICS_QUERY') {
  throw new Error('dashboard metrics error fixtures must keep recognizable server codes')
}
if (capabilitiesFixture.features?.unifiedDashboardMetrics?.available !== true
    || capabilitiesFixture.features?.unifiedDashboardMetrics?.rawRecordsMerged !== false
    || capabilitiesFixture.features?.aiClassification?.available !== false
    || capabilitiesFixture.features?.aiClassification?.deterministicGroupingAvailable !== true) {
  throw new Error('dashboard metrics capability must not claim AI classification or raw-record merging')
}
for (const feature of ['workflowTasks', 'documentUpload', 'ocr']) {
  const value = capabilitiesFixture.features?.[feature]
  if (value?.available !== false) throw new Error(`future capability must remain unavailable: ${feature}`)
}
if (capabilitiesFixture.safety?.aiMayWriteBusinessRecords !== false
    || capabilitiesFixture.safety?.aiMayPostJournalVouchers !== false) {
  throw new Error('capabilities fixture must preserve AI write safety')
}

for (const asset of [
  'Contents.json',
  'AccentColor.colorset/Contents.json',
  'BrandGreen.colorset/Contents.json',
]) {
  JSON.parse(fs.readFileSync(path.join(root, 'UwayFinance', 'Resources', 'Assets.xcassets', asset), 'utf8'))
}

const plist = fs.readFileSync(path.join(root, 'UwayFinance', 'Resources', 'Info.plist'), 'utf8')
for (const marker of [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<plist version="1.0">',
  '</plist>',
  '<key>UWAY_API_SCHEME</key>',
  '<key>UWAY_API_HOST</key>',
  '<key>NSCameraUsageDescription</key>',
]) {
  if (!plist.includes(marker)) throw new Error(`Info.plist marker missing: ${marker}`)
}
if ((plist.match(/<string>/g) ?? []).length !== (plist.match(/<\/string>/g) ?? []).length) {
  throw new Error('Info.plist contains an unclosed string value')
}
if (!plist.includes('<key>CFBundleShortVersionString</key>') || !plist.includes('<string>$(MARKETING_VERSION)</string>')) {
  throw new Error('Info.plist must derive CFBundleShortVersionString from MARKETING_VERSION')
}

const project = fs.readFileSync(path.join(root, 'project.yml'), 'utf8')
if (!project.includes(`MARKETING_VERSION: ${expectedMarketingVersion}`)) {
  throw new Error(`project MARKETING_VERSION must be ${expectedMarketingVersion}`)
}
if (!project.includes('INFOPLIST_FILE: UwayFinance/Resources/Info.plist')) {
  throw new Error('project must reference the complete checked-in Info.plist without regenerating it')
}
if (!project.includes('ASSETCATALOG_COMPILER_APPICON_NAME: ""')) {
  throw new Error('project must not require an AppIcon set until production icon assets are added')
}
if (/\n\s+info:\s*\n\s+path: UwayFinance\/Resources\/Info\.plist/.test(project)) {
  throw new Error('XcodeGen info generation would overwrite custom runtime configuration')
}
for (const marker of [
  'path: UwayFinance/Resources/Assets.xcassets\n        buildPhase: resources',
  'path: UwayFinanceTests/Fixtures\n        buildPhase: resources',
]) {
  if (!project.includes(marker)) throw new Error(`project resource build phase missing: ${marker}`)
}
for (const configFile of ['Debug.xcconfig', 'Release.xcconfig']) {
  const config = fs.readFileSync(path.join(root, 'Config', configFile), 'utf8')
  if (!config.trim()) throw new Error(`${configFile} must not be empty`)
}

for (const marker of ['<string>https</string>', '<string>115.29.239.217</string>']) {
  if (!plist.includes(marker)) throw new Error(`Info.plist API configuration marker missing: ${marker}`)
}

const profile = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'ProfileView.swift'), 'utf8')
for (const marker of ['Bundle.main', 'CFBundleShortVersionString', 'value: appVersion', 'contract.capabilities.importAnalysis.statusDisplay']) {
  if (!profile.includes(marker)) throw new Error(`Profile bundle version marker missing: ${marker}`)
}
if (profile.includes(`value: "${expectedMarketingVersion}"`)) {
  throw new Error('Profile version must not be hardcoded')
}
if (profile.includes('主线接口已连接')) {
  throw new Error('Profile must not hardcode import-analysis availability')
}

const swiftEndpoints = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'APIEndpoint.swift'), 'utf8')
const currentContracts = contractSnapshot.endpoints

for (const { method, path: endpoint, swift: swiftNeedle } of currentContracts) {
  if (!swiftEndpoints.includes(swiftNeedle)) throw new Error(`Swift endpoint missing: ${method.toUpperCase()} ${endpoint}`)
}

const importModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'ImportModels.swift'), 'utf8')
for (const field of contractSnapshot.importRequestFields) {
  if (!importModels.includes(field)) throw new Error(`mainline import field mismatch: ${field}`)
}
if (importModels.includes('reviewerId')) throw new Error('reviewer identity must come from the authenticated server session')
if (!importModels.includes('let resolution: ImportReviewResolution?')) {
  throw new Error('Harness result must preserve authenticated human-resolution provenance')
}
if (!importModels.includes('@LegacyMoney var amount: Double')) {
  throw new Error('legacy import amount must cross Codable through the exact-cent adapter')
}

const importPipeline = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'RecordImportPipeline.swift'), 'utf8')
for (const marker of ['maximumBatchRows = 30', 'maximumFileSize = 5 * 1024 * 1024', 'SHA256.hash', 'companyOwnership']) {
  if (!importPipeline.includes(marker)) throw new Error(`native import safety marker missing: ${marker}`)
}
const importView = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'RecordImportView.swift'), 'utf8')
for (const marker of ['.fileImporter(', 'confirmPendingOwnership()', 'importSession.analyze', 'importSession.commit', 'importAnalysisCapability.available', 'unavailableMessage']) {
  if (!importView.includes(marker)) throw new Error(`native import flow marker missing: ${marker}`)
}
const importSession = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'RecordImportSession.swift'), 'utf8')
for (const marker of ['session.importAnalysisCapability', 'guard capability.available else', 'capability.unavailableMessage']) {
  if (!importSession.includes(marker)) throw new Error(`import request capability gate missing: ${marker}`)
}
const quickSheet = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'QuickSheetView.swift'), 'utf8')
if (!quickSheet.includes('case .importFile:\n            RecordImportView()')) {
  throw new Error('quick import entry must open the live native import flow')
}

const financeModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'FinanceModels.swift'), 'utf8')
for (const field of contractSnapshot.ledgerProvenanceFields) {
  if (!financeModels.includes(field)) throw new Error(`ledger provenance field mismatch: ${field}`)
}
for (const marker of ['let financeSchemaVersion: String?', '@LegacyMoney var amount: Double']) {
  if (!financeModels.includes(marker)) throw new Error(`legacy compatibility model marker missing: ${marker}`)
}

const backendContract = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'BackendContract.swift'), 'utf8')
for (const marker of [expectedAPIContractVersion, expectedFinanceSchemaVersion, 'legacy_state_v1', 'cutoverState', 'cutoverReadiness', 'clientWritesEnabled', 'UnifiedDashboardMetricsCapability', 'deterministicGroupingAvailable', 'businessRecords', '"accepted", "review", "rejected"']) {
  if (!backendContract.includes(marker)) throw new Error(`backend capability marker missing: ${marker}`)
}
for (const marker of ['let reason: String?', 'provider_not_configured', 'capabilities_unavailable', 'importAnalysis: response.features.importAnalysis']) {
  if (!backendContract.includes(marker)) throw new Error(`dynamic import capability marker missing: ${marker}`)
}
if (backendContract.includes('importAnalysis: true')) {
  throw new Error('import-analysis availability must never be hardcoded true')
}

const moneyAmount = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'MoneyAmount.swift'), 'utf8')
for (const marker of ['let cents: Int64', 'struct LegacyMoney: Codable', 'container.encode(decimalValue)', 'init(decimalString:', 'var decimalString: String']) {
  if (!moneyAmount.includes(marker)) throw new Error(`lossless money marker missing: ${marker}`)
}

const resourceModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'FinanceResourceModels.swift'), 'utf8')
for (const marker of ['struct V2DecimalAmount: Codable', 'container.encode(value.decimalString)', 'let expectedVersion: Int', 'struct IdempotencyKey', 'CreateBusinessRecordCommand', 'UpdateBusinessRecordCommand']) {
  if (!resourceModels.includes(marker)) throw new Error(`Finance Resource V2 model marker missing: ${marker}`)
}
const resourceAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'FinanceResourceAPI.swift'), 'utf8')
for (const marker of ['protocol FinanceResourceAPI', 'Idempotency-Key', 'command.idempotencyKey.rawValue', '.updateBusinessRecord(recordId: command.recordId)']) {
  if (!resourceAPI.includes(marker)) throw new Error(`Finance Resource V2 client marker missing: ${marker}`)
}
const readinessModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'CutoverReadinessModels.swift'), 'utf8')
for (const marker of ['struct CutoverReadinessResponse: Codable', 'struct CutoverReadinessQuery', 'V2DecimalAmount', 'nextCursor', 'businessRecordWriteCutoverEligible']) {
  if (!readinessModels.includes(marker)) throw new Error(`cutover readiness model marker missing: ${marker}`)
}
const readinessAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'CutoverReadinessAPI.swift'), 'utf8')
for (const marker of ['protocol CutoverReadinessAPI', 'func readiness(', '.cutoverReadiness(query)']) {
  if (!readinessAPI.includes(marker)) throw new Error(`cutover readiness API marker missing: ${marker}`)
}
if (/\b(post|put|patch|delete)\b/i.test(readinessAPI)) {
  throw new Error('cutover readiness client must remain read-only')
}
const metricsModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'DashboardMetricsModels.swift'), 'utf8')
for (const marker of ['struct DashboardMetricsResponse: Codable', 'V2DecimalAmount', 'netCashFlow', 'classificationCoverage', 'rawBusinessRecordsMerged', 'modelWritesBusinessRecords', 'reviewSuggestionsAffectRawFacts']) {
  if (!metricsModels.includes(marker)) throw new Error(`dashboard metrics model marker missing: ${marker}`)
}
const metricsAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'DashboardMetricsAPI.swift'), 'utf8')
for (const marker of ['protocol DashboardMetricsAPI', 'func metrics(', '.dashboardMetrics(query)']) {
  if (!metricsAPI.includes(marker)) throw new Error(`dashboard metrics API marker missing: ${marker}`)
}
if (/\b(post|put|patch|delete)\b/i.test(metricsAPI)) {
  throw new Error('dashboard metrics client must remain read-only')
}
const httpTransport = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'HTTPTransport.swift'), 'utf8')
for (const marker of ['case versionConflict', 'VERSION_CONFLICT', 'headers: [String: String]']) {
  if (!httpTransport.includes(marker)) throw new Error(`V2 transport marker missing: ${marker}`)
}
const appSession = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'AppSession.swift'), 'utf8')
if (appSession.includes('FinanceResourceAPI') || appSession.includes('CutoverReadinessAPI') || appSession.includes('DashboardMetricsAPI') || appSession.includes('/api/v2')) {
  throw new Error('shadow V2 clients must not become the AppSession data source')
}

const serverPath = path.join(workspace, 'server', 'index.ts')
const importSchemaPath = path.join(workspace, 'server', 'import-analysis.ts')
const stateSchemaPath = path.join(workspace, 'server', 'schema.ts')
const financeDomainPath = path.join(workspace, 'server', 'finance-domain.ts')
const capabilitiesPath = path.join(workspace, 'server', 'capabilities.ts')
const financeResourcesPath = path.join(workspace, 'server', 'finance-resources.ts')
const financeCutoverPath = path.join(workspace, 'server', 'finance-cutover.ts')
const dashboardMetricsPath = path.join(workspace, 'server', 'dashboard-metrics.ts')
const apiContractDocumentPath = path.join(workspace, 'API-V2-CONTRACT.md')
const mainPackagePath = path.join(workspace, 'package.json')
const hasLocalBackend = process.env.UWAY_SKIP_LOCAL_BACKEND !== '1'
  && [serverPath, importSchemaPath, stateSchemaPath, financeDomainPath, capabilitiesPath, financeResourcesPath, financeCutoverPath, dashboardMetricsPath, apiContractDocumentPath].every(fs.existsSync)
if (hasLocalBackend) {
  const server = fs.readFileSync(serverPath, 'utf8')
  for (const { method, path: endpoint } of currentContracts) {
    if (!server.includes(`app.${method}('${endpoint}'`)) throw new Error(`local server endpoint missing: ${method.toUpperCase()} ${endpoint}`)
  }
  const importSchema = fs.readFileSync(importSchemaPath, 'utf8')
  for (const field of contractSnapshot.importRequestFields) {
    if (!importSchema.includes(field)) throw new Error(`local import schema mismatch: ${field}`)
  }
  const stateSchema = fs.readFileSync(stateSchemaPath, 'utf8')
  for (const field of contractSnapshot.ledgerProvenanceFields) {
    if (!stateSchema.includes(field)) throw new Error(`local state schema mismatch: ${field}`)
  }
  const financeDomain = fs.readFileSync(financeDomainPath, 'utf8')
  if (!financeDomain.includes(`FINANCE_SCHEMA_VERSION = '${expectedFinanceSchemaVersion}'`)) {
    throw new Error('local finance domain schema version mismatch')
  }
  if (!server.includes('financeSchemaVersion: FINANCE_SCHEMA_VERSION')) {
    throw new Error('local health response must expose financeSchemaVersion')
  }
  if (!server.includes('createServerCapabilities({ importAnalysisAvailable: importClassifier !== null })')) {
    throw new Error('local capabilities endpoint must derive import availability from configured classifier state')
  }
  const capabilities = fs.readFileSync(capabilitiesPath, 'utf8')
  for (const marker of [
    'createServerCapabilities',
    `API_CONTRACT_VERSION = '${expectedAPIContractVersion}'`,
    "preferredMode: 'legacy_state_v1'",
    "availableModes: ['legacy_state_v1']",
    "cutoverState: 'shadow'",
    "contextEndpoint: '/api/v2/context'",
    "endpoint: '/api/v2/cutover-readiness'",
    'requiresZeroDifferences: true',
    'requiresZeroShadowOnlyRecords: true',
    'clientWritesEnabled: false',
    "endpoint: '/api/v2/dashboard-metrics'",
    "source: 'finance_v2_shadow_read_model'",
    'rawRecordsMerged: false',
    'deterministicGroupingAvailable: true',
    "pagination: 'cursor'",
    "idempotencyHeader: 'Idempotency-Key'",
    "concurrencyControl: 'expectedVersion'",
    "legacyStateEncoding: 'json_number'",
    "financeV2Encoding: 'decimal_string'",
    'databasePrecision: 18',
    'databaseScale: 2',
    'aiMayWriteBusinessRecords: false',
    'aiMayPostJournalVouchers: false',
    "reason: options.importAnalysisAvailable ? null : 'provider_not_configured'",
  ]) {
    if (!capabilities.includes(marker)) throw new Error(`local capabilities marker missing: ${marker}`)
  }
  const financeResources = fs.readFileSync(financeResourcesPath, 'utf8')
  for (const marker of ['amount::text', 'nextCursor', 'expectedVersion', 'VERSION_CONFLICT', 'IDEMPOTENCY_KEY_REUSED']) {
    if (!financeResources.includes(marker)) throw new Error(`local finance resource marker missing: ${marker}`)
  }
  const financeCutover = fs.readFileSync(financeCutoverPath, 'utf8')
  for (const marker of ['INVALID_CUTOVER_CURSOR', 'CUTOVER_READINESS_FORBIDDEN', 'businessRecordReadCutoverEligible', 'businessRecordWriteCutoverEligible: false', 'fullFinanceCutoverEligible: false']) {
    if (!financeCutover.includes(marker)) throw new Error(`local cutover readiness marker missing: ${marker}`)
  }
  const dashboardMetrics = fs.readFileSync(dashboardMetricsPath, 'utf8')
  for (const marker of ['DASHBOARD_METRICS_FORBIDDEN', 'INVALID_DASHBOARD_PERIOD', 'netCashFlow', 'rawBusinessRecordsMerged: false', 'modelWritesBusinessRecords: false', 'reviewSuggestionsAffectRawFacts: false']) {
    if (!dashboardMetrics.includes(marker)) throw new Error(`local dashboard metrics marker missing: ${marker}`)
  }
  const apiContractDocument = fs.readFileSync(apiContractDocumentPath, 'utf8')
  const staleDocumentMarkers = []
  for (const marker of [expectedMarketingVersion, expectedAPIContractVersion, expectedFinanceSchemaVersion, 'legacy_state_v1']) {
    if (!apiContractDocument.includes(marker)) staleDocumentMarkers.push(marker)
  }
  if (staleDocumentMarkers.length > 0) {
    console.warn(`mainline API-V2-CONTRACT.md is stale for candidate markers: ${staleDocumentMarkers.join(', ')}`)
  }
  if (fs.existsSync(mainPackagePath)) {
    const mainPackage = JSON.parse(fs.readFileSync(mainPackagePath, 'utf8'))
    if (mainPackage.version !== expectedMarketingVersion) {
      console.warn(`mainline package.json version is ${mainPackage.version}; candidate contract expects ${expectedMarketingVersion}`)
    }
  }
}

const ledger = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'LedgerView.swift'), 'utf8')
if (!ledger.includes('fixedControls') || !ledger.includes('ledgerScroll')) throw new Error('ledger fixed/scroll boundary missing')
if (ledger.includes('pinnedViews:')) throw new Error('month headings must not be sticky')

const workflow = fs.readFileSync(workflowPath, 'utf8')
for (const marker of [
  'runs-on: macos-26',
  'uses: actions/checkout@v7',
  'xcodegen generate --spec project.yml',
  'build-for-testing',
  'Verify built API configuration',
  'test-without-building',
  'CODE_SIGNING_ALLOWED=NO',
  'uses: actions/upload-artifact@v7',
]) {
  if (!workflow.includes(marker)) throw new Error(`iOS CI marker missing: ${marker}`)
}

console.log(`validated iOS ${expectedMarketingVersion}: ${requiredFiles.length} files, ${currentContracts.length} API contracts, ${fixtures.length} JSON fixtures, macOS CI${hasLocalBackend ? ', local backend cross-check' : ''}`)
