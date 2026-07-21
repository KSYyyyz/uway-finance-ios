import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const workspace = path.resolve(root, '..', '..')
const expectedMarketingVersion = '0.16.0'
const expectedBackendVersion = '0.16.0'
const expectedAPIContractVersion = '20260721_014'
const expectedFinanceSchemaVersion = '20260721_011_verified_account_email'
const expectedBuildVersion = '15'
const expectedBackendBaselineCommit = null
const expectedBackendBaselineStatus = 'frozen-candidate'
const workflowPath = path.join(root, '.github', 'workflows', 'ios-ci.yml')
const contractSnapshotPath = path.join(root, 'ContractSnapshots', 'backend-api-v0.16.0.json')

const requiredFiles = [
  'project.yml',
  'ContractSnapshots/backend-api-v0.16.0.json',
  'ContractSnapshots/backend-api-v0.15.0.json',
  'ContractSnapshots/backend-api-v0.14.1.json',
  'ContractSnapshots/backend-api-v0.14.0.json',
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
  'UwayFinance/Networking/BusinessRecordEvidenceAPI.swift',
  'UwayFinance/Models/RegistrationModels.swift',
  'UwayFinance/Models/AuthenticationModels.swift',
  'UwayFinance/Models/BackendContract.swift',
  'UwayFinance/Models/FinanceResourceModels.swift',
  'UwayFinance/Models/CutoverReadinessModels.swift',
  'UwayFinance/Models/DashboardMetricsModels.swift',
  'UwayFinance/Models/ClassificationReviewModels.swift',
  'UwayFinance/Models/ClassificationPreferenceModels.swift',
  'UwayFinance/Models/BusinessRecordEvidenceModels.swift',
  'UwayFinance/Models/RecordDeepLink.swift',
  'UwayFinance/Models/MoneyAmount.swift',
  'UwayFinance/Models/RecordImportPipeline.swift',
  'UwayFinance/State/RecordImportSession.swift',
  'UwayFinance/State/ClassificationReviewStore.swift',
  'UwayFinance/State/ClassificationPreferenceStore.swift',
  'UwayFinance/State/BusinessRecordEvidenceStore.swift',
  'UwayFinance/State/BusinessRecordEvidenceCoverageStore.swift',
  'UwayFinance/State/EvidencePreviewFileManager.swift',
  'UwayFinance/Views/RecordImportView.swift',
  'UwayFinance/Views/LedgerView.swift',
  'UwayFinance/Views/ClassificationReviewView.swift',
  'UwayFinance/Views/ClassificationPreferenceView.swift',
  'UwayFinance/Views/BusinessRecordEvidenceView.swift',
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
  'UwayFinanceTests/BusinessRecordEvidenceAPITests.swift',
  'UwayFinanceTests/BusinessRecordEvidenceStoreTests.swift',
  'UwayFinanceTests/BusinessRecordEvidenceCoverageStoreTests.swift',
  'UwayFinanceTests/RegistrationAPITests.swift',
  'UwayFinanceTests/EvidencePreviewFileManagerTests.swift',
  'UwayFinanceTests/RecordDeepLinkTests.swift',
  'UwayFinanceTests/LegacyStateConditionalWriteAPITests.swift',
  'UwayFinanceTests/RecordImportPipelineTests.swift',
  'UwayFinanceTests/ImportAnalysisAPITests.swift',
  'UwayFinanceTests/Fixtures/harness-result.json',
  'UwayFinanceTests/Fixtures/import-analysis-request.json',
  'UwayFinanceTests/Fixtures/import-analysis-request-account-book-v0.14.0.json',
  'UwayFinanceTests/Fixtures/import-decision-request-account-book-v0.14.0.json',
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
  'UwayFinanceTests/Fixtures/health-immutable-evidence-v0.13.0.json',
  'UwayFinanceTests/Fixtures/capabilities-immutable-evidence-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-list-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-coverage-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-upload-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-revoke-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-version-conflict-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-forbidden-v0.13.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-integrity-mismatch-v0.13.0.json',
  'UwayFinanceTests/Fixtures/health-semantic-preference-memory-v0.14.0.json',
  'UwayFinanceTests/Fixtures/capabilities-semantic-preference-memory-v0.14.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-list-v0.14.0.json',
  'UwayFinanceTests/Fixtures/business-record-evidence-coverage-v0.14.0.json',
  'UwayFinanceTests/Fixtures/registration-code-success-v0.14.0.json',
  'UwayFinanceTests/Fixtures/registration-success-v0.14.0.json',
  'UwayFinanceTests/Fixtures/registration-errors-v0.14.0.json',
  'UwayFinanceTests/Fixtures/health-aliyun-sms-v0.14.1.json',
  'UwayFinanceTests/Fixtures/capabilities-aliyun-sms-v0.14.1.json',
  'UwayFinanceTests/Fixtures/health-account-identity-recovery-v0.15.0.json',
  'UwayFinanceTests/Fixtures/capabilities-account-identity-recovery-v0.15.0.json',
  'UwayFinanceTests/Fixtures/username-availability-v0.15.0.json',
  'UwayFinanceTests/Fixtures/password-reset-request-v0.15.0.json',
  'UwayFinanceTests/Fixtures/password-reset-confirm-v0.15.0.json',
  'UwayFinanceTests/Fixtures/password-reset-errors-v0.15.0.json',
  'UwayFinanceTests/Fixtures/registration-errors-v0.15.0.json',
  'UwayFinanceTests/Fixtures/health-verified-account-email-v0.16.0.json',
  'UwayFinanceTests/Fixtures/capabilities-verified-account-email-v0.16.0.json',
  'UwayFinanceTests/Fixtures/registration-pending-v0.16.0.json',
  'UwayFinanceTests/Fixtures/registration-email-resend-v0.16.0.json',
  'UwayFinanceTests/Fixtures/registration-email-confirm-v0.16.0.json',
  'UwayFinanceTests/Fixtures/registration-errors-v0.16.0.json',
  'UwayFinanceTests/IdentityInputPolicyTests.swift',
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
  'import-analysis-request-account-book-v0.14.0.json',
  'import-decision-request-account-book-v0.14.0.json',
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
  'health-immutable-evidence-v0.13.0.json',
  'capabilities-immutable-evidence-v0.13.0.json',
  'business-record-evidence-list-v0.13.0.json',
  'business-record-evidence-coverage-v0.13.0.json',
  'business-record-evidence-upload-v0.13.0.json',
  'business-record-evidence-revoke-v0.13.0.json',
  'business-record-evidence-version-conflict-v0.13.0.json',
  'business-record-evidence-forbidden-v0.13.0.json',
  'business-record-evidence-integrity-mismatch-v0.13.0.json',
  'health-semantic-preference-memory-v0.14.0.json',
  'capabilities-semantic-preference-memory-v0.14.0.json',
  'business-record-evidence-list-v0.14.0.json',
  'business-record-evidence-coverage-v0.14.0.json',
  'registration-code-success-v0.14.0.json',
  'registration-success-v0.14.0.json',
  'registration-errors-v0.14.0.json',
  'health-aliyun-sms-v0.14.1.json',
  'capabilities-aliyun-sms-v0.14.1.json',
  'health-account-identity-recovery-v0.15.0.json',
  'capabilities-account-identity-recovery-v0.15.0.json',
  'username-availability-v0.15.0.json',
  'password-reset-request-v0.15.0.json',
  'password-reset-confirm-v0.15.0.json',
  'password-reset-errors-v0.15.0.json',
  'registration-errors-v0.15.0.json',
  'health-verified-account-email-v0.16.0.json',
  'capabilities-verified-account-email-v0.16.0.json',
  'registration-pending-v0.16.0.json',
  'registration-email-resend-v0.16.0.json',
  'registration-email-confirm-v0.16.0.json',
  'registration-errors-v0.16.0.json',
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
const currentImportRequest = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-analysis-request-account-book-v0.14.0.json'), 'utf8'))
const currentDecisionRequest = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-decision-request-account-book-v0.14.0.json'), 'utf8'))
if (currentImportRequest.accountBookId !== '11' || currentDecisionRequest.accountBookId !== '11') {
  throw new Error('current import and decision fixtures must carry an explicit accountBookId')
}
const historicalImportRequest = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-analysis-request.json'), 'utf8'))
if ('accountBookId' in historicalImportRequest) {
  throw new Error('historical pre-account-book import fixture must remain immutable')
}

const contractSnapshot = JSON.parse(fs.readFileSync(contractSnapshotPath, 'utf8'))
if (contractSnapshot.version !== expectedMarketingVersion) throw new Error('backend contract snapshot version mismatch')
if (contractSnapshot.backendAppVersion !== expectedBackendVersion) throw new Error('backend app version snapshot mismatch')
if (contractSnapshot.backendBaselineCommit !== expectedBackendBaselineCommit) throw new Error('backend baseline commit snapshot mismatch')
if (contractSnapshot.backendBaselineStatus !== expectedBackendBaselineStatus) throw new Error('backend baseline status snapshot mismatch')
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
    || preferenceMemorySnapshot?.writesBusinessRecords !== false
    || preferenceMemorySnapshot?.normalizationVersion !== 'semantic-preference-v2'
    || preferenceMemorySnapshot?.companyScoped !== true
    || preferenceMemorySnapshot?.learningStates?.join(',') !== 'shadow,provisional,active'
    || preferenceMemorySnapshot?.similarity !== 'complete_link_semantic'
    || preferenceMemorySnapshot?.provisionalMinimumConsistentObservations !== 2) {
  throw new Error('classification preference-memory snapshot safety boundary mismatch')
}
const registrationSnapshot = contractSnapshot.capabilities?.registration
if (registrationSnapshot?.availability !== 'runtime'
    || registrationSnapshot?.reasonWhenUnavailable !== 'sms_provider_not_configured|email_provider_not_configured|app_origin_not_configured|verification_pepper_not_configured'
    || registrationSnapshot?.codeEndpoint !== '/api/auth/registration-code'
    || registrationSnapshot?.registerEndpoint !== '/api/auth/register'
    || registrationSnapshot?.usernameAvailabilityEndpoint !== '/api/auth/username-availability'
    || registrationSnapshot?.phoneVerification !== 'aliyun_sms'
    || registrationSnapshot?.emailRequired !== true
    || registrationSnapshot?.emailVerificationRequired !== true
    || registrationSnapshot?.emailVerification?.purpose !== 'registration_verification'
    || registrationSnapshot?.emailVerification?.strategy !== 'email_link'
    || registrationSnapshot?.emailVerification?.confirmEndpoint !== '/api/auth/registration-email/confirm'
    || registrationSnapshot?.emailVerification?.resendEndpoint !== '/api/auth/registration-email/resend'
    || registrationSnapshot?.emailVerification?.delivery !== 'aliyun_direct_mail'
    || registrationSnapshot?.emailVerification?.tokenStorage !== 'hmac_sha256_digest_only'
    || registrationSnapshot?.emailVerification?.tokenTransport !== 'url_fragment_then_post_body'
    || registrationSnapshot?.emailVerification?.activation !== 'after_email_confirmation'
    || registrationSnapshot?.emailVerification?.pendingTenantCreated !== false
    || registrationSnapshot?.emailVerification?.unknownPendingResponse !== 'indistinguishable'
    || registrationSnapshot?.usernameNormalization !== 'nfkc_lowercase'
    || registrationSnapshot?.usernameLength?.min !== 3
    || registrationSnapshot?.usernameLength?.max !== 32
    || registrationSnapshot?.passwordLength?.min !== 8
    || registrationSnapshot?.passwordLength?.max !== 256
    || registrationSnapshot?.createsIsolatedOrganizationAndAccountBookAfterEmailConfirmation !== true
    || registrationSnapshot?.sessionCookie !== 'http_only_secure_same_site_strict') {
  throw new Error('registration snapshot must preserve pending email-link activation and tenant-isolation boundaries')
}
const authenticationSnapshot = contractSnapshot.capabilities?.authentication
if (authenticationSnapshot?.loginEndpoint !== '/api/auth/login'
    || authenticationSnapshot?.acceptedIdentifiers?.join(',') !== 'username,phone,email'
    || authenticationSnapshot?.identifierField !== 'identifier'
    || authenticationSnapshot?.legacyUsernameFieldAccepted !== true
    || authenticationSnapshot?.invalidCredentialsMessage !== '账号或密码错误'
    || authenticationSnapshot?.sessionRevokedOnPasswordReset !== true) {
  throw new Error('authentication snapshot must preserve identifier privacy and reset revocation')
}
const passwordRecoverySnapshot = contractSnapshot.capabilities?.passwordRecovery
if (passwordRecoverySnapshot?.availability !== 'runtime'
    || passwordRecoverySnapshot?.reasonWhenUnavailable !== 'email_provider_not_configured'
    || passwordRecoverySnapshot?.requestEndpoint !== '/api/auth/password-reset/request'
    || passwordRecoverySnapshot?.confirmEndpoint !== '/api/auth/password-reset/confirm'
    || passwordRecoverySnapshot?.delivery !== 'aliyun_direct_mail'
    || passwordRecoverySnapshot?.codeStorage !== 'hmac_sha256_digest_only'
    || passwordRecoverySnapshot?.unknownEmailResponse !== 'indistinguishable'
    || passwordRecoverySnapshot?.sessionRevocation !== 'all_sessions') {
  throw new Error('password recovery snapshot must preserve enumeration resistance and session revocation')
}
const evidenceSnapshot = contractSnapshot.capabilities?.documentUpload
if (evidenceSnapshot?.available !== true
    || evidenceSnapshot?.listEndpoint !== '/api/v2/business-record-evidence'
    || evidenceSnapshot?.coverageEndpoint !== '/api/v2/business-record-evidence-coverage'
    || evidenceSnapshot?.uploadEndpoint !== '/api/v2/business-record-evidence'
    || evidenceSnapshot?.contentEndpoint !== '/api/v2/business-record-evidence/:evidenceId/content'
    || evidenceSnapshot?.revokeEndpoint !== '/api/v2/business-record-evidence/:evidenceId/revoke'
    || evidenceSnapshot?.acceptedMediaTypes?.join(',') !== 'image/jpeg,image/png,image/webp,image/heic,image/heif,application/pdf'
    || evidenceSnapshot?.maxBytes !== 10000000
    || evidenceSnapshot?.contentImmutability !== 'database_trigger_and_sha256'
    || evidenceSnapshot?.lifecycle?.join(',') !== 'active,revoked'
    || evidenceSnapshot?.deletion !== false
    || evidenceSnapshot?.accountBookScoped !== true
    || evidenceSnapshot?.idempotencyHeader !== 'Idempotency-Key') {
  throw new Error('immutable evidence snapshot capability boundary mismatch')
}
if (contractSnapshot.capabilities?.importAnalysis?.availability !== 'runtime'
    || contractSnapshot.capabilities?.importAnalysis?.reasonWhenUnavailable !== 'provider_not_configured'
    || contractSnapshot.capabilities?.importAnalysis?.analysisEndpoint !== '/api/import-analysis'
    || contractSnapshot.capabilities?.importAnalysis?.decisionEndpoint !== '/api/import-analysis/:analysisId/decision'
    || contractSnapshot.capabilities?.importAnalysis?.scope !== 'account_book'
    || contractSnapshot.capabilities?.importAnalysis?.sharedWithinAccountBook !== true
    || contractSnapshot.capabilities?.importAnalysis?.idempotencyKey !== 'analysisId'
    || contractSnapshot.capabilities?.importAnalysis?.idempotencyReplayHeader !== 'Idempotency-Replayed') {
  throw new Error('import-analysis capability must remain runtime-negotiated and account-book scoped')
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

const capabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-verified-account-email-v0.16.0.json'), 'utf8'))
const healthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-verified-account-email-v0.16.0.json'), 'utf8'))
if (healthFixture.version !== expectedBackendVersion
    || healthFixture.financeSchemaVersion !== expectedFinanceSchemaVersion) {
  throw new Error('semantic preference-memory v2 health fixture version/schema mismatch')
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
    || capabilitiesFixture.features?.importAnalysis?.reason !== null
    || capabilitiesFixture.features?.importAnalysis?.analysisEndpoint !== '/api/import-analysis'
    || capabilitiesFixture.features?.importAnalysis?.decisionEndpoint !== '/api/import-analysis/:analysisId/decision'
    || capabilitiesFixture.features?.importAnalysis?.scope !== 'account_book'
    || capabilitiesFixture.features?.importAnalysis?.sharedWithinAccountBook !== true
    || capabilitiesFixture.features?.importAnalysis?.idempotencyKey !== 'analysisId'
    || capabilitiesFixture.features?.importAnalysis?.idempotencyReplayHeader !== 'Idempotency-Replayed') {
  throw new Error('configured import-analysis fixture must report the frozen account-book contract')
}
const disabledCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-v0.9.0-import-disabled.json'), 'utf8'))
if (disabledCapabilitiesFixture.features?.importAnalysis?.available !== false
    || disabledCapabilitiesFixture.features?.importAnalysis?.reason !== 'provider_not_configured') {
  throw new Error('unconfigured import-analysis fixture must expose provider_not_configured')
}
const registrationCapability = capabilitiesFixture.features?.registration
if (registrationCapability?.available !== true
    || registrationCapability?.reason !== null
    || registrationCapability?.codeEndpoint !== '/api/auth/registration-code'
    || registrationCapability?.registerEndpoint !== '/api/auth/register'
    || registrationCapability?.usernameAvailabilityEndpoint !== '/api/auth/username-availability'
    || registrationCapability?.phoneVerification !== 'aliyun_sms'
    || registrationCapability?.emailRequired !== true
    || registrationCapability?.emailVerificationRequired !== true
    || registrationCapability?.emailVerification?.purpose !== 'registration_verification'
    || registrationCapability?.emailVerification?.strategy !== 'email_link'
    || registrationCapability?.emailVerification?.confirmEndpoint !== '/api/auth/registration-email/confirm'
    || registrationCapability?.emailVerification?.resendEndpoint !== '/api/auth/registration-email/resend'
    || registrationCapability?.emailVerification?.delivery !== 'aliyun_direct_mail'
    || registrationCapability?.emailVerification?.tokenStorage !== 'hmac_sha256_digest_only'
    || registrationCapability?.emailVerification?.tokenTransport !== 'url_fragment_then_post_body'
    || registrationCapability?.emailVerification?.activation !== 'after_email_confirmation'
    || registrationCapability?.emailVerification?.pendingTenantCreated !== false
    || registrationCapability?.emailVerification?.unknownPendingResponse !== 'indistinguishable'
    || registrationCapability?.usernameNormalization !== 'nfkc_lowercase'
    || registrationCapability?.usernameLength?.min !== 3
    || registrationCapability?.usernameLength?.max !== 32
    || registrationCapability?.passwordLength?.min !== 8
    || registrationCapability?.passwordLength?.max !== 256
    || registrationCapability?.createsIsolatedOrganizationAndAccountBookAfterEmailConfirmation !== true
    || registrationCapability?.sessionCookie !== 'http_only_secure_same_site_strict') {
  throw new Error('current registration capability fixture is unsafe or incomplete')
}
const authenticationCapability = capabilitiesFixture.features?.authentication
if (authenticationCapability?.loginEndpoint !== '/api/auth/login'
    || authenticationCapability?.acceptedIdentifiers?.join(',') !== 'username,phone,email'
    || authenticationCapability?.identifierField !== 'identifier'
    || authenticationCapability?.legacyUsernameFieldAccepted !== true
    || authenticationCapability?.invalidCredentialsMessage !== '账号或密码错误'
    || authenticationCapability?.sessionRevokedOnPasswordReset !== true) {
  throw new Error('current authentication capability fixture is unsafe or incomplete')
}
const passwordRecoveryCapability = capabilitiesFixture.features?.passwordRecovery
if (passwordRecoveryCapability?.available !== true
    || passwordRecoveryCapability?.reason !== null
    || passwordRecoveryCapability?.requestEndpoint !== '/api/auth/password-reset/request'
    || passwordRecoveryCapability?.confirmEndpoint !== '/api/auth/password-reset/confirm'
    || passwordRecoveryCapability?.delivery !== 'aliyun_direct_mail'
    || passwordRecoveryCapability?.codeStorage !== 'hmac_sha256_digest_only'
    || passwordRecoveryCapability?.unknownEmailResponse !== 'indistinguishable'
    || passwordRecoveryCapability?.sessionRevocation !== 'all_sessions') {
  throw new Error('current password recovery capability fixture is unsafe or incomplete')
}
if (capabilitiesFixture.sync?.financeResources?.available !== true
    || capabilitiesFixture.sync?.financeResources?.cutoverState !== 'shadow'
    || capabilitiesFixture.sync?.financeResources?.cutoverReadiness?.clientWritesEnabled !== false
    || capabilitiesFixture.sync?.financeResources?.businessRecords?.moneyEncoding !== 'decimal_string') {
  throw new Error('current 0.16.0 capabilities fixture must preserve read-only readiness and the shadow resource slice')
}
const historicalV0141CapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-aliyun-sms-v0.14.1.json'), 'utf8'))
const historicalV0141HealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-aliyun-sms-v0.14.1.json'), 'utf8'))
if (historicalV0141HealthFixture.version !== '0.14.1'
    || historicalV0141HealthFixture.financeSchemaVersion !== '20260716_009_immutable_evidence_links'
    || historicalV0141CapabilitiesFixture.version !== '0.14.1'
    || historicalV0141CapabilitiesFixture.apiContractVersion !== '20260720_012'
    || 'authentication' in historicalV0141CapabilitiesFixture.features
    || 'passwordRecovery' in historicalV0141CapabilitiesFixture.features) {
  throw new Error('historical 0.14.1 authentication fixtures must remain unchanged')
}
const historicalV0140CapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-semantic-preference-memory-v0.14.0.json'), 'utf8'))
const historicalV0140HealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-semantic-preference-memory-v0.14.0.json'), 'utf8'))
if (historicalV0140HealthFixture.version !== '0.14.0'
    || historicalV0140HealthFixture.financeSchemaVersion !== '20260716_009_immutable_evidence_links'
    || historicalV0140CapabilitiesFixture.version !== '0.14.0'
    || historicalV0140CapabilitiesFixture.apiContractVersion !== '20260715_011'
    || historicalV0140CapabilitiesFixture.features?.registration?.phoneVerification !== 'sms_webhook') {
  throw new Error('historical 0.14.0 SMS webhook compatibility fixtures must remain unchanged')
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
for (const feature of ['workflowTasks', 'ocr']) {
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
const historicalPreferenceHealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-preference-memory-v0.12.0.json'), 'utf8'))
const historicalPreferenceCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-preference-memory-v0.12.0.json'), 'utf8'))
if (historicalPreferenceHealthFixture.version !== '0.12.0'
    || historicalPreferenceCapabilitiesFixture.version !== '0.12.0'
    || historicalPreferenceCapabilitiesFixture.apiContractVersion !== '20260715_008'
    || historicalPreferenceCapabilitiesFixture.financeSchemaVersion !== '20260715_004_account_book_preference_memory'
    || historicalPreferenceCapabilitiesFixture.features?.documentUpload?.available !== false
    || 'listEndpoint' in (historicalPreferenceCapabilitiesFixture.features?.documentUpload ?? {})) {
  throw new Error('dedicated 0.12.0 backward-compat fixtures must remain historical and omit evidence endpoints')
}
const historicalEvidenceHealthFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'health-immutable-evidence-v0.13.0.json'), 'utf8'))
const historicalEvidenceCapabilitiesFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'capabilities-immutable-evidence-v0.13.0.json'), 'utf8'))
if (historicalEvidenceHealthFixture.version !== '0.13.0'
    || historicalEvidenceCapabilitiesFixture.version !== '0.13.0'
    || historicalEvidenceCapabilitiesFixture.apiContractVersion !== '20260715_009'
    || historicalEvidenceCapabilitiesFixture.financeSchemaVersion !== '20260715_005_immutable_record_evidence'
    || 'learningState' in (historicalEvidenceCapabilitiesFixture.features?.classificationPreferenceMemory ?? {})) {
  throw new Error('dedicated 0.13.0 backward-compat fixtures must remain historical and omit semantic learning state')
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
    || preferenceCapability?.writesBusinessRecords !== false
    || preferenceCapability?.normalizationVersion !== 'semantic-preference-v2'
    || preferenceCapability?.companyScoped !== true
    || preferenceCapability?.learningStates?.join(',') !== 'shadow,provisional,active'
    || preferenceCapability?.similarity !== 'complete_link_semantic'
    || preferenceCapability?.provisionalMinimumConsistentObservations !== 2) {
  throw new Error('classification preference-memory capability fixture is unsafe or incomplete')
}
const registrationCodeFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-code-success-v0.14.0.json'), 'utf8'))
const registrationSuccessFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-success-v0.14.0.json'), 'utf8'))
const pendingRegistrationFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-pending-v0.16.0.json'), 'utf8'))
const registrationEmailResendFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-email-resend-v0.16.0.json'), 'utf8'))
const registrationEmailConfirmFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-email-confirm-v0.16.0.json'), 'utf8'))
const registrationErrorFixtures = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-errors-v0.16.0.json'), 'utf8'))
const expectedRegistrationErrors = [
  [400, 'INVALID_PHONE'],
  [400, 'INVALID_EMAIL'],
  [400, 'INVALID_REGISTRATION_INPUT'],
  [400, 'WEAK_PASSWORD'],
  [400, 'INVALID_REGISTRATION_CODE'],
  [400, 'INVALID_REGISTRATION_EMAIL_TOKEN'],
  [429, 'REGISTRATION_CODE_RATE_LIMITED'],
  [429, 'REGISTRATION_EMAIL_RESEND_RATE_LIMITED'],
  [429, 'REGISTRATION_EMAIL_CONFIRM_RATE_LIMITED'],
  [429, 'REGISTRATION_EMAIL_LINK_RATE_LIMITED'],
  [409, 'REGISTRATION_IDENTITY_CONFLICT'],
  [503, 'SMS_PROVIDER_UNAVAILABLE'],
  [503, 'SMS_DELIVERY_FAILED'],
  [503, 'EMAIL_VERIFICATION_UNAVAILABLE'],
]
if (registrationCodeFixture.ok !== true
    || registrationCodeFixture.expiresInSeconds !== 300
    || registrationCodeFixture.resendAfterSeconds !== 60
    || !registrationCodeFixture.challengeId
    || pendingRegistrationFixture.ok !== true
    || !pendingRegistrationFixture.pendingRegistrationId
    || pendingRegistrationFixture.expiresInSeconds !== 900
    || pendingRegistrationFixture.resendAfterSeconds !== 60
    || 'user' in pendingRegistrationFixture
    || 'organizationId' in pendingRegistrationFixture
    || 'accountBookId' in pendingRegistrationFixture
    || registrationEmailResendFixture.pendingRegistrationId !== pendingRegistrationFixture.pendingRegistrationId
    || registrationEmailResendFixture.expiresInSeconds !== 900
    || registrationEmailResendFixture.resendAfterSeconds !== 60
    || !registrationEmailConfirmFixture.user?.id
    || !registrationEmailConfirmFixture.organizationId
    || !registrationEmailConfirmFixture.accountBookId
    || !registrationSuccessFixture.user?.id
    || !registrationSuccessFixture.organizationId
    || !registrationSuccessFixture.accountBookId
    || JSON.stringify(registrationErrorFixtures.map(({ status, code }) => [status, code])) !== JSON.stringify(expectedRegistrationErrors)) {
  throw new Error('pending registration, email-link activation or error fixtures do not match the frozen contract')
}
const historicalRegistrationErrors = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-errors-v0.14.0.json'), 'utf8'))
const historicalV015RegistrationErrors = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'registration-errors-v0.15.0.json'), 'utf8'))
if (historicalRegistrationErrors.find(({ code }) => code === 'REGISTRATION_IDENTITY_CONFLICT')?.error !== '用户名或手机号已被使用'
    || historicalV015RegistrationErrors.length !== 8
    || historicalV015RegistrationErrors.some(({ code }) => code.includes('EMAIL_CODE') || code === 'EMAIL_VERIFICATION_UNAVAILABLE')
    || registrationErrorFixtures.find(({ code }) => code === 'REGISTRATION_IDENTITY_CONFLICT')?.error !== '用户名、手机号或邮箱已被使用') {
  throw new Error('registration fixtures must preserve v0.14/v0.15 history and v0.16 pending email-link semantics')
}
const usernameAvailabilityFixtures = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'username-availability-v0.15.0.json'), 'utf8'))
if (usernameAvailabilityFixtures.map(({ reason }) => reason).filter(Boolean).sort().join(',') !== 'format,length,numeric_only,reserved,unavailable'
    || !usernameAvailabilityFixtures.some(({ available, reason }) => available === true && reason === null)) {
  throw new Error('username availability fixtures must cover the frozen UX reasons and available result')
}
const passwordResetRequestFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'password-reset-request-v0.15.0.json'), 'utf8'))
const passwordResetConfirmFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'password-reset-confirm-v0.15.0.json'), 'utf8'))
const passwordResetErrorFixtures = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'password-reset-errors-v0.15.0.json'), 'utf8'))
const expectedPasswordResetErrors = [
  [400, 'INVALID_EMAIL'],
  [400, 'INVALID_PASSWORD_RESET_INPUT'],
  [400, 'INVALID_PASSWORD_RESET_CODE'],
  [400, 'WEAK_PASSWORD'],
  [429, 'PASSWORD_RESET_REQUEST_RATE_LIMITED'],
  [503, 'EMAIL_RESET_UNAVAILABLE'],
]
if (passwordResetRequestFixture.ok !== true
    || !passwordResetRequestFixture.challengeId
    || passwordResetRequestFixture.expiresInSeconds !== 600
    || passwordResetRequestFixture.resendAfterSeconds !== 60
    || 'email' in passwordResetRequestFixture
    || passwordResetConfirmFixture.ok !== true
    || JSON.stringify(passwordResetErrorFixtures.map(({ status, code }) => [status, code])) !== JSON.stringify(expectedPasswordResetErrors)) {
  throw new Error('password recovery fixtures must preserve indistinguishable request and frozen error behavior')
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
const evidenceCapability = capabilitiesFixture.features?.documentUpload
if (evidenceCapability?.available !== true
    || evidenceCapability?.listEndpoint !== '/api/v2/business-record-evidence'
    || evidenceCapability?.coverageEndpoint !== '/api/v2/business-record-evidence-coverage'
    || evidenceCapability?.uploadEndpoint !== '/api/v2/business-record-evidence'
    || evidenceCapability?.contentEndpoint !== '/api/v2/business-record-evidence/:evidenceId/content'
    || evidenceCapability?.revokeEndpoint !== '/api/v2/business-record-evidence/:evidenceId/revoke'
    || evidenceCapability?.acceptedMediaTypes?.join(',') !== 'image/jpeg,image/png,image/webp,image/heic,image/heif,application/pdf'
    || evidenceCapability?.maxBytes !== 10000000
    || evidenceCapability?.contentImmutability !== 'database_trigger_and_sha256'
    || evidenceCapability?.lifecycle?.join(',') !== 'active,revoked'
    || evidenceCapability?.deletion !== false
    || evidenceCapability?.accountBookScoped !== true
    || evidenceCapability?.idempotencyHeader !== 'Idempotency-Key') {
  throw new Error('immutable evidence capability fixture is unsafe or incomplete')
}
const evidenceListFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-list-v0.13.0.json'), 'utf8'))
const evidenceCoverageFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-coverage-v0.13.0.json'), 'utf8'))
const evidenceUploadFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-upload-v0.13.0.json'), 'utf8'))
const evidenceRevokeFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-revoke-v0.13.0.json'), 'utf8'))
if (evidenceListFixture.items?.[0]?.status !== 'active'
    || evidenceListFixture.items?.[1]?.status !== 'revoked'
    || evidenceListFixture.items?.some((item) => item.recordExternalId !== 'R-EVIDENCE')
    || evidenceListFixture.items?.some((item) => typeof item.sha256 !== 'string' || item.sha256.length !== 64)
    || evidenceCoverageFixture.records?.['R-EVIDENCE']?.activeEvidenceCount !== 1
    || evidenceUploadFixture.fixed !== true
    || evidenceUploadFixture.contentImmutable !== true
    || evidenceRevokeFixture.contentDeleted !== false
    || evidenceRevokeFixture.contentImmutable !== true
    || evidenceRevokeFixture.evidence?.status !== 'revoked') {
  throw new Error('evidence fixtures must preserve scope, immutable content and active/revoked lifecycle')
}
const currentEvidenceListFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-list-v0.14.0.json'), 'utf8'))
const currentEvidenceCoverageFixture = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'business-record-evidence-coverage-v0.14.0.json'), 'utf8'))
const currentEvidence = currentEvidenceCoverageFixture.records?.['R-EVIDENCE']
if (currentEvidenceListFixture.items?.filter((item) => item.status === 'active').length !== currentEvidence?.activeEvidenceCount
    || currentEvidence?.activeImageCount !== 1
    || currentEvidence?.invoiceEvidenceCount !== 1
    || currentEvidence?.paymentEvidenceCount !== 0
    || currentEvidence?.contractEvidenceCount !== 1
    || currentEvidence?.requirementState !== 'satisfied'
    || currentEvidence?.missingRequiredTypes?.length !== 0
    || currentEvidenceCoverageFixture.records?.['R-MISSING']?.requirementState !== 'required_missing'
    || currentEvidenceCoverageFixture.records?.['R-MISSING']?.missingRequiredTypes?.join(',') !== 'invoice,supporting_document'
    || currentEvidenceCoverageFixture.records?.['R-NOT-REQUIRED']?.requirementState !== 'not_required'
    || currentEvidenceCoverageFixture.records?.['R-REVOKED-ONLY']?.activeEvidenceCount !== 0
    || currentEvidenceListFixture.items?.some((item) => typeof item.sha256 !== 'string' || item.sha256.length !== 64)) {
  throw new Error('v0.14 evidence coverage must count active items only and preserve requirement semantics')
}
for (const [name, code] of [
  ['business-record-evidence-version-conflict-v0.13.0.json', 'EVIDENCE_VERSION_CONFLICT'],
  ['business-record-evidence-forbidden-v0.13.0.json', 'EVIDENCE_WRITE_FORBIDDEN'],
  ['business-record-evidence-integrity-mismatch-v0.13.0.json', 'EVIDENCE_INTEGRITY_MISMATCH'],
]) {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', name), 'utf8'))
  if (value.code !== code) throw new Error(`evidence error fixture mismatch: ${name}`)
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
if (!project.includes(`CURRENT_PROJECT_VERSION: ${expectedBuildVersion}`)) {
  throw new Error(`project CURRENT_PROJECT_VERSION must be ${expectedBuildVersion}`)
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
for (const marker of ['Bundle.main', 'CFBundleShortVersionString', 'value: appVersion', 'contract.capabilities.importAnalysis.statusDisplay', 'classificationPreferenceMemory?.statusDisplay', 'documentUploadCapability.statusDisplay']) {
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
for (const marker of ['.fileImporter(', 'confirmPendingOwnership()', 'importSession.analyze', 'importSession.commit', 'importAnalysisCapability.safeForAccountBookUse', 'unavailableMessage']) {
  if (!importView.includes(marker)) throw new Error(`native import flow marker missing: ${marker}`)
}
const importSession = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'RecordImportSession.swift'), 'utf8')
for (const marker of ['session.importAnalysisCapability', 'guard capability.safeForAccountBookUse else', 'accountBookContext()', 'pendingRequests', 'scopedAccountBookID', 'capability.unavailableMessage']) {
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
for (const marker of [expectedAPIContractVersion, expectedFinanceSchemaVersion, 'legacy_state_v1', 'versionSource', 'etagHeader', 'conditionalWriteHeader', 'cutoverState', 'cutoverReadiness', 'clientWritesEnabled', 'UnifiedDashboardMetricsCapability', 'ClassificationReviewCapability', 'ClassificationPreferenceMemoryCapability', 'ClassificationPreferenceLearningState', 'learningStates', 'semantic-preference-v2', 'complete_link_semantic', 'RegistrationCapability', 'RegistrationEmailVerificationCapability', 'safeForEmailLinkRegistration', 'AuthenticationCapability', 'PasswordRecoveryCapability', 'supportsIdentityContract', 'safeForIdentifierLogin', 'sms_webhook', 'aliyun_sms', 'aliyun_direct_mail', 'registration_verification', 'email_link', 'url_fragment_then_post_body', 'after_email_confirmation', 'pendingTenantCreated', 'nfkc_lowercase', 'indistinguishable', 'all_sessions', 'http_only_secure_same_site_strict', 'DocumentUploadCapability', 'database_trigger_and_sha256', 'accountBookScoped', 'closed_candidate_reordering_only', 'explicit_authenticated_human_decisions', 'deterministicGroupingAvailable', 'modelCanAccept', 'writesBusinessRecords', 'businessRecords', 'safeForAccountBookUse', 'sharedWithinAccountBook', 'idempotencyReplayHeader', '"accepted", "review", "rejected"']) {
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
const evidenceModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'BusinessRecordEvidenceModels.swift'), 'utf8')
for (const marker of ['BusinessRecordEvidenceType', 'payment_proof', 'BusinessRecordEvidenceStatus', 'case active', 'case revoked', 'sha256', 'activeImageCount', 'contractEvidenceCount', 'required_missing', 'not_required', 'supporting_document', 'BusinessRecordEvidenceUploadCommand', 'BusinessRecordEvidenceRevokeCommand', 'expectedVersion', 'IdempotencyKey']) {
  if (!evidenceModels.includes(marker)) throw new Error(`business record evidence model marker missing: ${marker}`)
}
const evidenceAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'BusinessRecordEvidenceAPI.swift'), 'utf8')
for (const marker of ['protocol BusinessRecordEvidenceAPI', 'multipart/form-data', 'EvidenceMultipartEncoder', 'accountBookId', 'recordExternalId', 'evidenceType', 'Idempotency-Key', 'SHA256.hash', 'EVIDENCE_INTEGRITY_MISMATCH']) {
  if (!evidenceAPI.includes(marker)) throw new Error(`business record evidence API marker missing: ${marker}`)
}
const evidenceStore = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'BusinessRecordEvidenceStore.swift'), 'utf8')
for (const marker of ['api.context', 'pendingUpload', 'pendingRevokes', 'EVIDENCE_VERSION_CONFLICT', '同一幂等请求', 'clearScopedState', 'coverageLoadState', '不能判断材料是否齐全', 'contentDeleted == false', 'contentImmutable']) {
  if (!evidenceStore.includes(marker)) throw new Error(`business record evidence isolation/retry marker missing: ${marker}`)
}
const evidenceView = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'BusinessRecordEvidenceView.swift'), 'utf8')
for (const marker of ['PhotosPicker', '.fileImporter(', '.quickLookPreview(', 'autoPreviewFirstSupported', 'supportsAutomaticPreview', '上传时间', '上传者', 'SHA-256', '无需补充材料', '票据与附件', '标记作废', '存在附件不代表自动记账', 'appScrollIndicatorsHidden']) {
  if (!evidenceView.includes(marker)) throw new Error(`business record evidence native UI marker missing: ${marker}`)
}
const evidenceCoverageStore = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'BusinessRecordEvidenceCoverageStore.swift'), 'utf8')
for (const marker of ['api.coverage(accountBookId: incomingBook.id)', 'records = [:]', 'userScopeID', 'loadGeneration', 'case failed']) {
  if (!evidenceCoverageStore.includes(marker)) throw new Error(`account-book evidence coverage cache marker missing: ${marker}`)
}
const httpTransport = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'HTTPTransport.swift'), 'utf8')
for (const marker of ['case versionConflict', 'case stateVersionConflict', 'STATE_VERSION_CONFLICT', 'currentUpdatedAt', 'headers: [String: String]']) {
  if (!httpTransport.includes(marker)) throw new Error(`V2 transport marker missing: ${marker}`)
}
const financeAPI = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'FinanceAPI.swift'), 'utf8')
for (const marker of ['login(identifier:', 'useLegacyUsernameField', 'usernameAvailability', 'requestRegistrationCode', 'register(_ request: RegistrationRequest)', 'resendRegistrationEmail', 'confirmRegistrationEmail', 'RegistrationEmailConfirmRequest', 'requestPasswordReset', 'confirmPasswordReset', 'serializedAuthenticationRequest', 'ifMatch revision: StateRevision', 'headers: ["If-Match": revision.ifMatchHeaderValue]', 'StateRevision(updatedAt: updatedAt)']) {
  if (!financeAPI.includes(marker)) throw new Error(`legacy state conditional-write API marker missing: ${marker}`)
}
if (financeAPI.includes('ISO8601DateFormatter().string(from: Date())')) {
  throw new Error('conditional state revision must never be invented client-side')
}
const appSession = fs.readFileSync(path.join(root, 'UwayFinance', 'State', 'AppSession.swift'), 'utf8')
if (appSession.includes('FinanceResourceAPI') || appSession.includes('CutoverReadinessAPI') || appSession.includes('DashboardMetricsAPI') || appSession.includes('ClassificationReviewAPI') || appSession.includes('ClassificationPreferenceAPI') || appSession.includes('BusinessRecordEvidenceAPI') || appSession.includes('/api/v2')) {
  throw new Error('shadow V2 clients must not become the AppSession data source')
}
for (const marker of ['stateRevision', 'unsavedSnapshot', 'conflictingServerRevision', 'catch APIError.stateVersionConflict', 'resolveStateConflictAndRetry', '其他设备已更新，需要核对']) {
  if (!appSession.includes(marker)) throw new Error(`AppSession conflict preservation marker missing: ${marker}`)
}
for (const marker of ['sessionGeneration', 'sessionScopeID', 'onSessionScopeCleared', 'registrationCapability', 'authenticationCapability', 'passwordRecoveryCapability', 'requestRegistrationCode', 'resendRegistrationEmail', 'confirmRegistrationEmail', 'checkUsernameAvailability', 'requestPasswordReset', 'confirmPasswordReset', 'beginSessionTransition']) {
  if (!appSession.includes(marker)) throw new Error(`AppSession account-isolation marker missing: ${marker}`)
}
const loginView = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'LoginView.swift'), 'utf8')
for (const marker of ['用户名、手机号或邮箱', 'requestRegistrationCode', 'pendingRegistration', 'resendRegistrationEmail', 'RegistrationEmailLink.token(from:', '.onOpenURL', 'session.confirmRegistrationEmail(token:', '一次性确认链接', '点击链接前不会创建用户、企业、账套或登录会话', 'session.register', 'debounceUsernameCheck', 'IdentityInputPolicy', 'session.checkUsernameAvailability', 'session.requestPasswordReset', 'session.confirmPasswordReset', 'PasswordEntry', 'controlsConfirmationVisibility: true', 'showsVisibilityToggle: false', 'TimelineView', 'expiresInSeconds', 'resendAfterSeconds', 'textContentType(.oneTimeCode)', 'contentType: .newPassword', 'RegistrationErrorMessage.localized', 'AuthenticationErrorMessage.localized']) {
  if (!loginView.includes(marker)) throw new Error(`registration UI marker missing: ${marker}`)
}
for (const forbidden of ['UserDefaults', 'Keychain', 'URLQueryItem(name: "password"', 'URLQueryItem(name: "code"']) {
  if (loginView.includes(forbidden)) throw new Error(`registration secret persistence/URL marker forbidden: ${forbidden}`)
}
for (const forbidden of ['requestRegistrationEmailCode', 'registrationEmailChallenge', 'emailChallengeId', 'emailCode']) {
  if (loginView.includes(forbidden) || financeAPI.includes(forbidden) || appSession.includes(forbidden)) {
    throw new Error('obsolete registration email-code marker forbidden: ' + forbidden)
  }
}
const authenticationModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'AuthenticationModels.swift'), 'utf8')
for (const marker of ['UsernameAvailabilityRequest', 'PasswordResetChallengeResponse', 'PasswordResetConfirmRequest', 'precomposedStringWithCompatibilityMapping', 'reservedUsernames', 'numeric_only', '8...256', 'INVALID_CREDENTIALS', 'EMAIL_RESET_UNAVAILABLE']) {
  if (!authenticationModels.includes(marker)) throw new Error(`identity/authentication model marker missing: ${marker}`)
}
for (const file of listSwiftFiles(path.join(root, 'UwayFinance'))) {
  const source = fs.readFileSync(file, 'utf8')
  for (const forbiddenLogging of [/\bprint\s*\(/, /\bdebugPrint\s*\(/, /\bNSLog\s*\(/, /\bos_log\s*\(/, /\bLogger\s*\(/]) {
    if (forbiddenLogging.test(source)) {
      throw new Error(`application source must not log registration codes, passwords or provider secrets: ${path.relative(root, file)}`)
    }
  }
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
const businessRecordEvidencePath = path.join(workspace, 'server', 'business-record-evidence.ts')
const registrationPath = path.join(workspace, 'server', 'registration.ts')
const authenticationPath = path.join(workspace, 'server', 'authentication.ts')
const identityPath = path.join(workspace, 'server', 'identity.ts')
const passwordRecoveryPath = path.join(workspace, 'server', 'password-recovery.ts')
const emailPath = path.join(workspace, 'server', 'email.ts')
const databasePath = path.join(workspace, 'server', 'database.ts')
const apiContractDocumentPath = path.join(workspace, 'API-V2-CONTRACT.md')
const mainPackagePath = path.join(workspace, 'package.json')
const hasMainPackage = fs.existsSync(mainPackagePath)
const hasMainContractDocument = fs.existsSync(apiContractDocumentPath)
const validateMainline = process.env.UWAY_STANDALONE_CONTRACT !== '1'
if (validateMainline && hasMainPackage !== hasMainContractDocument) {
  throw new Error('mainline package.json and API-V2-CONTRACT.md must be validated together')
}
if (validateMainline && hasMainPackage && hasMainContractDocument) {
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
const hasLocalBackend = validateMainline && process.env.UWAY_SKIP_LOCAL_BACKEND !== '1'
  && [serverPath, healthPath, importSchemaPath, stateSchemaPath, financeDomainPath, capabilitiesPath, financeResourcesPath, financeCutoverPath, dashboardMetricsPath, classificationReviewPath, classificationAnalysisPath, classificationPreferencesPath, businessRecordEvidencePath, registrationPath, authenticationPath, identityPath, passwordRecoveryPath, emailPath, databasePath, apiContractDocumentPath].every(fs.existsSync)
if (hasLocalBackend) {
  const server = fs.readFileSync(serverPath, 'utf8')
  for (const { method, path: endpoint } of currentContracts) {
    if (!server.includes(`app.${method}('${endpoint}'`)) throw new Error(`local server endpoint missing: ${method.toUpperCase()} ${endpoint}`)
  }
  const importSchema = fs.readFileSync(importSchemaPath, 'utf8')
  for (const field of contractSnapshot.importRequestFields) {
    if (!importSchema.includes(field)) throw new Error(`local import schema mismatch: ${field}`)
  }
  for (const marker of [
    'accountBookId: z.string().regex',
    'export const importAnalysisDecisionSchema',
  ]) {
    if (!importSchema.includes(marker)) throw new Error(`local import account-book schema marker missing: ${marker}`)
  }
  const stateSchema = fs.readFileSync(stateSchemaPath, 'utf8')
  for (const field of contractSnapshot.ledgerProvenanceFields) {
    if (!stateSchema.includes(field)) throw new Error(`local state schema mismatch: ${field}`)
  }
  const financeDomain = fs.readFileSync(financeDomainPath, 'utf8')
  if (!financeDomain.includes(`FINANCE_SCHEMA_VERSION = '${expectedFinanceSchemaVersion}'`)) {
    throw new Error('local finance domain schema version mismatch')
  }
  for (const marker of [
    'BUSINESS_RECORD_DOCUMENT_SCOPE_MISMATCH',
    'BUSINESS_RECORD_EVIDENCE_ORPHANED',
    'enforce_business_record_document_scope',
    'BUSINESS_RECORD_EVIDENCE_LINK_IMMUTABLE',
    'LINKED_EVIDENCE_SCOPE_IMMUTABLE',
    'business_record_documents_delete_guard',
    'documents_linked_scope_guard',
    'business_records_linked_scope_guard',
  ]) {
    if (!financeDomain.includes(marker)) throw new Error(`local immutable evidence-link marker missing: ${marker}`)
  }
  const health = fs.readFileSync(healthPath, 'utf8')
  if (!health.includes('financeSchemaVersion: FINANCE_SCHEMA_VERSION')) {
    throw new Error('local health response must expose financeSchemaVersion')
  }
  if (!server.includes('importAnalysisAvailable: importClassifier !== null')
      || !server.includes('const registrationAvailable = smsProvider !== null')
      || !server.includes('&& emailProvider !== null')
      || !server.includes('&& Boolean(config.UWAY_PHONE_CODE_PEPPER)')
      || !server.includes('&& Boolean(config.UWAY_EMAIL_CODE_PEPPER)')) {
    throw new Error('local capabilities endpoint must derive import and registration availability from configured provider state')
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
    "listEndpoint: '/api/v2/business-record-evidence'",
    "coverageEndpoint: '/api/v2/business-record-evidence-coverage'",
    "uploadEndpoint: '/api/v2/business-record-evidence'",
    "contentEndpoint: '/api/v2/business-record-evidence/:evidenceId/content'",
    "revokeEndpoint: '/api/v2/business-record-evidence/:evidenceId/revoke'",
    "contentImmutability: 'database_trigger_and_sha256'",
    "lifecycle: ['active', 'revoked']",
    'deletion: false',
    'accountBookScoped: true',
    "legacyStateEncoding: 'json_number'",
    "financeV2Encoding: 'decimal_string'",
    'databasePrecision: 18',
    'databaseScale: 2',
    'aiMayWriteBusinessRecords: false',
    'aiMayPostJournalVouchers: false',
    "reason: options.importAnalysisAvailable ? null : 'provider_not_configured'",
    "analysisEndpoint: '/api/import-analysis'",
    "decisionEndpoint: '/api/import-analysis/:analysisId/decision'",
    "scope: 'account_book'",
    'sharedWithinAccountBook: true',
    "idempotencyKey: 'analysisId'",
    "idempotencyReplayHeader: 'Idempotency-Replayed'",
    "codeEndpoint: '/api/auth/registration-code'",
    "registerEndpoint: '/api/auth/register'",
    "usernameAvailabilityEndpoint: '/api/auth/username-availability'",
    "phoneVerification: 'aliyun_sms'",
    'emailRequired: true',
    'emailVerificationRequired: true',
    "purpose: 'registration_verification'",
    "strategy: 'email_link'",
    "confirmEndpoint: '/api/auth/registration-email/confirm'",
    "resendEndpoint: '/api/auth/registration-email/resend'",
    'delivery: options.emailDelivery ?? null',
    "tokenStorage: 'hmac_sha256_digest_only'",
    "tokenTransport: 'url_fragment_then_post_body'",
    "activation: 'after_email_confirmation'",
    'pendingTenantCreated: false',
    "unknownPendingResponse: 'indistinguishable'",
    "usernameNormalization: 'nfkc_lowercase'",
    'usernameLength: { min: 3, max: 32 }',
    'passwordLength: { min: 8, max: 256 }',
    'createsIsolatedOrganizationAndAccountBookAfterEmailConfirmation: true',
    "sessionCookie: 'http_only_secure_same_site_strict'",
    "acceptedIdentifiers: ['username', 'phone', 'email']",
    "identifierField: 'identifier'",
    'legacyUsernameFieldAccepted: true',
    "invalidCredentialsMessage: '账号或密码错误'",
    'sessionRevokedOnPasswordReset: true',
    "requestEndpoint: '/api/auth/password-reset/request'",
    "confirmEndpoint: '/api/auth/password-reset/confirm'",
    "codeStorage: 'hmac_sha256_digest_only'",
    "unknownEmailResponse: 'indistinguishable'",
    "sessionRevocation: 'all_sessions'",
  ]) {
    if (!capabilities.includes(marker)) throw new Error(`local capabilities marker missing: ${marker}`)
  }
  const importRouteStart = server.indexOf("app.post('/api/import-analysis'")
  const importDecisionRouteStart = server.indexOf("app.post('/api/import-analysis/:analysisId/decision'")
  const importRoute = importRouteStart >= 0 && importDecisionRouteStart > importRouteStart
    ? server.slice(importRouteStart, importDecisionRouteStart)
    : ''
  for (const marker of [
    'const user = (request as AuthenticatedRequest).authUser',
    'getFinanceContext(pool, user.id, parsed.data.accountBookId)',
    'assertFinanceWritable(context.selectedAccountBook)',
    'findImportAnalysisReplay(pool, context.selectedAccountBook.id',
    'listKnownImportFingerprints(pool, context.selectedAccountBook.id)',
  ]) {
    if (!importRoute.includes(marker)) throw new Error(`local import route account-book authorization marker missing: ${marker}`)
  }
  const database = fs.readFileSync(databasePath, 'utf8')
  for (const marker of [
    'importAnalysisRequestHash',
    'canonicalJson',
    "'IMPORT_ANALYSIS_ID_REUSED'",
    "'IMPORT_ANALYSIS_DECISION_CONFLICT'",
    'WHERE account_book_id = $1 AND analysis_id = $2',
    'ON CONFLICT (account_book_id, analysis_id) DO NOTHING',
  ]) {
    if (!database.includes(marker)) throw new Error(`local import persistence isolation marker missing: ${marker}`)
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
  const businessRecordEvidence = fs.readFileSync(businessRecordEvidencePath, 'utf8')
  for (const marker of [
    "'invoice', 'payment_proof', 'receipt', 'contract', 'bank_slip', 'expense_claim', 'payroll', 'tax', 'other'",
    "'image/jpeg' | 'image/png' | 'image/webp' | 'image/heic' | 'image/heif' | 'application/pdf'",
    "status: 'active' | 'revoked'",
    'createHash(\'sha256\')',
    'IDEMPOTENCY_KEY_REUSED',
    'EVIDENCE_WRITE_FORBIDDEN',
    'EVIDENCE_VERSION_CONFLICT',
    'EVIDENCE_INTEGRITY_MISMATCH',
    'contentDeleted: false',
    'contentImmutable: true',
    'account_book_id',
  ]) {
    if (!businessRecordEvidence.includes(marker)) throw new Error(`local business record evidence marker missing: ${marker}`)
  }
  const registration = fs.readFileSync(registrationPath, 'utf8')
  for (const marker of [
    'registrationCodeRequestSchema',
    'registrationEmailConfirmSchema',
    'registrationEmailResendSchema',
    'usernameAvailabilitySchema',
    'registrationSchema',
    'email: emailSchema',
    'validateUsername',
    'validatePassword',
    'REGISTRATION_CODE_RATE_LIMITED',
    'REGISTRATION_EMAIL_RESEND_RATE_LIMITED',
    'REGISTRATION_EMAIL_LINK_RATE_LIMITED',
    'EMAIL_VERIFICATION_UNAVAILABLE',
    'INVALID_REGISTRATION_EMAIL_TOKEN',
    'pending_account_registrations',
    'registrationEmailTokenDigest',
    "update('registration_email_link')",
    'email_verified_at',
    'REGISTRATION_IDENTITY_CONFLICT',
    'SMS_PROVIDER_UNAVAILABLE',
    'SMS_DELIVERY_FAILED',
    'syncLegacyStateToFinanceV2',
    'INSERT INTO app_state',
    'INSERT INTO sessions',
  ]) {
    if (!registration.includes(marker)) throw new Error(`local registration safety marker missing: ${marker}`)
  }
  const authentication = fs.readFileSync(authenticationPath, 'utf8')
  for (const marker of ['identifier:', 'username:', 'loginIdentifierFromRequest', 'classifyLoginIdentifier', 'INVALID_CREDENTIALS_MESSAGE', '账号或密码错误']) {
    if (!authentication.includes(marker)) throw new Error(`local authentication privacy marker missing: ${marker}`)
  }
  const identity = fs.readFileSync(identityPath, 'utf8')
  for (const marker of ['normalize(\'NFKC\')', 'USERNAME_MIN_LENGTH = 3', 'USERNAME_MAX_LENGTH = 32', 'PASSWORD_MIN_LENGTH = 8', 'PASSWORD_MAX_LENGTH = 256', 'RESERVED_USERNAMES', 'numeric_only', '手机号后六位', '邮箱名称']) {
    if (!identity.includes(marker)) throw new Error(`local identity policy marker missing: ${marker}`)
  }
  const passwordRecovery = fs.readFileSync(passwordRecoveryPath, 'utf8')
  for (const marker of ['passwordResetRequestSchema', 'passwordResetConfirmSchema', 'EMAIL_RESET_UNAVAILABLE', 'INVALID_PASSWORD_RESET_CODE', 'hmac_sha256_digest_only', 'DELETE FROM sessions', 'requestPasswordReset', 'confirmPasswordReset']) {
    if (!passwordRecovery.includes(marker) && !(marker === 'hmac_sha256_digest_only' && capabilities.includes(marker))) {
      throw new Error(`local password recovery marker missing: ${marker}`)
    }
  }
  const emailProvider = [
    fs.readFileSync(emailPath, 'utf8'),
    fs.readFileSync(path.join(workspace, 'server', 'config.ts'), 'utf8'),
    fs.readFileSync(serverPath, 'utf8'),
  ].join('\n')
  for (const marker of ['aliyun_direct_mail', 'email_webhook', 'sendSecurityCode', 'registration_verification', 'password_reset']) {
    if (!emailProvider.includes(marker)) throw new Error(`local email provider marker missing: ${marker}`)
  }
}

const ledger = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'LedgerView.swift'), 'utf8')
if (!ledger.includes('fixedControls') || !ledger.includes('ledgerScroll')) throw new Error('ledger fixed/scroll boundary missing')
if (ledger.includes('pinnedViews:')) throw new Error('month headings must not be sticky')
for (const marker of ['查看附件（', 'evidenceCoverageStore.coverage(for:', 'autoPreviewFirstSupported: true', '当前不显示“材料齐全”结论']) {
  if (!ledger.includes(marker)) throw new Error(`ledger evidence integration marker missing: ${marker}`)
}

const workflow = fs.readFileSync(workflowPath, 'utf8')
for (const marker of [
  'runs-on: macos-26',
  'uses: actions/checkout@v7',
  'xcodegen generate --spec project.yml',
  'build-for-testing',
  'Verify built API configuration',
  'Package interactive simulator build',
  'UwayFinance-simulator.zip',
  'shasum -a 256',
  'test-without-building',
  'Build unsigned iPhone device app',
  "-destination 'generic/platform=iOS'",
  'Package unsigned IPA for local signing',
  'UwayFinance-unsigned.ipa',
  'test ! -e "$APP_PATH/embedded.mobileprovision"',
  'CODE_SIGNING_ALLOWED=NO',
  'uses: actions/upload-artifact@v7',
  'Upload interactive simulator build',
  'Upload unsigned iPhone device build',
]) {
  if (!workflow.includes(marker)) throw new Error(`iOS CI marker missing: ${marker}`)
}

console.log(`validated iOS ${expectedMarketingVersion}: ${requiredFiles.length} files, ${currentContracts.length} API contracts, ${fixtures.length} JSON fixtures, macOS CI${hasLocalBackend ? ', local backend cross-check' : ''}`)
