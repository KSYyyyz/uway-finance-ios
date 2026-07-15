import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const workspace = path.resolve(root, '..', '..')
const expectedMarketingVersion = '0.12.0'
const expectedBackendVersion = '0.12.0'
const expectedAPIContractVersion = '20260715_008'
const expectedFinanceSchemaVersion = '20260715_004_account_book_preference_memory'
const workflowPath = path.join(root, '.github', 'workflows', 'ios-ci.yml')
const contractSnapshotPath = path.join(root, 'ContractSnapshots', 'backend-api-v0.12.0.json')

const requiredFiles = [
  'project.yml',
  'ContractSnapshots/backend-api-v0.12.0.json',
  'UwayFinance/App/UwayFinanceApp.swift',
  'UwayFinance/Networking/APIEndpoint.swift',
  'UwayFinance/Networking/FinanceAPI.swift',
  'UwayFinance/Networking/ImportAnalysisAPI.swift',
  'UwayFinance/Networking/DocumentAPI.swift',
  'UwayFinance/Networking/FinanceResourceAPI.swift',
  'UwayFinance/Networking/CutoverReadinessAPI.swift',
  'UwayFinance/Networking/DashboardMetricsAPI.swift',
  'UwayFinance/Networking/ClassificationReviewAPI.swift',
  'UwayFinance/Networking/ClassificationPreferenceAPI.swift',
  'UwayFinance/Models/BackendContract.swift',
  'UwayFinance/Models/FinanceResourceModels.swift',
  'UwayFinance/Models/CutoverReadinessModels.swift',
  'UwayFinance/Models/DashboardMetricsModels.swift',
  'UwayFinance/Models/ClassificationReviewModels.swift',
  'UwayFinance/Models/ClassificationPreferenceModels.swift',
  'UwayFinance/Models/RecordDeepLink.swift',
  'UwayFinance/Models/MoneyAmount.swift',
  'UwayFinance/Models/RecordImportPipeline.swift',
  'UwayFinance/State/RecordImportSession.swift',
  'UwayFinance/State/ClassificationReviewStore.swift',
  'UwayFinance/State/ClassificationPreferenceStore.swift',
  'UwayFinance/Views/RecordImportView.swift',
  'UwayFinance/Views/LedgerView.swift',
  'UwayFinance/Views/ClassificationReviewView.swift',
  'UwayFinance/Views/ClassificationPreferenceView.swift',
  'UwayFinance/Views/RecordDetailView.swift',
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
  'UwayFinanceTests/ClassificationReviewAPITests.swift',
  'UwayFinanceTests/ClassificationReviewStoreTests.swift',
  'UwayFinanceTests/ClassificationPreferenceAPITests.swift',
  'UwayFinanceTests/ClassificationPreferenceStoreTests.swift',
  'UwayFinanceTests/RecordDeepLinkTests.swift',
  'UwayFinanceTests/LegacyStateConditionalWriteAPITests.swift',
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
  'UwayFinanceTests/Fixtures/health-classification-review-v0.11.0.json',
  'UwayFinanceTests/Fixtures/capabilities-classification-review-v0.11.0.json',
  'UwayFinanceTests/Fixtures/state-empty-v0.11.0.json',
  'UwayFinanceTests/Fixtures/state-save-v0.11.0.json',
  'UwayFinanceTests/Fixtures/state-version-conflict-v0.11.0.json',
  'UwayFinanceTests/Fixtures/state-record-deeplink-v0.11.0.json',
  'UwayFinanceTests/Fixtures/health-preference-memory-v0.12.0.json',
  'UwayFinanceTests/Fixtures/capabilities-preference-memory-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preferences-active-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preferences-revoked-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preference-revoke-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preference-version-conflict-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preference-forbidden-v0.12.0.json',
  'UwayFinanceTests/Fixtures/classification-preference-invalid-cursor-v0.12.0.json',
  'Docs/PERSONALIZATION_CONTRACT_REQUIREMENTS.md',
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
  'health-classification-review-v0.11.0.json',
  'capabilities-classification-review-v0.11.0.json',
  'classification-reviews-pending-v0.11.0.json',
  'classification-reviews-accepted-v0.11.0.json',
  'classification-reviews-rejected-v0.11.0.json',
  'classification-analysis-accepted-v0.11.0.json',
  'classification-analysis-review-v0.11.0.json',
  'classification-analysis-rejected-v0.11.0.json',
  'classification-decision-confirm-v0.11.0.json',
  'classification-decision-correct-v0.11.0.json',
  'classification-decision-reject-v0.11.0.json',
  'classification-record-conflict-v0.11.0.json',
  'classification-version-conflict-v0.11.0.json',
  'classification-forbidden-v0.11.0.json',
  'classification-ai-unavailable-v0.11.0.json',
  'state-empty-v0.11.0.json',
  'state-save-v0.11.0.json',
  'state-version-conflict-v0.11.0.json',
  'state-record-deeplink-v0.11.0.json',
  'health-preference-memory-v0.12.0.json',
  'capabilities-preference-memory-v0.12.0.json',
  'classification-preferences-active-v0.12.0.json',
  'classification-preferences-revoked-v0.12.0.json',
  'classification-preference-revoke-v0.12.0.json',
  'classification-preference-version-conflict-v0.12.0.json',
  'classification-preference-forbidden-v0.12.0.json',
  'classification-preference-invalid-cursor-v0.12.0.json',
]
for (const fixture of fixtures) {
  JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', fixture), 'utf8'))
}

