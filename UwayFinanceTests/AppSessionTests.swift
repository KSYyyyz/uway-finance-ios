import XCTest
@testable import UwayFinance

@MainActor
final class AppSessionTests: XCTestCase {
    func testStartRestoresSessionStateAndServerVersion() async {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)

        await session.start()

        XCTAssertEqual(session.phase, .signedIn)
        XCTAssertEqual(session.user?.username, "finance-admin")
        guard case .available(let contract) = session.serverState else {
            return XCTFail("0.10.2 server should be available")
        }
        XCTAssertEqual(contract.serverVersion, "0.10.2")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, BackendContract.apiContractVersion)
        XCTAssertEqual(contract.capabilities.source, .server)
        XCTAssertEqual(contract.capabilities.financeResources.cutoverState, "shadow")
        XCTAssertEqual(contract.capabilities.financeResources.cutoverReadiness?.available, true)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.classificationReview?.available, true)
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.classificationReviewSchema)
        XCTAssertEqual(session.state.records.count, 1)
        let fetchStateCallCount = await api.fetchStateCallCount()
        XCTAssertEqual(fetchStateCallCount, 1)
    }

    func testCapabilities404KeepsLegacyServerUsable() async {
        let api = FinanceAPISpy(healthResponse: HealthResponse(status: "ok", version: "0.8.1"))
        await api.setCapabilitiesError(.server(status: 404, code: nil, message: "Not Found"))
        let session = AppSession(api: api, saveDelay: .zero)

        await session.start()

        XCTAssertEqual(session.phase, .signedIn)
        guard case .available(let contract) = session.serverState else {
            return XCTFail("missing capabilities endpoint must not mark an old server offline")
        }
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.source, .legacyFallback)
        XCTAssertNil(contract.negotiatedAPIContractVersion)
        XCTAssertNil(contract.financeSchemaVersion)
    }

    func testUnavailableImportCapabilityBlocksAnalysisRequest() async throws {
        let api = FinanceAPISpy(
            healthResponse: HealthResponse(
                status: "ok",
                version: "0.9.0",
                financeSchemaVersion: "20260714_001_finance_domain_v2"
            ),
            capabilitiesFixtureName: "capabilities-v0.9.0-import-disabled"
        )
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()

        let csv = "日期,收支方向,金额,交易对方,事项说明,是否公司账目\n2026-07-14,支出,2480,示例云服务商,云服务器费用,是"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("uway-disabled-import-\(UUID().uuidString).csv")
        try Data(csv.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let importSession = RecordImportSession()
        await importSession.load(url: url, existing: session.state.records)
        XCTAssertTrue(importSession.canAnalyze)

        let importAPI = ImportAnalysisAPISpy()
        await importSession.analyze(using: importAPI, session: session)

        let analyzeCallCount = await importAPI.analyzeCallCount()
        XCTAssertEqual(analyzeCallCount, 0)
        XCTAssertEqual(importSession.message, "服务器尚未配置 DeepSeek 分析服务，暂时不能进行 AI 核验。")
    }

    func testUnauthorizedRefreshReturnsToLogin() async {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        await api.setFetchError(.unauthorized)

        do {
            try await session.refresh()
            XCTFail("refresh should throw unauthorized")
        } catch APIError.unauthorized {
            XCTAssertEqual(session.phase, .signedOut)
            XCTAssertNil(session.user)
            XCTAssertEqual(session.state, .empty)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testLoginLoadsCurrentLegacyState() async throws {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)

        try await session.login(username: "finance-admin", password: "secret")

        XCTAssertEqual(session.phase, .signedIn)
        XCTAssertEqual(session.user?.username, "finance-admin")
        XCTAssertEqual(session.state.records.first?.id, "local-001")
    }

    func testFailedSaveRetriesLocalSnapshot() async throws {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        await api.setSaveError(.transport("offline"))

        let record = makeSessionTestRecord()
        session.addRecord(record)
        try await Task.sleep(for: .milliseconds(50))
        guard case .failed = session.syncState else {
            return XCTFail("save should expose a recoverable failure")
        }

        await api.setSaveError(nil)
        await session.recoverSync()

        let saved = await api.lastSavedState()
        XCTAssertEqual(saved?.records.first?.id, record.id)
        guard case .synced = session.syncState else {
            return XCTFail("retry should finish in synced state")
        }
    }

    func testDashboardMetricsFailureCannotOverwriteUnsavedLegacyState() async throws {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        await api.setSaveError(.transport("offline"))
        let localRecord = makeSessionTestRecord()
        session.addRecord(localRecord)
        try await Task.sleep(for: .milliseconds(50))

        do {
            _ = try await DashboardMetricsAPISpy().metrics(DashboardMetricsQuery(period: "2026-07"))
            XCTFail("diagnostic failure should be surfaced")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "DASHBOARD_METRICS_FORBIDDEN")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertEqual(session.state.records.first?.id, localRecord.id)
        guard case .failed = session.syncState else {
            return XCTFail("unsaved /api/state snapshot must remain recoverable")
        }
    }

    func testImportRecordsSavesOneBatchAndAuditsProvenance() async throws {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        let record = makeSessionTestRecord()

        session.importRecords([record], fileName: "records.csv", duplicateCount: 2, errorCount: 1)
        try await Task.sleep(for: .milliseconds(50))

        let saved = await api.lastSavedState()
        XCTAssertEqual(saved?.records.first?.id, record.id)
        let event = await api.lastAuditEvent()
        XCTAssertEqual(event?.action, .recordCSVImport)
        XCTAssertEqual(event?.count, 1)
        XCTAssertEqual(event?.duplicateCount, 2)
        XCTAssertEqual(event?.errorCount, 1)
        XCTAssertEqual(event?.fileName, "records.csv")
    }
}

private func makeSessionTestRecord() -> BusinessRecord {
    BusinessRecord(
        id: "local-001",
        date: "2026-07-14",
        direction: .expense,
        amount: 360,
        category: "软件服务",
        counterparty: "测试供应商",
        project: "Uway",
        account: "公司银行",
        settlementStatus: .settled,
        invoiceStatus: .pending,
        financeStatus: .draft,
        contractStatus: .notRequired,
        description: "待重试事项"
    )
}

private actor FinanceAPISpy: FinanceAPI {
    private let healthResponse: HealthResponse
    private let capabilitiesFixtureName: String
    private var fetchError: APIError?
    private var saveError: APIError?
    private var capabilitiesError: APIError?
    private var savedStates: [AppStatePayload] = []
    private var auditEvents: [AuditEventRequest] = []
    private var fetchStateCalls = 0

    init(healthResponse: HealthResponse = HealthResponse(
        status: "ok",
        version: "0.10.2",
        financeSchemaVersion: BackendContract.classificationReviewSchema
    ), capabilitiesFixtureName: String = "capabilities-classification-review-v0.11.0") {
        self.healthResponse = healthResponse
        self.capabilitiesFixtureName = capabilitiesFixtureName
    }

    func setFetchError(_ error: APIError?) { fetchError = error }
    func setSaveError(_ error: APIError?) { saveError = error }
    func setCapabilitiesError(_ error: APIError?) { capabilitiesError = error }
    func lastSavedState() -> AppStatePayload? { savedStates.last }
    func lastAuditEvent() -> AuditEventRequest? { auditEvents.last }
    func fetchStateCallCount() -> Int { fetchStateCalls }

    func health() async throws -> HealthResponse {
        healthResponse
    }

    func capabilities() async throws -> ServerCapabilitiesResponse {
        if let capabilitiesError { throw capabilitiesError }
        let bundle = Bundle(for: AppSessionTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: capabilitiesFixtureName, withExtension: "json"))
        return try JSONDecoder().decode(ServerCapabilitiesResponse.self, from: Data(contentsOf: url))
    }

    func login(username: String, password: String) async throws -> SessionUser {
        SessionUser(id: "user-001", username: username)
    }

    func currentUser() async throws -> SessionUser {
        SessionUser(id: "user-001", username: "finance-admin")
    }

    func logout() async throws {}

    func fetchState() async throws -> StateEnvelope {
        if let fetchError { throw fetchError }
        fetchStateCalls += 1
        return StateEnvelope(
            data: AppStatePayload(
                records: [makeSessionTestRecord()],
                bankTransactions: [],
                completedLessons: [],
                completedClose: []
            ),
            updatedAt: "2026-07-14T00:00:00.000Z"
        )
    }

    func saveState(_ state: AppStatePayload) async throws -> String {
        if let saveError { throw saveError }
        savedStates.append(state)
        return "2026-07-14T00:00:00.000Z"
    }

    func audit(_ event: AuditEventRequest) async throws { auditEvents.append(event) }
}

private actor ImportAnalysisAPISpy: ImportAnalysisAPI {
    private var analyzeCalls = 0

    func analyzeCallCount() -> Int { analyzeCalls }

    func analyze(_ request: ImportAnalysisRequest) async throws -> HarnessResult {
        analyzeCalls += 1
        throw APIError.unavailable("test should not reach transport")
    }

    func decide(analysisId: String, decision: ImportReviewDecision) async throws -> ImportReviewDecisionResponse {
        throw APIError.unavailable("test should not reach transport")
    }
}

private actor DashboardMetricsAPISpy: DashboardMetricsAPI {
    func metrics(_ query: DashboardMetricsQuery) async throws -> DashboardMetricsResponse {
        throw APIError.server(
            status: 403,
            code: "DASHBOARD_METRICS_FORBIDDEN",
            message: "当前角色无权查看全账套经营指标"
        )
    }
}
