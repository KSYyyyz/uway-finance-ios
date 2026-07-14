import XCTest
@testable import UwayFinance

@MainActor
final class ClassificationReviewStoreTests: XCTestCase {
    func testSessionRestoreAndOpaqueCursorStackSupportForwardAndBack() async throws {
        let first = try decodeList("classification-reviews-pending-v0.11.0")
        let second = try decodeList("classification-reviews-accepted-v0.11.0")
        let api = ClassificationReviewAPISpy(listResponses: [first, second, first])
        let store = ClassificationReviewStore(api: api)

        await store.restoreSession(accountBookId: "11", period: "2026-07")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.nextCursor, "opaque+/next=")
        XCTAssertFalse(store.canGoBack)

        await store.nextPage()
        XCTAssertTrue(store.canGoBack)
        await store.previousPage()
        XCTAssertFalse(store.canGoBack)

        let queries = await api.capturedListQueries()
        XCTAssertEqual(queries.map(\.cursor), [nil, "opaque+/next=", nil])
        XCTAssertEqual(queries.map(\.limit), [10, 10, 10])
    }

    func testOfflineDecisionRetryKeepsDraftAndReusesIdenticalCommand() async throws {
        let page = try decodeList("classification-reviews-pending-v0.11.0")
        let completedPage = try decodeList("classification-reviews-rejected-v0.11.0")
        let response = try decodeDecision("classification-decision-correct-v0.11.0")
        let api = ClassificationReviewAPISpy(
            listResponses: [page, completedPage],
            decisionResults: [.failure(.transport("offline")), .success(response)]
        )
        let store = ClassificationReviewStore(api: api)
        await store.restoreSession(accountBookId: "11")
        let item = try XCTUnwrap(store.items.first)
        store.setAction(.correct, for: item.id)
        store.setTaxonomyCode("professional_services", for: item.id)
        store.setNormalizedItemName("研发外包服务", for: item.id)
        store.setReason("合同属于研发外包", for: item.id)

        await store.submitDecision(item)
        XCTAssertEqual(store.drafts[item.id]?.reason, "合同属于研发外包")
        XCTAssertTrue(store.message?.contains("幂等请求") == true)
        await store.submitDecision(item)

        let commands = await api.capturedDecisionCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], commands[1])
        XCTAssertNil(store.drafts[item.id])
        XCTAssertEqual(store.successTrigger, 1)
    }

    func testVersionConflictReloadsCurrentVersionsWithoutOverwritingDraft() async throws {
        let page = try decodeList("classification-reviews-pending-v0.11.0")
        let api = ClassificationReviewAPISpy(
            listResponses: [page, page],
            decisionResults: [.failure(.versionConflict(expectedVersion: 3, currentVersion: 4))]
        )
        let store = ClassificationReviewStore(api: api)
        await store.restoreSession(accountBookId: "11")
        let item = try XCTUnwrap(store.items.first)
        store.setReason("保留这份人工理由", for: item.id)

        await store.submitDecision(item)

        XCTAssertEqual(store.drafts[item.id]?.reason, "保留这份人工理由")
        XCTAssertTrue(store.message?.contains("本地理由和更正草稿仍然保留") == true)
        let listQueries = await api.capturedListQueries()
        XCTAssertEqual(listQueries.count, 2)
    }

    func testAIUnavailableThenRetryReusesAnalyzeIdempotencyAndFallsBackToManualReview() async throws {
        let page = try decodeList("classification-reviews-pending-v0.11.0")
        let analysis = try decodeAnalysis("classification-analysis-review-v0.11.0")
        let api = ClassificationReviewAPISpy(
            listResponses: [page],
            analyzeResults: [
                .failure(.server(status: 503, code: "CLASSIFICATION_AI_UNAVAILABLE", message: "AI unavailable")),
                .success(analysis)
            ]
        )
        let store = ClassificationReviewStore(api: api)
        await store.restoreSession(accountBookId: "11")
        let item = try XCTUnwrap(store.items.first)

        await store.analyze(item, aiAvailable: true)
        XCTAssertTrue(store.message?.contains("人工复核") == true)
        await store.analyze(item, aiAvailable: true)

        let commands = await api.capturedAnalyzeCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], commands[1])
        XCTAssertEqual(store.analyses[item.id]?.status, .review)
    }

    func testRejectedHarnessResultFailsClosedWithoutCreatingDecision() async throws {
        let page = try decodeList("classification-reviews-pending-v0.11.0")
        let analysis = try decodeAnalysis("classification-analysis-rejected-v0.11.0")
        let api = ClassificationReviewAPISpy(listResponses: [page], analyzeResults: [.success(analysis)])
        let store = ClassificationReviewStore(api: api)
        await store.restoreSession(accountBookId: "11")
        let item = try XCTUnwrap(store.items.first)

        await store.analyze(item, aiAvailable: true)

        XCTAssertEqual(store.analyses[item.id]?.status, .rejected)
        XCTAssertTrue(store.message?.contains("失败关闭") == true)
        let decisions = await api.capturedDecisionCommands()
        XCTAssertEqual(decisions.count, 0)
    }

    func testForbiddenListProducesReadOnlyEmptyState() async {
        let api = ClassificationReviewAPISpy(
            listResponses: [],
            listErrors: [.server(status: 403, code: "CLASSIFICATION_REVIEW_FORBIDDEN", message: "当前角色没有分类复核权限")]
        )
        let store = ClassificationReviewStore(api: api)

        await store.restoreSession(accountBookId: "11")

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.message, "当前角色没有分类复核权限")
    }

    private func decodeList(_ name: String) throws -> ClassificationReviewListResponse {
        try decode(ClassificationReviewListResponse.self, name)
    }

    private func decodeAnalysis(_ name: String) throws -> ClassificationAnalysisResponse {
        try decode(ClassificationAnalysisResponse.self, name)
    }

    private func decodeDecision(_ name: String) throws -> ClassificationDecisionResponse {
        try decode(ClassificationDecisionResponse.self, name)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

private actor ClassificationReviewAPISpy: ClassificationReviewAPI {
    private var listResponses: [ClassificationReviewListResponse]
    private var listErrors: [APIError]
    private var analyzeResults: [Result<ClassificationAnalysisResponse, APIError>]
    private var decisionResults: [Result<ClassificationDecisionResponse, APIError>]
    private var listQueries: [ClassificationReviewQuery] = []
    private var analyzeCommands: [ClassificationAnalyzeCommand] = []
    private var decisionCommands: [ClassificationDecisionCommand] = []

    init(
        listResponses: [ClassificationReviewListResponse],
        listErrors: [APIError] = [],
        analyzeResults: [Result<ClassificationAnalysisResponse, APIError>] = [],
        decisionResults: [Result<ClassificationDecisionResponse, APIError>] = []
    ) {
        self.listResponses = listResponses
        self.listErrors = listErrors
        self.analyzeResults = analyzeResults
        self.decisionResults = decisionResults
    }

    func capturedListQueries() -> [ClassificationReviewQuery] { listQueries }
    func capturedAnalyzeCommands() -> [ClassificationAnalyzeCommand] { analyzeCommands }
    func capturedDecisionCommands() -> [ClassificationDecisionCommand] { decisionCommands }

    func list(_ query: ClassificationReviewQuery) async throws -> ClassificationReviewListResponse {
        listQueries.append(query)
        if !listErrors.isEmpty { throw listErrors.removeFirst() }
        guard !listResponses.isEmpty else { throw APIError.invalidResponse }
        if listResponses.count == 1 { return listResponses[0] }
        return listResponses.removeFirst()
    }

    func analyze(_ command: ClassificationAnalyzeCommand) async throws -> ClassificationAnalysisResponse {
        analyzeCommands.append(command)
        guard !analyzeResults.isEmpty else { throw APIError.invalidResponse }
        return try analyzeResults.removeFirst().get()
    }

    func decide(_ command: ClassificationDecisionCommand) async throws -> ClassificationDecisionResponse {
        decisionCommands.append(command)
        guard !decisionResults.isEmpty else { throw APIError.invalidResponse }
        return try decisionResults.removeFirst().get()
    }
}