const deepLinkStateFixture = JSON.parse(fs.readFileSync(
  path.join(root, 'UwayFinanceTests', 'Fixtures', 'state-record-deeplink-v0.11.0.json'),
  'utf8',
))
if (!deepLinkStateFixture.data?.records?.some((record) => record.id === '102')) {
  throw new Error('record deep-link fixture must match the current classification-review recordId')
}

const viewDirectory = path.join(root, 'UwayFinance', 'Views')
const listSwiftFiles = (directory) => fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const itemPath = path.join(directory, entry.name)
  if (entry.isDirectory()) return listSwiftFiles(itemPath)
  return entry.isFile() && entry.name.endsWith('.swift') ? [itemPath] : []
})
const viewFiles = listSwiftFiles(viewDirectory)
for (const file of viewFiles) {
  const source = fs.readFileSync(file, 'utf8')
  const scrollContainerCount = (source.match(/\b(?:ScrollView|List|Form)\s*\{|\bTextEditor\s*\(|\bTextField\([^\n]*axis:\s*\.vertical/g) ?? []).length
  const hiddenIndicatorCount = (source.match(/\.appScrollIndicatorsHidden\(\)/g) ?? []).length
  if (scrollContainerCount !== hiddenIndicatorCount) {
    throw new Error(`every scrolling container must hide only its visual indicator: ${path.relative(root, file)}`)
  }
}

const decisionResponse = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-decision-response.json'), 'utf8'))
if (decisionResponse.status !== 'accepted') throw new Error('accepted human decision must keep Harness status accepted')
if (decisionResponse.resolution?.decision !== 'accept' || !decisionResponse.resolution?.reviewer) {
  throw new Error('human decision provenance must remain in resolution.decision/reviewer')
}

const contractSnapshot = JSON.parse(fs.readFileSync(contractSnapshotPath, 'utf8'))
if (contractSnapshot.version !== expectedMarketingVersion) throw new Error('backend contract snapshot version mismatch')
if (contractSnapshot.backendAppVersion !== expectedBackendVersion) throw new Error('backend app version snapshot mismatch')
if (contractSnapshot.apiContractVersion !== expectedAPIContractVersion) {
  throw new Error('backend contract snapshot API contract version mismatch')
}
if (contractSnapshot.financeSchemaVersion !== expectedFinanceSchemaVersion) {
  throw new Error('backend contract snapshot finance schema mismatch')
}
if (contractSnapshot.syncMode !== 'legacy_state_v1') {
  throw new Error('iOS must remain on the legacy-state compatibility path')
}
const legacyStateSnapshot = contractSnapshot.capabilities?.legacyState
if (legacyStateSnapshot?.readable !== true
    || legacyStateSnapshot?.writable !== true
    || legacyStateSnapshot?.conflictControl !== 'optional_if_match'
    || legacyStateSnapshot?.versionSource !== 'updatedAt'
    || legacyStateSnapshot?.etagHeader !== 'ETag'
    || legacyStateSnapshot?.conditionalWriteHeader !== 'If-Match') {
  throw new Error('legacy state conditional-write snapshot mismatch')
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
  throw new Error('V2 shadow resource capabilities do not match the classification-review backend boundary')
}
const metricsSnapshot = contractSnapshot.capabilities?.unifiedDashboardMetrics
if (metricsSnapshot?.available !== true
    || metricsSnapshot?.endpoint !== '/api/v2/dashboard-metrics'
    || metricsSnapshot?.moneyEncoding !== 'decimal_string'
    || metricsSnapshot?.source !== 'finance_v2_shadow_read_model'
    || metricsSnapshot?.rawRecordsMerged !== false
    || metricsSnapshot?.classificationStates?.join(',') !== 'accepted,review,unclassified') {
  throw new Error('dashboard metrics snapshot must remain governed, read-only and deterministic')
}
const classificationSnapshot = contractSnapshot.capabilities?.classificationReview
const preferenceMemorySnapshot = contractSnapshot.capabilities?.classificationPreferenceMemory
const classificationAISnapshot = contractSnapshot.capabilities?.aiClassification
if (classificationSnapshot?.available !== true
    || classificationSnapshot?.listEndpoint !== '/api/v2/classification-reviews'
    || classificationSnapshot?.pagination !== 'cursor'
    || classificationSnapshot?.defaultPageSize !== 10
    || classificationSnapshot?.decisions?.join(',') !== 'confirm,correct,reject'
    || classificationSnapshot?.idempotencyHeader !== 'Idempotency-Key'
    || classificationSnapshot?.concurrencyControl?.join(',') !== 'expectedRecordVersion,expectedClassificationVersion'
    || classificationSnapshot?.modelCanAccept !== false
    || classificationSnapshot?.deterministicRuleMayAccept !== true
    || classificationSnapshot?.rawBusinessRecordsChanged !== false
    || classificationAISnapshot?.available !== 'runtime'
    || classificationAISnapshot?.contract !== 'closed_set_existing_operating_item_v1'
    || classificationAISnapshot?.deterministicGroupingAvailable !== true
    || classificationAISnapshot?.modelCanAccept !== false
    || classificationAISnapshot?.writesBusinessRecords !== false) {
  throw new Error('classification review snapshot safety boundary mismatch')
}
if (preferenceMemorySnapshot?.available !== true
    || preferenceMemorySnapshot?.listEndpoint !== '/api/v2/classification-preferences'
    || preferenceMemorySnapshot?.revokeEndpoint !== '/api/v2/classification-preferences/:observationId/revoke'
    || preferenceMemorySnapshot?.pagination !== 'cursor'
    || preferenceMemorySnapshot?.scope !== 'account_book'
    || preferenceMemorySnapshot?.source !== 'explicit_authenticated_human_decisions'
    || preferenceMemorySnapshot?.minimumConsistentObservations !== 3
    || preferenceMemorySnapshot?.minimumConsistency !== 0.8
    || preferenceMemorySnapshot?.lifecycleStates?.join(',') !== 'active,revoked,invalidated'
    || preferenceMemorySnapshot?.effect !== 'closed_candidate_reordering_only'
    || preferenceMemorySnapshot?.idempotencyHeader !== 'Idempotency-Key'
    || preferenceMemorySnapshot?.concurrencyControl !== 'expectedVersion'
    || preferenceMemorySnapshot?.modelCanAccept !== false
    || preferenceMemorySnapshot?.writesBusinessRecords !== false) {
  throw new Error('classification preference-memory snapshot safety boundary mismatch')
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

const capabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-preference-memory-v0.12.0.json'), 'utf8'))
const healthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-preference-memory-v0.12.0.json'), 'utf8'))
if (healthFixture.version !== expectedBackendVersion
    || healthFixture.financeSchemaVersion !== expectedFinanceSchemaVersion) {
  throw new Error('preference-memory health fixture version/schema mismatch')
}
if (capabilitiesFixture.version !== expectedBackendVersion
    || capabilitiesFixture.apiContractVersion !== expectedAPIContractVersion
    || capabilitiesFixture.sync?.preferredMode !== 'legacy_state_v1'
    || capabilitiesFixture.sync?.availableModes?.join(',') !== 'legacy_state_v1') {
  throw new Error('capabilities fixture must publish only legacy_state_v1')
}
if (capabilitiesFixture.sync?.legacyState?.readable !== true
    || capabilitiesFixture.sync?.legacyState?.writable !== true
    || capabilitiesFixture.sync?.legacyState?.conflictControl !== 'optional_if_match'
    || capabilitiesFixture.sync?.legacyState?.versionSource !== 'updatedAt'
    || capabilitiesFixture.sync?.legacyState?.etagHeader !== 'ETag'
    || capabilitiesFixture.sync?.legacyState?.conditionalWriteHeader !== 'If-Match') {
  throw new Error('capabilities fixture must advertise optional If-Match state protection')
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
  throw new Error('current 0.12.0 capabilities fixture must preserve read-only readiness and the shadow resource slice')
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
    || capabilitiesFixture.features?.aiClassification?.available !== true
    || capabilitiesFixture.features?.aiClassification?.contract !== 'closed_set_existing_operating_item_v1'
    || capabilitiesFixture.features?.aiClassification?.modelCanAccept !== false
    || capabilitiesFixture.features?.aiClassification?.writesBusinessRecords !== false
    || capabilitiesFixture.features?.aiClassification?.deterministicGroupingAvailable !== true) {
  throw new Error('classification AI capability must remain closed-set and non-writing')
}
for (const feature of ['workflowTasks', 'documentUpload', 'ocr']) {
  const value = capabilitiesFixture.features?.[feature]
  if (value?.available !== false) throw new Error(`future capability must remain unavailable: ${feature}`)
}
if (capabilitiesFixture.safety?.aiMayWriteBusinessRecords !== false
    || capabilitiesFixture.safety?.aiMayPostJournalVouchers !== false) {
  throw new Error('capabilities fixture must preserve AI write safety')
}

const oldClassificationCapability = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.10.2.json'), 'utf8')).features?.classificationReview
if (oldClassificationCapability !== undefined) {
  throw new Error('0.10.2 fixture must prove classificationReview is optional')
}
const historicalHealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-v0.10.2.json'), 'utf8'))
const historicalCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.10.2.json'), 'utf8'))
if (historicalHealthFixture.version !== '0.10.2'
    || historicalCapabilitiesFixture.version !== '0.10.2'
    || historicalCapabilitiesFixture.apiContractVersion !== '20260714_004') {
  throw new Error('dedicated 0.10.2 backward-compat fixtures must remain historical and immutable')
}
const historicalReviewHealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-classification-review-v0.11.0.json'), 'utf8'))
const historicalReviewCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-classification-review-v0.11.0.json'), 'utf8'))
if (historicalReviewHealthFixture.version !== '0.11.0'
    || historicalReviewCapabilitiesFixture.version !== '0.11.0'
    || historicalReviewCapabilitiesFixture.apiContractVersion !== '20260714_007'
    || historicalReviewCapabilitiesFixture.features?.classificationPreferenceMemory !== undefined) {
  throw new Error('dedicated 0.11.0 backward-compat fixtures must remain historical and omit preference memory')
}
const reviewCapability = capabilitiesFixture.features?.classificationReview
if (reviewCapability?.available !== true
    || reviewCapability?.defaultPageSize !== 10
    || reviewCapability?.pagination !== 'cursor'
    || reviewCapability?.decisions?.join(',') !== 'confirm,correct,reject'
    || reviewCapability?.modelCanAccept !== false
    || reviewCapability?.deterministicRuleMayAccept !== true
    || reviewCapability?.rawBusinessRecordsChanged !== false) {
  throw new Error('classification review capability fixture is unsafe or incomplete')
}
const pendingReviews = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-reviews-pending-v0.11.0.json'), 'utf8'))
const acceptedReviews = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-reviews-accepted-v0.11.0.json'), 'utf8'))
const rejectedReviews = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-reviews-rejected-v0.11.0.json'), 'utf8'))
if (pendingReviews.page?.limit !== 10
    || typeof pendingReviews.page?.nextCursor !== 'string'
    || pendingReviews.items?.[0]?.record?.amount !== '1170.00'
    || pendingReviews.items?.[0]?.proposal?.classificationState !== 'review'
    || pendingReviews.safety?.rawBusinessRecordsChanged !== false
    || pendingReviews.safety?.modelCanAccept !== false
    || acceptedReviews.items?.[0]?.reviewState !== 'accepted'
    || rejectedReviews.items?.[0]?.reviewState !== 'rejected') {
  throw new Error('classification list fixtures must preserve cursor, decimal money and three-state review boundaries')
}
for (const [name, expectedStatus] of [
  ['classification-analysis-accepted-v0.11.0.json', 'accepted'],
  ['classification-analysis-review-v0.11.0.json', 'review'],
  ['classification-analysis-rejected-v0.11.0.json', 'rejected'],
]) {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', name), 'utf8'))
  if (value.analysis?.status !== expectedStatus
      || value.analysis?.writesBusinessRecord !== false
      || value.safety?.modelCanAccept !== false
      || value.safety?.modelWritesBusinessRecords !== false) {
    throw new Error(`classification analysis safety mismatch: ${name}`)
  }
}
for (const action of ['confirm', 'correct', 'reject']) {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', `classification-decision-${action}-v0.11.0.json`), 'utf8'))
  if (value.decision?.action !== action || value.safety?.rawBusinessRecordChanged !== false) {
    throw new Error(`classification decision fixture mismatch: ${action}`)
  }
}
const classificationErrorCodes = [
  ['classification-record-conflict-v0.11.0.json', 'VERSION_CONFLICT'],
  ['classification-version-conflict-v0.11.0.json', 'CLASSIFICATION_VERSION_CONFLICT'],
  ['classification-forbidden-v0.11.0.json', 'CLASSIFICATION_REVIEW_FORBIDDEN'],
  ['classification-ai-unavailable-v0.11.0.json', 'CLASSIFICATION_AI_UNAVAILABLE'],
]
for (const [name, code] of classificationErrorCodes) {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', name), 'utf8'))
  if (value.code !== code) throw new Error(`classification error fixture mismatch: ${name}`)
}
const preferenceCapability = capabilitiesFixture.features?.classificationPreferenceMemory
if (preferenceCapability?.available !== true
    || preferenceCapability?.listEndpoint !== '/api/v2/classification-preferences'
    || preferenceCapability?.revokeEndpoint !== '/api/v2/classification-preferences/:observationId/revoke'
    || preferenceCapability?.pagination !== 'cursor'
    || preferenceCapability?.scope !== 'account_book'
    || preferenceCapability?.source !== 'explicit_authenticated_human_decisions'
    || preferenceCapability?.minimumConsistentObservations !== 3
    || preferenceCapability?.minimumConsistency !== 0.8
    || preferenceCapability?.lifecycleStates?.join(',') !== 'active,revoked,invalidated'
    || preferenceCapability?.effect !== 'closed_candidate_reordering_only'
    || preferenceCapability?.idempotencyHeader !== 'Idempotency-Key'
    || preferenceCapability?.concurrencyControl !== 'expectedVersion'
    || preferenceCapability?.modelCanAccept !== false
    || preferenceCapability?.writesBusinessRecords !== false) {
  throw new Error('classification preference-memory capability fixture is unsafe or incomplete')
}
const activePreferences = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-preferences-active-v0.12.0.json'), 'utf8'))
const revokedPreferences = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-preferences-revoked-v0.12.0.json'), 'utf8'))
const revokePreference = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'classification-preference-revoke-v0.12.0.json'), 'utf8'))
if (activePreferences.accountBook?.id !== '11'
    || activePreferences.items?.some((item) => item.accountBookId !== activePreferences.accountBook.id)
    || activePreferences.page?.limit !== 10
    || typeof activePreferences.page?.nextCursor !== 'string'
    || activePreferences.safety?.accountBookScoped !== true
    || activePreferences.safety?.modelCanAccept !== false
    || activePreferences.safety?.writesBusinessRecords !== false
    || revokedPreferences.items?.[0]?.lifecycle?.state !== 'revoked'
    || revokePreference.observation?.lifecycle?.state !== 'revoked'
    || revokePreference.safety?.recomputedFromActiveEvents !== true
    || revokePreference.safety?.modelCanAccept !== false
    || revokePreference.safety?.writesBusinessRecords !== false) {
  throw new Error('classification preference fixtures must preserve account-book scope, lifecycle and non-writing safety')
}
for (const [name, code] of [
  ['classification-preference-version-conflict-v0.12.0.json', 'CLASSIFICATION_PREFERENCE_VERSION_CONFLICT'],
  ['classification-preference-forbidden-v0.12.0.json', 'CLASSIFICATION_PREFERENCE_FORBIDDEN'],
  ['classification-preference-invalid-cursor-v0.12.0.json', 'INVALID_CLASSIFICATION_PREFERENCE_CURSOR'],
]) {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', name), 'utf8'))
  if (value.code !== code) throw new Error(`classification preference error fixture mismatch: ${name}`)
}
const emptyStateFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'state-empty-v0.11.0.json'), 'utf8'))
const stateSaveFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'state-save-v0.11.0.json'), 'utf8'))
const stateConflictFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'state-version-conflict-v0.11.0.json'), 'utf8'))
if (emptyStateFixture.updatedAt !== null
    || stateSaveFixture.updatedAt !== '2026-07-15T00:02:00.000Z'
    || stateConflictFixture.code !== 'STATE_VERSION_CONFLICT'
    || stateConflictFixture.details?.currentUpdatedAt !== '2026-07-15T00:01:00.000Z') {
  throw new Error('legacy state revision fixtures must preserve empty, saved and conflict revisions')
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
for (const marker of ['Bundle.main', 'CFBundleShortVersionString', 'value: appVersion', 'contract.capabilities.importAnalysis.statusDisplay', 'classificationPreferenceMemory?.statusDisplay']) {
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
for (const marker of ['let financeSchemaVersion: String?', '@LegacyMoney var amount: Double', 'struct StateRevision', 'static let empty', 'ifMatchHeaderValue']) {
  if (!financeModels.includes(marker)) throw new Error(`legacy compatibility model marker missing: ${marker}`)
}

const backendContract = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'BackendContract.swift'), 'utf8')
for (const marker of [expectedAPIContractVersion, expectedFinanceSchemaVersion, 'legacy_state_v1', 'versionSource', 'etagHeader', 'conditionalWriteHeader', 'cutoverState', 'cutoverReadiness', 'clientWritesEnabled', 'UnifiedDashboardMetricsCapability', 'ClassificationReviewCapability', 'ClassificationPreferenceMemoryCapability', 'closed_candidate_reordering_only', 'explicit_authenticated_human_decisions', 'deterministicGroupingAvailable', 'modelCanAccept', 'writesBusinessRecords', 'businessRecords', '"accepted", "review", "rejected"']) {
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
const classificationModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'ClassificationReviewModels.swift'), 'utf8')
for (const marker of ['V2DecimalAmount', 'case confirm', 'case correct', 'case reject', 'expectedRecordVersion', 'expectedClassificationVersion', 'normalizedItemName', 'ClassificationAnalyzeCommand', 'ClassificationDecisionCommand']) {
  if (!classificationModels.includes(marker)) throw new Error(`classification model marker missing: ${marker}`)
}
if (classificationModels.includes('normalizedGroupName') || /\n\s*case accept\s*\n/.test(classificationModels)) {
  throw new Error('classification client must use current server confirm/normalizedItemName vocabulary')
}
const classificationAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'ClassificationReviewAPI.swift'), 'utf8')
for (const marker of ['protocol ClassificationReviewAPI', 'Idempotency-Key', 'command.idempotencyKey.rawValue', '.analyzeClassification', '.decideClassification']) {
  if (!classificationAPI.includes(marker)) throw new Error(`classification API marker missing: ${marker}`)
}
const classificationStore = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'ClassificationReviewStore.swift'), 'utf8')
for (const marker of ['limit: 10', 'cursorStack', 'pendingAnalyze', 'pendingDecision', 'CLASSIFICATION_AI_UNAVAILABLE', 'CLASSIFICATION_VERSION_CONFLICT', '本地理由和更正草稿仍然保留']) {
  if (!classificationStore.includes(marker)) throw new Error(`classification retry/draft marker missing: ${marker}`)
}
const classificationView = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'ClassificationReviewView.swift'), 'utf8')
for (const marker of ['closed_set_existing_operating_item_v1', 'modelCanAccept == false', 'writesBusinessRecords == false', '每页最多 10 条']) {
  if (!classificationView.includes(marker)) throw new Error(`classification workbench safety marker missing: ${marker}`)
}
const preferenceModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'ClassificationPreferenceModels.swift'), 'utf8')
for (const marker of ['ClassificationPreferenceObservation', 'accountBookId', 'expectedVersion', 'ClassificationPreferenceRevokeCommand', 'IdempotencyKey', 'case active', 'case revoked', 'case invalidated']) {
  if (!preferenceModels.includes(marker)) throw new Error(`classification preference model marker missing: ${marker}`)
}
const preferenceAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'ClassificationPreferenceAPI.swift'), 'utf8')
for (const marker of ['protocol ClassificationPreferenceAPI', '.classificationPreferences(query)', '.revokeClassificationPreference', 'Idempotency-Key', 'command.idempotencyKey.rawValue']) {
  if (!preferenceAPI.includes(marker)) throw new Error(`classification preference API marker missing: ${marker}`)
}
const preferenceStore = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'ClassificationPreferenceStore.swift'), 'utf8')
for (const marker of ['limit: 10', 'cursorStack', 'pendingRevokes', 'CLASSIFICATION_PREFERENCE_VERSION_CONFLICT', '当前筛选和分页', 'clearAccountScopedState', 'accountBookScoped', 'writesBusinessRecords == false']) {
  if (!preferenceStore.includes(marker)) throw new Error(`classification preference isolation/retry marker missing: ${marker}`)
}
const preferenceView = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'ClassificationPreferenceView.swift'), 'utf8')
for (const marker of ['账套级分类记忆', '每页最多 10 条', '撤销这条学习记录', 'TextEditor', 'appScrollIndicatorsHidden']) {
  if (!preferenceView.includes(marker)) throw new Error(`classification preference UI marker missing: ${marker}`)
}
const httpTransport = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'HTTPTransport.swift'), 'utf8')
for (const marker of ['case versionConflict', 'case stateVersionConflict', 'STATE_VERSION_CONFLICT', 'currentUpdatedAt', 'headers: [String: String]']) {
  if (!httpTransport.includes(marker)) throw new Error(`V2 transport marker missing: ${marker}`)
}
const financeAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'FinanceAPI.swift'), 'utf8')
for (const marker of ['ifMatch revision: StateRevision', 'headers: ["If-Match": revision.ifMatchHeaderValue]', 'StateRevision(updatedAt: updatedAt)']) {
  if (!financeAPI.includes(marker)) throw new Error(`legacy state conditional-write API marker missing: ${marker}`)
}
if (financeAPI.includes('ISO8601DateFormatter().string(from: Date())')) {
  throw new Error('conditional state revision must never be invented client-side')
}
const appSession = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'AppSession.swift'), 'utf8')
if (appSession.includes('FinanceResourceAPI') || appSession.includes('CutoverReadinessAPI') || appSession.includes('DashboardMetricsAPI') || appSession.includes('ClassificationReviewAPI') || appSession.includes('ClassificationPreferenceAPI') || appSession.includes('/api/v2')) {
  throw new Error('shadow V2 clients must not become the AppSession data source')
}
for (const marker of ['stateRevision', 'unsavedSnapshot', 'conflictingServerRevision', 'catch APIError.stateVersionConflict', 'resolveStateConflictAndRetry', '其他设备已更新，需要核对']) {
  if (!appSession.includes(marker)) throw new Error(`AppSession conflict preservation marker missing: ${marker}`)
}

