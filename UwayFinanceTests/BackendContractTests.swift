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
        XCTAssertFalse(contract.capabilities.ocr)
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
