import XCTest
@testable import UwayFinance

@MainActor
final class ClassificationPreferenceStoreTests: XCTestCase {
    func testOpaquePaginationAndFilterStayAccountBookScoped() async throws {
        let first = try decodeList("classification-preferences-active-v0.12.0")
        let second = try decodeList("classification-preferences-revoked-v0.12.0")
        let api = ClassificationPreferenceAPISpy(listResults: [.success(first), .success(second), .success(first)])
        let store = ClassificationPreferenceStore(api: api)

        await store.restore(accountBook: first.accountBook)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.nextCursor, "opaque+/preference=")
        await store.nextPage()
        XCTAssertTrue(store.canGoBack)
        await store.previousPage()
        XCTAssertFalse(store.canGoBack)

        let queries = await api.capturedListQueries()
        XCTAssertEqual(queries.map(\.accountBookId), ["11", "11", "11"])
        XCTAssertEqual(queries.map(\.cursor), [nil, "opaque+/preference=", nil])
        XCTAssertEqual(queries.map(\.limit), [10, 10, 10])
    }

    func testOfflineRevokeRetryKeepsReasonAndReusesIdenticalCommand() async throws {
        let page = try decodeList("classification-preferences-active-v0.12.0")
        let after = ClassificationPreferenceListResponse(
            accountBook: page.accountBook,
            items: Array(page.items.dropFirst()),
            page: ClassificationPreferencePage(limit: 10, nextCursor: nil),
            safety: page.safety
        )
        let response = try decodeRevoke()
        let api = ClassificationPreferenceAPISpy(
            listResults: [.success(page), .success(after)],
            revokeResults: [.failure(.transport("offline")), .success(response)]
        )
        let store = ClassificationPreferenceStore(api: api)
        await store.restore(accountBook: page.accountBook)
        let item = try XCTUnwrap(store.items.first)
        store.setRevokeReason("这次判断不应继续参与分类", for: item.id)

        let firstAttempt = await store.revoke(item)
        XCTAssertFalse(firstAttempt)
        XCTAssertEqual(store.revokeDrafts[item.id], "这次判断不应继续参与分类")
        XCTAssertTrue(store.message?.contains("幂等请求") == true)
        let secondAttempt = await store.revoke(item)
        XCTAssertTrue(secondAttempt)

        let commands = await api.capturedRevokeCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], commands[1])
        XCTAssertNil(store.revokeDrafts[item.id])
        XCTAssertEqual(store.successTrigger, 1)
    }

    func testVersionConflictPreservesDraftFilterAndPaginationWhileRefreshingCurrentPage() async throws {
        let first = try decodeList("classification-preferences-active-v0.12.0")
        let currentPage = ClassificationPreferenceListResponse(
            accountBook: first.accountBook,
            items: first.items,
            page: ClassificationPreferencePage(limit: 10, nextCursor: nil),
            safety: first.safety
        )
        let api = ClassificationPreferenceAPISpy(
            listResults: [.success(first), .success(currentPage), .success(currentPage)],
            revokeResults: [.failure(.server(
                status: 409,
                code: "CLASSIFICATION_PREFERENCE_VERSION_CONFLICT",
                message: "版本已变化"
            ))]
        )
        let store = ClassificationPreferenceStore(api: api)
        await store.restore(accountBook: first.accountBook)
        await store.nextPage()
        let item = try XCTUnwrap(store.items.first)
        store.setRevokeReason("保留这份未提交撤销理由", for: item.id)

        let succeeded = await store.revoke(item)
        XCTAssertFalse(succeeded)

        XCTAssertEqual(store.selectedState, .active)
        XCTAssertTrue(store.canGoBack)
        XCTAssertEqual(store.revokeDrafts[item.id], "保留这份未提交撤销理由")
        XCTAssertTrue(store.message?.contains("当前筛选和分页") == true)
        let queries = await api.capturedListQueries()
        XCTAssertEqual(queries.map(\.cursor), [nil, "opaque+/preference=", "opaque+/preference="])
    }

    func testSwitchingAccountBookClearsDraftsCursorsAndOldItems() async throws {
        let first = try decodeList("classification-preferences-active-v0.12.0")
        let secondBook = FinanceAccountBookAccess(
            id: "22",
            name: "第二账套",
            baseCurrency: "CNY",
            organization: FinanceResourceOrganization(id: "8", name: "第二组织"),
            role: "finance",
            permissions: FinanceResourcePermissions(readBusinessRecords: true, writeBusinessRecords: true)
        )
        let second = ClassificationPreferenceListResponse(
            accountBook: secondBook,
            items: [],
            page: ClassificationPreferencePage(limit: 10, nextCursor: nil),
            safety: first.safety
        )
        let api = ClassificationPreferenceAPISpy(listResults: [.success(first), .success(second)])
        let store = ClassificationPreferenceStore(api: api)
        await store.restore(accountBook: first.accountBook)
        let item = try XCTUnwrap(store.items.first)
        store.setRevokeReason("不能跨账套保留", for: item.id)

        await store.restore(accountBook: secondBook)

        XCTAssertEqual(store.accountBook?.id, "22")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.revokeDrafts.isEmpty)
        XCTAssertFalse(store.canGoBack)
        XCTAssertEqual(store.selectedState, .active)
        let queries = await api.capturedListQueries()
        XCTAssertEqual(queries.map(\.accountBookId), ["11", "22"])
    }

    func testMismatchedAccountBookResponseFailsClosedAndClearsCache() async throws {
        let first = try decodeList("classification-preferences-active-v0.12.0")
        let wrongBook = FinanceAccountBookAccess(
            id: "99", name: "错误账套", baseCurrency: "CNY",
            organization: FinanceResourceOrganization(id: "99", name: "错误组织"), role: "finance",
            permissions: FinanceResourcePermissions(readBusinessRecords: true, writeBusinessRecords: true)
        )
        let mismatched = ClassificationPreferenceListResponse(
            accountBook: wrongBook,
            items: first.items,
            page: first.page,
            safety: first.safety
        )
        let store = ClassificationPreferenceStore(
            api: ClassificationPreferenceAPISpy(listResults: [.success(mismatched)])
        )

        await store.restore(accountBook: first.accountBook)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.revokeDrafts.isEmpty)
        XCTAssertTrue(store.message?.contains("不同账套") == true)
    }

    private func decodeList(_ name: String) throws -> ClassificationPreferenceListResponse {
        try decode(ClassificationPreferenceListResponse.self, name)
    }

    private func decodeRevoke() throws -> ClassificationPreferenceRevokeResponse {
        try decode(ClassificationPreferenceRevokeResponse.self, "classification-preference-revoke-v0.12.0")
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

private actor ClassificationPreferenceAPISpy: ClassificationPreferenceAPI {
    private var listResults: [Result<ClassificationPreferenceListResponse, APIError>]
    private var revokeResults: [Result<ClassificationPreferenceRevokeResponse, APIError>]
    private var listQueries: [ClassificationPreferenceQuery] = []
    private var revokeCommands: [ClassificationPreferenceRevokeCommand] = []

    init(
        listResults: [Result<ClassificationPreferenceListResponse, APIError>],
        revokeResults: [Result<ClassificationPreferenceRevokeResponse, APIError>] = []
    ) {
        self.listResults = listResults
        self.revokeResults = revokeResults
    }

    func capturedListQueries() -> [ClassificationPreferenceQuery] { listQueries }
    func capturedRevokeCommands() -> [ClassificationPreferenceRevokeCommand] { revokeCommands }

    func list(_ query: ClassificationPreferenceQuery) async throws -> ClassificationPreferenceListResponse {
        listQueries.append(query)
        guard !listResults.isEmpty else { throw APIError.invalidResponse }
        return try listResults.removeFirst().get()
    }

    func revoke(_ command: ClassificationPreferenceRevokeCommand) async throws -> ClassificationPreferenceRevokeResponse {
        revokeCommands.append(command)
        guard !revokeResults.isEmpty else { throw APIError.invalidResponse }
        return try revokeResults.removeFirst().get()
    }
}
