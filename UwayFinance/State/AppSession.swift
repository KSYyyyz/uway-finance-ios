import Combine
import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum Phase: Equatable { case starting, signedOut, signedIn }
    enum SyncState: Equatable { case idle, syncing, synced(Date), failed(String), conflict(String) }
    enum ServerState: Equatable {
        case checking
        case available(BackendContract)
        case unavailable(String)
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var user: SessionUser?
    @Published var state: AppStatePayload = .empty
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var serverState: ServerState = .checking
    @Published private(set) var stateRevision: StateRevision = .empty
    @Published private(set) var sessionScopeID = UUID()
    @Published var alertMessage: String?

    private let api: any FinanceAPI
    private let saveDelay: Duration
    private var didStart = false
    private var pendingSave: Task<Void, Never>?
    private var unsavedSnapshot: AppStatePayload?
    private var conflictingServerRevision: StateRevision?
    private var sessionGeneration: UInt64 = 0
    private let onSessionScopeCleared: @MainActor () -> Void

    var importAnalysisCapability: ImportAnalysisCapability {
        guard case .available(let contract) = serverState else { return .serviceUnavailable }
        return contract.capabilities.importAnalysis
    }

    var registrationCapability: RegistrationCapability {
        guard case .available(let contract) = serverState else { return .unavailableFallback }
        return contract.capabilities.registration
    }

    var authenticationCapability: AuthenticationCapability {
        guard case .available(let contract) = serverState else { return .unavailableFallback }
        return contract.capabilities.authentication
    }

    var passwordRecoveryCapability: PasswordRecoveryCapability {
        guard case .available(let contract) = serverState else { return .unavailableFallback }
        return contract.capabilities.passwordRecovery
    }

    init(
        api: any FinanceAPI,
        saveDelay: Duration = .milliseconds(650),
        onSessionScopeCleared: @escaping @MainActor () -> Void = {}
    ) {
        self.api = api
        self.saveDelay = saveDelay
        self.onSessionScopeCleared = onSessionScopeCleared
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        await checkServer()
        guard case .available = serverState else {
            phase = .signedOut
            return
        }
        await restoreSession()
    }

    func retryConnection() async {
        await checkServer()
        guard case .available = serverState, phase == .signedOut else { return }
        await restoreSession()
    }

    func checkServer() async {
        serverState = .checking
        do {
            let health = try await api.health()
            let negotiated = try? await api.capabilities()
            serverState = .available(BackendContract(health: health, negotiated: negotiated))
            alertMessage = nil
        } catch {
            serverState = .unavailable(error.localizedDescription)
            alertMessage = error.localizedDescription
        }
    }

    func login(identifier: String, password: String) async throws {
        let generation = beginSessionTransition()
        do {
            let authenticatedUser = try await api.login(
                identifier: identifier,
                password: password,
                useLegacyUsernameField: !authenticationCapability.safeForIdentifierLogin
            )
            try await establishAuthenticatedSession(user: authenticatedUser, generation: generation)
        } catch {
            if generation == sessionGeneration { phase = .signedOut }
            throw error
        }
    }

    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponse {
        guard registrationCapability.supportsIdentityContract else {
            throw APIError.unavailable("当前服务器未开放用户名实时检查")
        }
        return try await api.usernameAvailability(UsernameAvailabilityRequest(username: username))
    }

    func requestRegistrationCode(phone: String) async throws -> RegistrationCodeResponse {
        guard registrationCapability.safeForVerifiedEmailRegistration else {
            throw APIError.unavailable(registrationCapability.unavailableMessage)
        }
        return try await api.requestRegistrationCode(phone: phone)
    }

    func requestRegistrationEmailCode(email: String) async throws -> RegistrationEmailCodeResponse {
        guard registrationCapability.safeForVerifiedEmailRegistration else {
            throw APIError.unavailable(registrationCapability.unavailableMessage)
        }
        return try await api.requestRegistrationEmailCode(email: email)
    }

    func register(_ request: RegistrationRequest) async throws {
        guard registrationCapability.safeForVerifiedEmailRegistration else {
            throw APIError.unavailable(registrationCapability.unavailableMessage)
        }
        let generation = beginSessionTransition()
        do {
            let response = try await api.register(request)
            try await establishAuthenticatedSession(user: response.user, generation: generation)
        } catch {
            if generation == sessionGeneration { phase = .signedOut }
            throw error
        }
    }

    func requestPasswordReset(email: String) async throws -> PasswordResetChallengeResponse {
        guard passwordRecoveryCapability.safeForClientUse else {
            throw APIError.unavailable(passwordRecoveryCapability.unavailableMessage)
        }
        return try await api.requestPasswordReset(PasswordResetRequest(email: email))
    }

    func confirmPasswordReset(_ request: PasswordResetConfirmRequest) async throws -> PasswordResetConfirmResponse {
        guard passwordRecoveryCapability.safeForClientUse else {
            throw APIError.unavailable(passwordRecoveryCapability.unavailableMessage)
        }
        let generation = beginSessionTransition()
        phase = .signedOut
        do {
            let response = try await api.confirmPasswordReset(request)
            guard generation == sessionGeneration else {
                throw APIError.unavailable("密码重置请求已被新的账号操作替代")
            }
            alertMessage = nil
            return response
        } catch {
            if generation == sessionGeneration { phase = .signedOut }
            throw error
        }
    }

    func logout() async {
        let generation = beginSessionTransition()
        phase = .signedOut
        try? await api.logout()
        guard generation == sessionGeneration else { return }
    }

    func refresh() async throws {
        if unsavedSnapshot != nil {
            await recoverSync()
            return
        }
        let generation = sessionGeneration
        let expectedUserID = user?.id
        syncState = .syncing
        do {
            let envelope = try await api.fetchState()
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            state = envelope.data
            stateRevision = StateRevision(updatedAt: envelope.updatedAt)
            conflictingServerRevision = nil
            syncState = .synced(Date())
        } catch APIError.unauthorized {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            handleUnauthorized()
            throw APIError.unauthorized
        } catch {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            markServerUnavailableIfNeeded(error)
            syncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func addRecord(_ record: BusinessRecord) {
        state.records.insert(record, at: 0)
        queueSave()
    }

    func importRecords(_ records: [BusinessRecord], fileName: String, duplicateCount: Int, errorCount: Int) {
        guard !records.isEmpty else { return }
        state.records.insert(contentsOf: records, at: 0)
        queueSave()
        audit(AuditEventRequest(
            action: .recordCSVImport,
            count: records.count,
            duplicateCount: duplicateCount,
            errorCount: errorCount,
            fileName: fileName
        ))
    }

    func updateRecord(_ record: BusinessRecord) {
        guard let index = state.records.firstIndex(where: { $0.id == record.id }) else { return }
        state.records[index] = record
        queueSave()
    }

    func toggleCloseItem(_ id: String) {
        if state.completedClose.contains(id) {
            state.completedClose.removeAll { $0 == id }
        } else {
            state.completedClose.append(id)
        }
        queueSave()
    }

    func resolve(_ item: PendingItem) {
        guard let index = state.records.firstIndex(where: { $0.id == item.recordId }) else { return }
        switch item.kind {
        case .settlement:
            state.records[index].settlementStatus = .settled
        case .material:
            if state.records[index].invoiceStatus == .pending { state.records[index].invoiceStatus = .received }
            if state.records[index].contractStatus == .missing { state.records[index].contractStatus = .attached }
            if state.records[index].supportingDocumentStatus == .pending { state.records[index].supportingDocumentStatus = .complete }
        case .reconciliation:
            break
        case .bookkeeping:
            state.records[index].financeStatus = .submitted
        }
        queueSave()
    }

    func audit(_ event: AuditEventRequest) {
        Task { try? await api.audit(event) }
    }

    func recoverSync() async {
        guard conflictingServerRevision == nil else { return }
        if case .unavailable = serverState {
            await checkServer()
            guard case .available = serverState else { return }
        }
        if let snapshot = unsavedSnapshot {
            await save(snapshot)
        } else {
            try? await refresh()
        }
    }

    func resolveStateConflictAndRetry() async {
        guard conflictingServerRevision != nil, unsavedSnapshot != nil else { return }
        let generation = sessionGeneration
        let expectedUserID = user?.id
        syncState = .syncing
        do {
            let envelope = try await api.fetchState()
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            stateRevision = StateRevision(updatedAt: envelope.updatedAt)
            conflictingServerRevision = nil
            guard let latestLocalSnapshot = unsavedSnapshot else { return }
            await save(latestLocalSnapshot)
        } catch APIError.unauthorized {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            handleUnauthorized()
        } catch {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            markServerUnavailableIfNeeded(error)
            syncState = .conflict("其他设备已更新，需要核对；暂时无法取得最新版本")
        }
    }

    func invalidateExternalSession() {
        handleUnauthorized()
    }

    private func queueSave() {
        pendingSave?.cancel()
        syncState = .syncing
        let snapshot = state
        unsavedSnapshot = snapshot
        if conflictingServerRevision != nil {
            syncState = .conflict("其他设备已更新，需要核对")
            return
        }
        pendingSave = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.saveDelay)
            guard !Task.isCancelled else { return }
            await self.save(snapshot)
        }
    }

    private func restoreSession() async {
        let generation = beginSessionTransition()
        do {
            let restoredUser = try await api.currentUser()
            try await establishAuthenticatedSession(user: restoredUser, generation: generation)
        } catch APIError.unauthorized {
            if generation == sessionGeneration { handleUnauthorized() }
        } catch {
            guard generation == sessionGeneration else { return }
            markServerUnavailableIfNeeded(error)
            alertMessage = error.localizedDescription
            phase = .signedOut
        }
    }

    private func save(_ snapshot: AppStatePayload) async {
        let generation = sessionGeneration
        let expectedUserID = user?.id
        syncState = .syncing
        let revision = stateRevision
        do {
            let savedRevision = try await api.saveState(snapshot, ifMatch: revision)
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            stateRevision = savedRevision
            conflictingServerRevision = nil
            if unsavedSnapshot == snapshot { unsavedSnapshot = nil }
            syncState = unsavedSnapshot == nil ? .synced(Date()) : .syncing
        } catch APIError.unauthorized {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            handleUnauthorized()
        } catch APIError.stateVersionConflict(let currentUpdatedAt) {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            pendingSave?.cancel()
            conflictingServerRevision = StateRevision(updatedAt: currentUpdatedAt)
            unsavedSnapshot = unsavedSnapshot ?? snapshot
            syncState = .conflict("其他设备已更新，需要核对")
        } catch {
            guard generation == sessionGeneration, expectedUserID == user?.id else { return }
            markServerUnavailableIfNeeded(error)
            syncState = .failed(error.localizedDescription)
        }
    }

    private func handleUnauthorized() {
        _ = beginSessionTransition()
        phase = .signedOut
        syncState = .failed("登录已失效")
    }

    private func establishAuthenticatedSession(user authenticatedUser: SessionUser, generation: UInt64) async throws {
        guard generation == sessionGeneration else {
            throw APIError.unavailable("登录请求已被新的账号切换替代")
        }
        let envelope = try await api.fetchState()
        guard generation == sessionGeneration else {
            throw APIError.unavailable("登录请求已被新的账号切换替代")
        }
        user = authenticatedUser
        state = envelope.data
        stateRevision = StateRevision(updatedAt: envelope.updatedAt)
        conflictingServerRevision = nil
        unsavedSnapshot = nil
        syncState = .synced(Date())
        alertMessage = nil
        phase = .signedIn
    }

    @discardableResult
    private func beginSessionTransition() -> UInt64 {
        sessionGeneration &+= 1
        pendingSave?.cancel()
        state = .empty
        unsavedSnapshot = nil
        stateRevision = .empty
        conflictingServerRevision = nil
        user = nil
        syncState = .idle
        sessionScopeID = UUID()
        onSessionScopeCleared()
        return sessionGeneration
    }

    private func markServerUnavailableIfNeeded(_ error: Error) {
        if let apiError = error as? APIError, case .transport = apiError {
            serverState = .unavailable(error.localizedDescription)
        }
    }
}