const serverPath = path.join(workspace, 'server', 'index.ts')
const healthPath = path.join(workspace, 'server', 'health.ts')
const importSchemaPath = path.join(workspace, 'server', 'import-analysis.ts')
const stateSchemaPath = path.join(workspace, 'server', 'schema.ts')
const financeDomainPath = path.join(workspace, 'server', 'finance-domain.ts')
const capabilitiesPath = path.join(workspace, 'server', 'capabilities.ts')
const financeResourcesPath = path.join(workspace, 'server', 'finance-resources.ts')
const financeCutoverPath = path.join(workspace, 'server', 'finance-cutover.ts')
const dashboardMetricsPath = path.join(workspace, 'server', 'dashboard-metrics.ts')
const classificationReviewPath = path.join(workspace, 'server', 'classification-review.ts')
const classificationAnalysisPath = path.join(workspace, 'server', 'classification-analysis.ts')
const classificationPreferencesPath = path.join(workspace, 'server', 'classification-preferences.ts')
const apiContractDocumentPath = path.join(workspace, 'API-V2-CONTRACT.md')
const mainPackagePath = path.join(workspace, 'package.json')
const hasMainPackage = fs.existsSync(mainPackagePath)
const hasMainContractDocument = fs.existsSync(apiContractDocumentPath)
if (hasMainPackage !== hasMainContractDocument) {
  throw new Error('mainline package.json and API-V2-CONTRACT.md must be validated together')
}
if (hasMainPackage && hasMainContractDocument) {
  const mainPackage = JSON.parse(fs.readFileSync(mainPackagePath, 'utf8'))
  if (mainPackage.version !== expectedBackendVersion) {
    throw new Error(`mainline package.json version ${mainPackage.version} does not match frozen backend ${expectedBackendVersion}`)
  }
  const apiContractDocument = fs.readFileSync(apiContractDocumentPath, 'utf8')
  for (const marker of [
    `- 应用版本：\`${expectedBackendVersion}\``,
    `- API 契约版本：\`${expectedAPIContractVersion}\``,
    `- 财务结构版本：\`${expectedFinanceSchemaVersion}\``,
    '- 当前同步模式：`legacy_state_v1`',
  ]) {
    if (!apiContractDocument.includes(marker)) {
      throw new Error(`mainline API-V2-CONTRACT.md frozen marker mismatch: ${marker}`)
    }
  }
}
const hasLocalBackend = process.env.UWAY_SKIP_LOCAL_BACKEND !== '1'
  && [serverPath, healthPath, importSchemaPath, stateSchemaPath, financeDomainPath, capabilitiesPath, financeResourcesPath, financeCutoverPath, dashboardMetricsPath, classificationReviewPath, classificationAnalysisPath, classificationPreferencesPath, apiContractDocumentPath].every(fs.existsSync)
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
  const health = fs.readFileSync(healthPath, 'utf8')
  if (!health.includes('financeSchemaVersion: FINANCE_SCHEMA_VERSION')) {
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
    "conflictControl: 'optional_if_match'",
    "versionSource: 'updatedAt'",
    "etagHeader: 'ETag'",
    "conditionalWriteHeader: 'If-Match'",
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
    "listEndpoint: '/api/v2/classification-preferences'",
    "revokeEndpoint: '/api/v2/classification-preferences/:observationId/revoke'",
    "scope: 'account_book'",
    "source: 'explicit_authenticated_human_decisions'",
    'minimumConsistentObservations: 3',
    'minimumConsistency: 0.8',
    "lifecycleStates: ['active', 'revoked', 'invalidated']",
    "effect: 'closed_candidate_reordering_only'",
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
  for (const marker of [
    "app.get('/api/live'",
    "app.get('/api/ready'",
    "app.get('/api/health'",
    "reply.header('ETag'",
    "parseIfMatch(request.headers['if-match'])",
    "code: 'STATE_VERSION_CONFLICT'",
    'details: { currentUpdatedAt:',
  ]) {
    if (!server.includes(marker)) throw new Error(`local conditional state/health marker missing: ${marker}`)
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
  const classificationReview = fs.readFileSync(classificationReviewPath, 'utf8')
  for (const marker of ["action: z.enum(['confirm', 'correct', 'reject'])", 'normalizedItemName', 'expectedRecordVersion', 'expectedClassificationVersion', 'CLASSIFICATION_VERSION_CONFLICT', 'CLASSIFICATION_REVIEW_FORBIDDEN', 'rawBusinessRecordChanged: false', 'modelCanAccept: false']) {
    if (!classificationReview.includes(marker)) throw new Error(`local classification review marker missing: ${marker}`)
  }
  const classificationAnalysis = fs.readFileSync(classificationAnalysisPath, 'utf8')
  const classificationAnalysisRoute = `${server}\n${classificationAnalysis}`
  for (const marker of ['CLASSIFICATION_AI_UNAVAILABLE', 'Idempotency-Key', 'expectedRecordVersion', 'expectedClassificationVersion', 'writesBusinessRecord: false', 'modelCanAccept: false', 'modelWritesBusinessRecords: false']) {
    if (!classificationAnalysisRoute.includes(marker)) throw new Error(`local classification analysis marker missing: ${marker}`)
  }
  const classificationPreferences = fs.readFileSync(classificationPreferencesPath, 'utf8')
  for (const marker of [
    "state: z.enum(['active', 'revoked', 'invalidated', 'all'])",
    'accountBookId: accountBookIdSchema',
    'expectedVersion: z.number().int().positive()',
    'reason: z.string().trim().min(2).max(500)',
    'CLASSIFICATION_PREFERENCE_FORBIDDEN',
    'INVALID_CLASSIFICATION_PREFERENCE_CURSOR',
    'CLASSIFICATION_PREFERENCE_VERSION_CONFLICT',
    'CLASSIFICATION_PREFERENCE_NOT_ACTIVE',
    'accountBookScoped: true',
    'recomputedFromActiveEvents: true',
    'modelCanAccept: false',
    'writesBusinessRecords: false',
  ]) {
    if (!classificationPreferences.includes(marker)) throw new Error(`local classification preference marker missing: ${marker}`)
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
