import XCTest
@testable import UwayFinance

@MainActor
final class BusinessRecordEvidenceCoverageStoreTests: XCTestCase {
    func testLoadsWholeBookCoverageOnceAndReusesItAcrossRows() async throws {
        let response = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.14.0")
        let api = CoverageAPISpy(contexts: [context(bookID: "11")], coverages: [.success(response)])
        let store = BusinessRecordEvidenceCoverageStore(api: api)

        await store.load(userID: "user-1")
        _ = store.coverage(for: "R-EVIDENCE")
        _ = store.coverage(for: "R-MISSING")
        await store.load(userID: "user-1")

        let requests = await api.coverageRequests()
        XCTAssertEqual(requests, ["11"])
        XCTAssertEqual(store.coverage(for: "R-EVIDENCE")?.activeEvidenceCount, 2)
        XCTAssertEqual(store.coverage(for: "R-MISSING")?.requirementState, .requiredMissing)
    }

    func testAccountBookSwitchClearsCacheAndFetchesOnlyNewBook() async throws {
        let first = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.14.0")
        let second = BusinessRecordEvidenceCoverageResponse(records: [
            "R-SECOND": BusinessRecordEvidenceCoverage(
                activeEvidenceCount: 1,
                invoiceEvidenceCount: 1,
                paymentEvidenceCount: 0,
                requirementState: .satisfied
            ),
        ])
        let api = CoverageAPISpy(
            contexts: [context(bookID: "11"), context(bookID: "22")],
            coverages: [.success(first), .success(second)]
        )
        let store = BusinessRecordEvidenceCoverageStore(api: api)

        await store.load(userID: "user-1")
        await store.load(userID: "user-1", requestedAccountBookID: "22", force: true)

        XCTAssertNil(store.coverage(for: "R-EVIDENCE"))
        XCTAssertEqual(store.coverage(for: "R-SECOND")?.activeEvidenceCount, 1)
        let requests = await api.coverageRequests()
        XCTAssertEqual(requests, ["11", "22"])
    }

    func testFailureClearsStaleCoverageAndDoesNotClaimSatisfied() async throws {
        let response = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.14.0")
        let api = CoverageAPISpy(
            contexts: [context(bookID: "11"), context(bookID: "11")],
            coverages: [.success(response), .failure(.transport("offline"))]
        )
        let store = BusinessRecordEvidenceCoverageStore(api: api)

        await store.load(userID: "user-1")
        XCTAssertEqual(store.coverage(for: "R-EVIDENCE")?.requirementState, .satisfied)
        await store.load(userID: "user-1", force: true)

        XCTAssertNil(store.coverage(for: "R-EVIDENCE"))
        guard case .failed = store.loadState else { return XCTFail("coverage failure must be visible") }
    }

    private func context(bookID: String) -> FinanceContextResponse {
        let book = FinanceAccountBookAccess(
            id: bookID,
            name: "账套 \(bookID)",
            baseCurrency: "CNY",
            organization: FinanceResourceOrganization(id: bookID, name: "组织 \(bookID)"),
            role: "finance",
            permissions: FinanceResourcePermissions(readBusinessRecords: true, writeBusinessRecords: true)
        )
        return FinanceContextResponse(selectedAccountBook: book, accountBooks: [book])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

private actor CoverageAPISpy: BusinessRecordEvidenceAPI {
    private var contexts: [FinanceContextResponse]
    private var coverages: [Result<BusinessRecordEvidenceCoverageResponse, APIError>]
    private var requestedBooks: [String] = []

    init(contexts: [FinanceContextResponse], coverages: [Result<BusinessRecordEvidenceCoverageResponse, APIError>]) {
        self.contexts = contexts
        self.coverages = coverages
    }

    func coverageRequests() -> [String] { requestedBooks }
    func context(accountBookId: String?) async throws -> FinanceContextResponse {
        guard !contexts.isEmpty else { throw APIError.invalidResponse }
        return contexts.removeFirst()
    }
    func coverage(accountBookId: String) async throws -> BusinessRecordEvidenceCoverageResponse {
        requestedBooks.append(accountBookId)
        guard !coverages.isEmpty else { throw APIError.invalidResponse }
        return try coverages.removeFirst().get()
    }
    func list(_ query: BusinessRecordEvidenceListQuery) async throws -> BusinessRecordEvidenceListResponse { throw APIError.invalidResponse }
    func upload(_ command: BusinessRecordEvidenceUploadCommand) async throws -> BusinessRecordEvidenceUploadResponse { throw APIError.invalidResponse }
    func content(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent { throw APIError.invalidResponse }
    func revoke(_ command: BusinessRecordEvidenceRevokeCommand) async throws -> BusinessRecordEvidenceRevokeResponse { throw APIError.invalidResponse }
}
