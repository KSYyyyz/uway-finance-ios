import XCTest
@testable import UwayFinance

final class BackendContractTests: XCTestCase {
    func testHealthV081WithoutCapabilitiesFallsBackSafely() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.8.1"))
        let contract = BackendContract(health: health)

        XCTAssertEqual(health.version, "0.8.1")
        XCTAssertNil(health.financeSchemaVersion)
        XCTAssertNil(contract.negotiatedAPIContractVersion)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.source, .legacyFallback)
        XCTAssertFalse(contract.capabilities.financeResourceAPI)
        XCTAssertFalse(contract.capabilities.importAnalysis.available)
        XCTAssertEqual(contract.capabilities.importAnalysis.reason, "capabilities_unavailable")
        XCTAssertFalse(contract.capabilities.documentUpload)
        XCTAssertFalse(contract.capabilities.documentUploadCapability.safeForClientUse)
        XCTAssertFalse(contract.capabilities.ocr)
        XCTAssertNil(contract.capabilities.classificationPreferenceMemory)
    }

    func testCapabilitiesV090NegotiatesOnlyPublishedLegacyMode() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.9.0"))
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.9.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_001")
        XCTAssertEqual(contract.financeSchemaVersion, "20260714_001_finance_domain_v2")
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.source, .server)
        XCTAssertFalse(contract.capabilities.financeDomainV2Mirror)
        XCTAssertFalse(contract.capabilities.financeResourceAPI)
        XCTAssertEqual(contract.capabilities.money.legacyStateEncoding, "json_number")
        XCTAssertEqual(contract.capabilities.money.financeV2Encoding, "decimal_string")
        XCTAssertEqual(contract.capabilities.money.databasePrecision, 18)
        XCTAssertEqual(contract.capabilities.money.databaseScale, 2)
        XCTAssertTrue(contract.capabilities.importAnalysis.available)
        XCTAssertNil(contract.capabilities.importAnalysis.reason)
    }

    func testCapabilitiesV010RemainDecodableWithoutCutoverReadiness() throws {
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.10.0")
        )

        XCTAssertNil(response.sync.financeResources.cutoverReadiness)
        XCTAssertEqual(response.sync.financeResources.cutoverState, "shadow")
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        XCTAssertNil(response.sync.legacyState.versionSource)
        XCTAssertNil(response.sync.legacyState.etagHeader)
        XCTAssertNil(response.sync.legacyState.conditionalWriteHeader)
    }

    func testCapabilitiesV0101ExposeReadOnlyCutoverReadinessWithoutSwitchingSyncMode() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.10.1"))
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.10.1")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_003")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.financeDomainV2Schema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        XCTAssertTrue(contract.capabilities.financeResourceAPI)
        XCTAssertEqual(contract.capabilities.financeResources.cutoverState, "shadow")
        XCTAssertEqual(contract.capabilities.financeResources.businessRecords?.pagination, "cursor")
        XCTAssertEqual(contract.capabilities.financeResources.businessRecords?.idempotencyHeader, "Idempotency-Key")
        XCTAssertEqual(contract.capabilities.financeResources.businessRecords?.concurrencyControl, "expectedVersion")
        XCTAssertFalse(contract.capabilities.financeResources.businessRecords?.delete ?? true)
        let readiness = try XCTUnwrap(contract.capabilities.financeResources.cutoverReadiness)
        XCTAssertTrue(readiness.available)
        XCTAssertEqual(readiness.endpoint, "/api/v2/cutover-readiness")
        XCTAssertEqual(readiness.pagination, "cursor")
        XCTAssertTrue(readiness.requiresZeroDifferences)
        XCTAssertTrue(readiness.requiresZeroShadowOnlyRecords)
        XCTAssertFalse(readiness.clientWritesEnabled)
        XCTAssertFalse(contract.capabilities.unifiedDashboardMetrics)
        XCTAssertNil(contract.capabilities.dashboardMetrics.endpoint)
        XCTAssertFalse(contract.capabilities.deterministicGroupingAvailable)
    }

    func testCapabilitiesV0102ExposeReadOnlyDashboardMetricsWithoutClaimingAIClassification() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.10.2"))
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.10.2")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_004")
        XCTAssertEqual(contract.serverVersion, "0.10.2")
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        XCTAssertTrue(contract.capabilities.unifiedDashboardMetrics)
        XCTAssertEqual(contract.capabilities.dashboardMetrics.endpoint, "/api/v2/dashboard-metrics")
        XCTAssertEqual(contract.capabilities.dashboardMetrics.moneyEncoding, "decimal_string")
        XCTAssertEqual(contract.capabilities.dashboardMetrics.source, "finance_v2_shadow_read_model")
        XCTAssertEqual(contract.capabilities.dashboardMetrics.rawRecordsMerged, false)
        XCTAssertEqual(contract.capabilities.dashboardMetrics.classificationStates, ["accepted", "review", "unclassified"])
        XCTAssertFalse(contract.capabilities.aiClassification)
        XCTAssertTrue(contract.capabilities.deterministicGroupingAvailable)
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertNil(contract.capabilities.classificationReview)
        XCTAssertNil(contract.capabilities.aiClassificationCapability.contract)
    }

    func testClassificationReviewCapabilityNegotiatesCurrentSafetyContractWithoutChangingSyncMode() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-classification-review-v0.11.0")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-classification-review-v0.11.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_007")
        XCTAssertEqual(contract.serverVersion, "0.11.0")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.classificationReviewSchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        XCTAssertEqual(response.sync.legacyState.conflictControl, "optional_if_match")
        XCTAssertEqual(response.sync.legacyState.versionSource, "updatedAt")
        XCTAssertEqual(response.sync.legacyState.etagHeader, "ETag")
        XCTAssertEqual(response.sync.legacyState.conditionalWriteHeader, "If-Match")
        XCTAssertEqual(contract.capabilities.legacyState.conflictControl, "optional_if_match")
        XCTAssertEqual(contract.capabilities.legacyState.conditionalWriteHeader, "If-Match")
        let review = try XCTUnwrap(contract.capabilities.classificationReview)
        XCTAssertEqual(review.defaultPageSize, 10)
        XCTAssertEqual(review.pagination, "cursor")
        XCTAssertEqual(review.decisions, ["confirm", "correct", "reject"])
        XCTAssertEqual(review.concurrencyControl, ["expectedRecordVersion", "expectedClassificationVersion"])
        XCTAssertFalse(review.modelCanAccept)
        XCTAssertTrue(review.deterministicRuleMayAccept)
        XCTAssertFalse(review.rawBusinessRecordsChanged)
        XCTAssertTrue(contract.capabilities.aiClassification)
        XCTAssertEqual(contract.capabilities.aiClassificationCapability.contract, "closed_set_existing_operating_item_v1")
        XCTAssertFalse(contract.capabilities.aiClassificationCapability.modelCanAccept ?? true)
        XCTAssertFalse(contract.capabilities.aiClassificationCapability.writesBusinessRecords ?? true)
        XCTAssertNil(contract.capabilities.classificationPreferenceMemory)
    }

    func testPreferenceMemoryCapabilityNegotiatesCurrentAccountBookSafetyWithoutChangingSyncMode() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-preference-memory-v0.12.0")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-preference-memory-v0.12.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.serverVersion, "0.12.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260715_008")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.classificationPreferenceMemorySchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        let memory = try XCTUnwrap(contract.capabilities.classificationPreferenceMemory)
        XCTAssertTrue(memory.safeForClientUse)
        XCTAssertEqual(memory.scope, "account_book")
        XCTAssertEqual(memory.source, "explicit_authenticated_human_decisions")
        XCTAssertEqual(memory.minimumConsistentObservations, 3)
        XCTAssertEqual(memory.minimumConsistency, 0.8)
        XCTAssertEqual(Set(memory.lifecycleStates), Set(["active", "revoked", "invalidated"]))
        XCTAssertEqual(memory.effect, "closed_candidate_reordering_only")
        XCTAssertEqual(memory.idempotencyHeader, "Idempotency-Key")
        XCTAssertEqual(memory.concurrencyControl, "expectedVersion")
        XCTAssertFalse(memory.modelCanAccept)
        XCTAssertFalse(memory.writesBusinessRecords)
        XCTAssertNil(memory.learningState)
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(contract.capabilities.safety.aiMayPostJournalVouchers)
        XCTAssertFalse(contract.capabilities.documentUploadCapability.safeForClientUse)
    }

    func testImmutableEvidenceCapabilityNegotiatesExactCurrentSafetyWithoutChangingSyncMode() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-immutable-evidence-v0.13.0")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-immutable-evidence-v0.13.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.serverVersion, "0.13.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260715_009")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.immutableRecordEvidenceSchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(response.sync.availableModes, ["legacy_state_v1"])
        let evidence = contract.capabilities.documentUploadCapability
        XCTAssertTrue(evidence.safeForClientUse)
        XCTAssertEqual(evidence.listEndpoint, "/api/v2/business-record-evidence")
        XCTAssertEqual(evidence.coverageEndpoint, "/api/v2/business-record-evidence-coverage")
        XCTAssertEqual(evidence.maxBytes, 10_000_000)
        XCTAssertEqual(evidence.contentImmutability, "database_trigger_and_sha256")
        XCTAssertEqual(Set(evidence.lifecycle ?? []), Set(["active", "revoked"]))
        XCTAssertEqual(evidence.deletion, false)
        XCTAssertEqual(evidence.accountBookScoped, true)
        XCTAssertEqual(evidence.idempotencyHeader, "Idempotency-Key")
        XCTAssertNil(contract.capabilities.classificationPreferenceMemory?.learningState)
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(contract.capabilities.safety.aiMayPostJournalVouchers)
    }

    func testV0140SMSWebhookCapabilityRemainsBackwardCompatible() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-semantic-preference-memory-v0.14.0")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-semantic-preference-memory-v0.14.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.serverVersion, "0.14.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260715_011")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.immutableEvidenceLinksSchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        let memory = try XCTUnwrap(contract.capabilities.classificationPreferenceMemory)
        XCTAssertNil(memory.learningState)
        XCTAssertTrue(memory.semanticV2SafeForClientUse)
        XCTAssertEqual(Set(memory.learningStates ?? []), Set(ClassificationPreferenceLearningState.allCases))
        XCTAssertEqual(memory.normalizationVersion, "semantic-preference-v2")
        XCTAssertEqual(memory.companyScoped, true)
        XCTAssertEqual(memory.provisionalMinimumConsistentObservations, 2)
        XCTAssertFalse(memory.modelCanAccept)
        XCTAssertFalse(memory.writesBusinessRecords)
        XCTAssertTrue(contract.capabilities.registration.safeForClientUse)
        XCTAssertFalse(contract.capabilities.registration.supportsIdentityContract)
        XCTAssertFalse(contract.capabilities.authentication.safeForIdentifierLogin)
        XCTAssertFalse(contract.capabilities.passwordRecovery.safeForClientUse)
        XCTAssertEqual(contract.capabilities.registration.phoneVerification, "sms_webhook")
        XCTAssertEqual(contract.capabilities.registration.createsIsolatedOrganizationAndAccountBook, true)
        XCTAssertTrue(contract.capabilities.importAnalysis.safeForAccountBookUse)
        XCTAssertEqual(contract.capabilities.importAnalysis.scope, "account_book")
        XCTAssertEqual(contract.capabilities.importAnalysis.idempotencyKey, "analysisId")
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(contract.capabilities.safety.aiMayPostJournalVouchers)
    }

    func testV0150AccountIdentityRecoveryCapabilitiesDecodeFailClosedBoundaries() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-account-identity-recovery-v0.15.0")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-account-identity-recovery-v0.15.0")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.serverVersion, "0.15.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260720_013")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.accountIdentityRecoverySchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.financeResources.cutoverState, "shadow")
        XCTAssertTrue(contract.capabilities.registration.safeForClientUse)
        XCTAssertTrue(contract.capabilities.registration.supportsIdentityContract)
        XCTAssertEqual(contract.capabilities.registration.usernameAvailabilityEndpoint, "/api/auth/username-availability")
        XCTAssertEqual(contract.capabilities.registration.usernameLength, CapabilityLengthRange(min: 3, max: 32))
        XCTAssertEqual(contract.capabilities.registration.passwordLength, CapabilityLengthRange(min: 8, max: 256))
        XCTAssertTrue(contract.capabilities.authentication.safeForIdentifierLogin)
        XCTAssertTrue(contract.capabilities.passwordRecovery.safeForClientUse)
        XCTAssertEqual(contract.capabilities.passwordRecovery.unknownEmailResponse, "indistinguishable")
        XCTAssertEqual(contract.capabilities.passwordRecovery.sessionRevocation, "all_sessions")
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(contract.capabilities.safety.aiMayPostJournalVouchers)
    }

    func testUnavailablePasswordRecoveryCapabilityDoesNotExposeResetFlow() {
        let capability = PasswordRecoveryCapability(
            available: false,
            reason: "email_provider_not_configured",
            requestEndpoint: "/api/auth/password-reset/request",
            confirmEndpoint: "/api/auth/password-reset/confirm",
            delivery: "email_webhook",
            codeStorage: "hmac_sha256_digest_only",
            unknownEmailResponse: "indistinguishable",
            sessionRevocation: "all_sessions"
        )

        XCTAssertFalse(capability.safeForClientUse)
        XCTAssertEqual(capability.unavailableMessage, "邮件找回暂未开通")
    }

    func testV0141AliyunSMSCapabilityNegotiatesWithoutChangingRegistrationPayloadContract() throws {
        let health = try JSONDecoder().decode(
            HealthResponse.self,
            from: fixture(named: "health-aliyun-sms-v0.14.1")
        )
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-aliyun-sms-v0.14.1")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertEqual(contract.serverVersion, "0.14.1")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260720_012")
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.immutableEvidenceLinksSchema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertTrue(contract.capabilities.registration.safeForClientUse)
        XCTAssertEqual(contract.capabilities.registration.codeEndpoint, "/api/auth/registration-code")
        XCTAssertEqual(contract.capabilities.registration.registerEndpoint, "/api/auth/register")
        XCTAssertEqual(contract.capabilities.registration.phoneVerification, "aliyun_sms")
        XCTAssertEqual(contract.capabilities.registration.createsIsolatedOrganizationAndAccountBook, true)
        XCTAssertEqual(contract.capabilities.registration.sessionCookie, "http_only_secure_same_site_strict")
        XCTAssertFalse(contract.capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(contract.capabilities.safety.aiMayPostJournalVouchers)
    }

    func testUnknownRegistrationVerificationModeFailsClosed() {
        let capability = RegistrationCapability(
            available: true,
            reason: nil,
            codeEndpoint: "/api/auth/registration-code",
            registerEndpoint: "/api/auth/register",
            phoneVerification: "unrecognized_provider",
            createsIsolatedOrganizationAndAccountBook: true,
            sessionCookie: "http_only_secure_same_site_strict"
        )

        XCTAssertFalse(capability.safeForClientUse)
    }

    func testCapabilitiesV090ReportsUnconfiguredImportProvider() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.9.0"))
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.9.0-import-disabled")
        )
        let contract = BackendContract(health: health, negotiated: response)

        XCTAssertFalse(contract.capabilities.importAnalysis.available)
        XCTAssertEqual(contract.capabilities.importAnalysis.reason, "provider_not_configured")
        XCTAssertEqual(contract.capabilities.importAnalysis.statusDisplay, "未配置模型服务")
    }

    func testHistoricalImportCapabilityWithoutAccountBookFieldsFailsClosed() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.10.2"))
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.10.2")
        )
        let capability = BackendContract(health: health, negotiated: response).capabilities.importAnalysis

        XCTAssertTrue(capability.available)
        XCTAssertFalse(capability.safeForAccountBookUse)
        XCTAssertEqual(capability.statusDisplay, "契约不兼容")
    }

    func testNegotiatedFeaturesAndSafetyRemainUnavailableAndReadOnly() throws {
        let response = try JSONDecoder().decode(
            ServerCapabilitiesResponse.self,
            from: fixture(named: "capabilities-v0.9.0")
        )
        let capabilities = ServerCapabilities.negotiated(
            response,
            financeSchemaVersion: BackendContract.financeDomainV2Schema
        )

        XCTAssertEqual(capabilities.importHarnessStatuses, Set(["accepted", "review", "rejected"]))
        XCTAssertFalse(capabilities.unifiedDashboardMetrics)
        XCTAssertFalse(capabilities.workflowTasks)
        XCTAssertFalse(capabilities.aiClassification)
        XCTAssertFalse(capabilities.documentUpload)
        XCTAssertFalse(capabilities.ocr)
        XCTAssertFalse(capabilities.safety.aiMayWriteBusinessRecords)
        XCTAssertFalse(capabilities.safety.aiMayPostJournalVouchers)
        XCTAssertTrue(capabilities.safety.acceptedImportRequiresHarnessOrHumanDecision)
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
