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
            return XCTFail("0.14.0 server should be available")
        }
        XCTAssertEqual(contract.serverVersion, "0.14.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, BackendContract.apiContractVersion)
        XCTAssertEqual(contract.capabilities.source, .server)
        XCTAssertEqual(contract.capabilities.financeResources.cutoverState, "shadow")
        XCTAssertEqual(contract.capabilities.financeResources.cutoverReadiness?.available, true)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertEqual(contract.capabilities.classificationReview?.available, true)
        XCTAssertEqual(contract.capabilities.classificationPreferenceMemory?.safeForClientUse, true)
        XCTAssertEqual(contract.capabilities.classificationPreferenceMemory?.semanticV2SafeForClientUse, true)
        XCTAssertTrue(contract.capabilities.registration.safeForClientUse)
        XCTAssertTrue(contract.capabilities.documentUploadCapability.safeForClientUse)
        XCTAssertEqual(contract.financeSchemaVersion, BackendContract.multiTenantRegistrationSchema)
        XCTAssertEqual(session.state.records.count, 1)
        XCTAssertEqual(session.stateRevision, StateRevision(updatedAt: "2026-07-14T00:00:00.000Z"))
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

    func testBackendV0102SessionAndCapabilityFixturesRemainBackwardCompatible() async {
        let api = FinanceAPISpy(
            healthResponse: HealthResponse(
                status: "ok",
                version: "0.10.2",
                financeSchemaVersion: BackendContract.financeDomainV2Schema
            ),
            capabilitiesFixtureName: "capabilities-v0.10.2"
        )
        let session = AppSession(api: api, saveDelay: .zero)

        await session.start()

        XCTAssertEqual(session.phase, .signedIn)
        guard case .available(let contract) = session.serverState else {
            return XCTFail("historical 0.10.2 backend must remain usable")
        }
        XCTAssertEqual(contract.serverVersion, "0.10.2")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_004")
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
        XCTAssertNil(contract.capabilities.legacyState.conditionalWriteHeader)
        XCTAssertNil(contract.capabilities.classificationReview)
        XCTAssertEqual(session.stateRevision, StateRevision(updatedAt: "2026-07-14T00:00:00.000Z"))
    }

    func testBackendV011SessionRemainsCompatibleWithoutPreferenceMemoryCapability() async {
        let api = FinanceAPISpy(
            healthResponse: HealthResponse(
                status: "ok",
                version: "0.11.0",
                financeSchemaVersion: BackendContract.classificationReviewSchema
            ),
            capabilitiesFixtureName: "capabilities-classification-review-v0.11.0"
        )
        let session = AppSession(api: api, saveDelay: .zero)

        await session.start()

        guard case .available(let contract) = session.serverState else {
            return XCTFail("historical 0.11.0 backend must remain usable")
        }
        XCTAssertEqual(contract.serverVersion, "0.11.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260714_007")
        XCTAssertTrue(contract.capabilities.classificationReview?.available == true)
        XCTAssertNil(contract.capabilities.classificationPreferenceMemory)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
    }

    func testBackendV012SessionRemainsCompatibleWithoutImmutableEvidenceCapability() async {
        let api = FinanceAPISpy(
            healthResponse: HealthResponse(
                status: "ok",
                version: "0.12.0",
                financeSchemaVersion: BackendContract.classificationPreferenceMemorySchema
            ),
            capabilitiesFixtureName: "capabilities-preference-memory-v0.12.0"
        )
        let session = AppSession(api: api, saveDelay: .zero)

        await session.start()

        guard case .available(let contract) = session.serverState else {
            return XCTFail("historical 0.12.0 backend must remain usable")
        }
        XCTAssertEqual(contract.serverVersion, "0.12.0")
        XCTAssertEqual(contract.negotiatedAPIContractVersion, "20260715_008")
        XCTAssertTrue(contract.capabilities.classificationPreferenceMemory?.safeForClientUse == true)
        XCTAssertFalse(contract.capabilities.documentUploadCapability.safeForClientUse)
        XCTAssertEqual(contract.capabilities.syncMode, .legacyStateV1)
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
        let recorder = SessionClearRecorder()
        let session = AppSession(api: api, saveDelay: .zero) { recorder.record() }
        await session.start()
        let clearsBefore401 = recorder.count
        await api.setFetchError(.unauthorized)

        do {
            try await session.refresh()
            XCTFail("refresh should throw unauthorized")
        } catch APIError.unauthorized {
            XCTAssertEqual(session.phase, .signedOut)
            XCTAssertNil(session.user)
            XCTAssertEqual(session.state, .empty)
            XCTAssertEqual(recorder.count, clearsBefore401 + 1)
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

    func testContinuousSavesAdvanceAndReuseLatestRevision() async throws {
        let api = FinanceAPISpy(saveUpdatedAts: [
            "2026-07-15T00:01:00.000Z",
            "2026-07-15T00:02:00.000Z",
        ])
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()

        var record = makeSessionTestRecord()
        session.addRecord(record)
        try await Task.sleep(for: .milliseconds(50))
        record.description = "第二次本地编辑"
        session.updateRecord(record)
        try await Task.sleep(for: .milliseconds(50))

        let revisions = await api.attemptedSaveRevisions()
        XCTAssertEqual(revisions, [
            StateRevision(updatedAt: "2026-07-14T00:00:00.000Z"),
            StateRevision(updatedAt: "2026-07-15T00:01:00.000Z"),
        ])
        XCTAssertEqual(session.stateRevision, StateRevision(updatedAt: "2026-07-15T00:02:00.000Z"))
    }

    func testFirstEmptyLedgerSaveUsesZeroRevision() async throws {
        let api = FinanceAPISpy(
            fetchEnvelopes: [StateEnvelope(data: .empty, updatedAt: nil)],
            saveUpdatedAts: ["2026-07-15T00:01:00.000Z"]
        )
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()

        session.addRecord(makeSessionTestRecord())
        try await Task.sleep(for: .milliseconds(50))

        let revisions = await api.attemptedSaveRevisions()
        XCTAssertEqual(revisions, [.empty])
        XCTAssertEqual(session.stateRevision, StateRevision(updatedAt: "2026-07-15T00:01:00.000Z"))
    }

    func testStateConflictKeepsUnsavedLocalStateAndExplicitRetryUsesLatestRevision() async throws {
        let remoteOriginal = makeSessionState(description: "服务器旧内容")
        let remoteChanged = makeSessionState(description: "其他设备新内容")
        let api = FinanceAPISpy(
            fetchEnvelopes: [
                StateEnvelope(data: remoteOriginal, updatedAt: "2026-07-15T00:00:00.000Z"),
                StateEnvelope(data: remoteChanged, updatedAt: "2026-07-15T00:01:00.000Z"),
            ],
            saveUpdatedAts: ["2026-07-15T00:02:00.000Z"]
        )
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        await api.setSaveError(.stateVersionConflict(currentUpdatedAt: "2026-07-15T00:01:00.000Z"))

        var localRecord = makeSessionTestRecord()
        localRecord.description = "本机尚未同步的修改"
        session.updateRecord(localRecord)
        try await Task.sleep(for: .milliseconds(50))

        guard case .conflict(let message) = session.syncState else {
            return XCTFail("stale conditional write must enter conflict state")
        }
        XCTAssertEqual(message, "其他设备已更新，需要核对")
        XCTAssertEqual(session.state.records.first?.description, "本机尚未同步的修改")
        await api.setSaveError(nil)

        await session.resolveStateConflictAndRetry()

        XCTAssertEqual(session.state.records.first?.description, "本机尚未同步的修改")
        let revisions = await api.attemptedSaveRevisions()
        XCTAssertEqual(revisions, [
            StateRevision(updatedAt: "2026-07-15T00:00:00.000Z"),
            StateRevision(updatedAt: "2026-07-15T00:01:00.000Z"),
        ])
        let saved = await api.lastSavedState()
        XCTAssertEqual(saved?.records.first?.description, "本机尚未同步的修改")
        XCTAssertEqual(session.stateRevision, StateRevision(updatedAt: "2026-07-15T00:02:00.000Z"))
        guard case .synced = session.syncState else {
            return XCTFail("explicit conflict resolution should complete the pending save")
        }
    }

    func testConflictPausesAutomaticSavesUntilExplicitResolution() async throws {
        let api = FinanceAPISpy()
        let session = AppSession(api: api, saveDelay: .zero)
        await session.start()
        await api.setSaveError(.stateVersionConflict(currentUpdatedAt: "2026-07-15T00:01:00.000Z"))
        var record = makeSessionTestRecord()
        record.description = "第一次本机修改"
        session.updateRecord(record)
        try await Task.sleep(for: .milliseconds(50))

        record.description = "冲突后的继续编辑"
        session.updateRecord(record)
        try await Task.sleep(for: .milliseconds(50))

        let revisions = await api.attemptedSaveRevisions()
        XCTAssertEqual(revisions.count, 1)
        XCTAssertEqual(session.state.records.first?.description, "冲突后的继续编辑")
        guard case .conflict = session.syncState else {
            return XCTFail("local edits must remain paused behind explicit conflict resolution")
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

    func testRegistrationCreatesAuthenticatedIsolatedSessionWithoutPersistingSecrets() async throws {
        let empty = StateEnvelope(data: .empty, updatedAt: nil)
        let api = FinanceAPISpy(fetchEnvelopes: [empty])
        let session = AppSession(api: api, saveDelay: .zero)
        await session.checkServer()

        let challenge = try await session.requestRegistrationCode(phone: "+8613800138000")
        XCTAssertEqual(challenge.expiresInSeconds, 300)
        XCTAssertEqual(challenge.resendAfterSeconds, 60)
        try await session.register(RegistrationRequest(
            username: "new_owner",
            password: "SecurePass2026",
            phone: "+8613800138000",
            challengeId: challenge.challengeId,
            code: "246810"
        ))

        XCTAssertEqual(session.phase, .signedIn)
        XCTAssertEqual(session.user, SessionUser(id: "201", username: "new_owner"))
        XCTAssertEqual(session.state, .empty)
        XCTAssertEqual(session.stateRevision, .empty)
        let request = await api.lastRegistrationRequest()
        XCTAssertEqual(request?.challengeId, challenge.challengeId)
        XCTAssertEqual(request?.code, "246810")
    }

    func testSlowLoginAResponseCannotOverwriteNewerUserB() async throws {
        let api = FinanceAPISpy(
            fetchEnvelopes: [StateEnvelope(
                data: makeSessionState(description: "B 的独立账套"),
                updatedAt: "2026-07-16T01:00:00.000Z"
            )],
            loginDelays: ["user-a": .milliseconds(120), "user-b": .milliseconds(10)]
        )
        let session = AppSession(api: api, saveDelay: .zero)
        await session.checkServer()

        async let oldAttempt: Void = session.login(username: "user-a", password: "PasswordA1")
        try await Task.sleep(for: .milliseconds(15))
        async let newAttempt: Void = session.login(username: "user-b", password: "PasswordB1")
        _ = try? await oldAttempt
        try await newAttempt

        XCTAssertEqual(session.user, SessionUser(id: "id-user-b", username: "user-b"))
        XCTAssertEqual(session.state.records.first?.description, "B 的独立账套")
        XCTAssertEqual(session.phase, .signedIn)
    }

    func testLogoutClearsStateConflictAndAllRegisteredSessionCaches() async {
        let api = FinanceAPISpy()
        let recorder = SessionClearRecorder()
        let session = AppSession(api: api, saveDelay: .zero) { recorder.record() }
        await session.start()
        let oldScope = session.sessionScopeID
        let clearsBeforeLogout = recorder.count

        await session.logout()

        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertNil(session.user)
        XCTAssertEqual(session.state, .empty)
        XCTAssertEqual(session.stateRevision, .empty)
        XCTAssertNotEqual(session.sessionScopeID, oldScope)
        XCTAssertEqual(recorder.count, clearsBeforeLogout + 1)
    }
}

@MainActor
private final class SessionClearRecorder {
    private(set) var count = 0
    func record() { count += 1 }
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

private func makeSessionState(description: String) -> AppStatePayload {
    var record = makeSessionTestRecord()
    record.description = description
    return AppStatePayload(records: [record], bankTransactions: [], completedLessons: [], completedClose: [])
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
    private var fetchEnvelopes: [StateEnvelope]
    private var saveUpdatedAts: [String]
    private var saveRevisions: [StateRevision] = []
    private var registrationRequests: [RegistrationRequest] = []
    private let loginDelays: [String: Duration]

    init(healthResponse: HealthResponse = HealthResponse(
        status: "ok",
        version: "0.14.0",
        financeSchemaVersion: BackendContract.multiTenantRegistrationSchema
    ), capabilitiesFixtureName: String = "capabilities-semantic-preference-memory-v0.14.0",
       fetchEnvelopes: [StateEnvelope] = [StateEnvelope(
        data: makeSessionState(description: "待重试事项"),
        updatedAt: "2026-07-14T00:00:00.000Z"
       )],
       saveUpdatedAts: [String] = ["2026-07-14T00:00:01.000Z"],
       loginDelays: [String: Duration] = [:]) {
        self.healthResponse = healthResponse
        self.capabilitiesFixtureName = capabilitiesFixtureName
        self.fetchEnvelopes = fetchEnvelopes
        self.saveUpdatedAts = saveUpdatedAts
        self.loginDelays = loginDelays
    }

    func setFetchError(_ error: APIError?) { fetchError = error }
    func setSaveError(_ error: APIError?) { saveError = error }
    func setCapabilitiesError(_ error: APIError?) { capabilitiesError = error }
    func lastSavedState() -> AppStatePayload? { savedStates.last }
    func lastAuditEvent() -> AuditEventRequest? { auditEvents.last }
    func fetchStateCallCount() -> Int { fetchStateCalls }
    func attemptedSaveRevisions() -> [StateRevision] { saveRevisions }
    func lastRegistrationRequest() -> RegistrationRequest? { registrationRequests.last }

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
        if let delay = loginDelays[username] { try await Task.sleep(for: delay) }
        return SessionUser(id: loginDelays.isEmpty ? "user-001" : "id-\(username)", username: username)
    }

    func requestRegistrationCode(phone: String) async throws -> RegistrationCodeResponse {
        RegistrationCodeResponse(
            ok: true,
            challengeId: "challenge-20260716-abcdefghijklmnop",
            expiresInSeconds: 300,
            resendAfterSeconds: 60
        )
    }

    func register(_ request: RegistrationRequest) async throws -> RegistrationResponse {
        registrationRequests.append(request)
        return RegistrationResponse(
            user: SessionUser(id: "201", username: request.username),
            organizationId: "301",
            accountBookId: "401"
        )
    }

    func currentUser() async throws -> SessionUser {
        SessionUser(id: "user-001", username: "finance-admin")
    }

    func logout() async throws {}

    func fetchState() async throws -> StateEnvelope {
        if let fetchError { throw fetchError }
        fetchStateCalls += 1
        guard !fetchEnvelopes.isEmpty else { throw APIError.invalidResponse }
        if fetchEnvelopes.count == 1 { return fetchEnvelopes[0] }
        return fetchEnvelopes.removeFirst()
    }

    func saveState(_ state: AppStatePayload, ifMatch revision: StateRevision) async throws -> StateRevision {
        saveRevisions.append(revision)
        if let saveError { throw saveError }
        savedStates.append(state)
        guard !saveUpdatedAts.isEmpty else { throw APIError.invalidResponse }
        let updatedAt = saveUpdatedAts.count == 1 ? saveUpdatedAts[0] : saveUpdatedAts.removeFirst()
        return StateRevision(updatedAt: updatedAt)
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
