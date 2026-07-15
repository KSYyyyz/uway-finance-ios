import XCTest
@testable import UwayFinance

final class RecordDeepLinkTests: XCTestCase {
    func testPendingRiskDeepLinkResolvesMatchingFixtureRecordAndKeepsFilterContext() throws {
        let envelope = try decodeStateFixture()

        let resolution = RecordDeepLinkResolver.resolve(
            recordID: "102",
            availableRecordIDs: Set(envelope.data.records.map(\.id)),
            canRead: true,
            canEdit: true,
            origin: .pending(filter: "high")
        )

        guard case .destination(let route) = resolution else {
            return XCTFail("matching risk item should open its operating record")
        }
        XCTAssertEqual(route.recordID, "102")
        XCTAssertEqual(route.origin, .pending(filter: "high"))
        XCTAssertTrue(route.canEdit)
    }

    func testDeepLinkFailsClearlyWhenRecordIsMissing() {
        let resolution = RecordDeepLinkResolver.resolve(
            recordID: "missing",
            availableRecordIDs: ["102"],
            canRead: true,
            canEdit: true,
            origin: .ledger
        )

        XCTAssertEqual(resolution, .failure(.notFound(recordID: "missing")))
        XCTAssertFalse(RecordDeepLinkFailure.notFound(recordID: "missing").message.isEmpty)
    }

    func testDeepLinkFailsClosedWhenAccountBookCannotReadRecords() {
        let resolution = RecordDeepLinkResolver.resolve(
            recordID: "102",
            availableRecordIDs: ["102"],
            canRead: false,
            canEdit: false,
            origin: .classification(state: "pending")
        )

        XCTAssertEqual(resolution, .failure(.forbidden(recordID: "102")))
    }

    func testResolvedDetailReportsDeletionIfRecordDisappears() {
        XCTAssertEqual(
            RecordDeepLinkResolver.missingRecordFailure(recordID: "102", wasPreviouslyResolved: true),
            .deleted(recordID: "102")
        )
        XCTAssertEqual(
            RecordDeepLinkResolver.missingRecordFailure(recordID: "102", wasPreviouslyResolved: false),
            .notFound(recordID: "102")
        )
    }

    func testApplicationScrollPolicyHidesOnlyVisualIndicators() {
        XCTAssertTrue(AppScrollPolicy.hidesIndicators)
    }

    private func decodeStateFixture() throws -> StateEnvelope {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "state-record-deeplink-v0.11.0", withExtension: "json"))
        return try JSONDecoder().decode(StateEnvelope.self, from: Data(contentsOf: url))
    }
}
