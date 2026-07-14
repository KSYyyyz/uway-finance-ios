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

        XCTAssertEqual(contract.negotiatedAPIContractVersion, BackendContract.apiContractVersion)
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.financeDomainV2Schema)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.source, .server)
        XCTAssertTrue(contract.capabilities.financeDomainV2Mirror)
        XCTAssertFalse(contract.capabilities.financeResourceAPI)
        XCTAssertEqual(contract.capabilities.money.legacyStateEncoding, "json_number")
        XCTAssertEqual(contract.capabilities.money.financeV2Encoding, "decimal_string")
        XCTAssertEqual(contract.capabilities.money.databasePrecision, 18)
        XCTAssertEqual(contract.capabilities.money.databaseScale, 2)
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
