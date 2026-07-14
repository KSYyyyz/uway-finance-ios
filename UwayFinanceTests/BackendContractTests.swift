import XCTest
@testable import UwayFinance

final class BackendContractTests: XCTestCase {
    func testHealthV081DecodesWithoutFinanceSchemaVersion() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.8.1"))
        let contract = BackendContract(health: health)

        XCTAssertEqual(health.version, "0.8.1")
        XCTAssertNil(health.financeSchemaVersion)
        XCTAssertEqual(contract.capabilities.financeDataMode, .legacyStateCompatibility)
        XCTAssertFalse(contract.capabilities.financeDomainV2Mirror)
        XCTAssertFalse(contract.capabilities.financeResourceAPI)
    }

    func testHealthV090RecognizesFinanceDomainV2Mirror() throws {
        let health = try JSONDecoder().decode(HealthResponse.self, from: fixture(named: "health-v0.9.0"))
        let contract = BackendContract(health: health)

        XCTAssertEqual(health.version, "0.9.0")
        XCTAssertEqual(health.financeSchemaVersion, BackendContract.financeDomainV2Schema)
        XCTAssertEqual(contract.capabilities.financeDataMode, .legacyStateCompatibility)
        XCTAssertTrue(contract.capabilities.financeDomainV2Mirror)
        XCTAssertFalse(contract.capabilities.financeResourceAPI)
    }

    func testCapabilitiesPreserveHarnessThreeStateSafetyBoundary() {
        let capabilities = ServerCapabilities.current(financeSchemaVersion: BackendContract.financeDomainV2Schema)

        XCTAssertEqual(capabilities.importHarnessStatuses, Set(["accepted", "review", "rejected"]))
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
