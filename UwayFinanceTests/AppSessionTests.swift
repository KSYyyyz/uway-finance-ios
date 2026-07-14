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
        XCTAssertEqual(session.serverState, .available(version: "0.8.1"))
        XCTAssertEqual(session.state.records.count, 1)
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
    private var fetchError: APIError?
    private var saveError: APIError?
    private var savedStates: [AppStatePayload] = []
    private var auditEvents: [AuditEventRequest] = []

    func setFetchError(_ error: APIError?) { fetchError = error }
    func setSaveError(_ error: APIError?) { saveError = error }
    func lastSavedState() -> AppStatePayload? { savedStates.last }
    func lastAuditEvent() -> AuditEventRequest? { auditEvents.last }

    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok", version: "0.8.1")
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
