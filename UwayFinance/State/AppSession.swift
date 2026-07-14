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
    @Published var alertMessage: String?

    private let api: any FinanceAPI
    private let saveDelay: Duration
    private var didStart = false
    private var pendingSave: Task<Void, Never>?
    private var unsavedSnapshot: AppStatePayload?
    private var conflictingServerRevision: StateRevision?

    var importAnalysisCapability: ImportAnalysisCapability {
        guard case .available(let contract) = serverState else { return .serviceUnavailable }
        return contract.capabilities.importAnalysis
    }

    init(api: any FinanceAPI, saveDelay: Duration = .milliseconds(650)) {
        self.api = api
        self.saveDelay = saveDelay
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

    func login(username: String, password: String) async throws {
        user = try await api.login(username: username, password: password)
        alertMessage = nil
        phase = .signedIn
        try await refresh()
    }

    func logout() async {
        pendingSave?.cancel()
        try? await api.logout()
        state = .empty
        unsavedSnapshot = nil
        stateRevision = .empty
        conflictingServerRevision = nil
        user = nil
        syncState = .idle
        phase = .signedOut
    }

    func refresh() async throws {
        if unsavedSnapshot != nil {
            await recoverSync()
            return
        }
        syncState = .syncing
        do {
            let envelope = try await api.fetchState()
            state = envelope.data
            stateRevision = StateRevision(updatedAt: envelope.updatedAt)
            conflictingServerRevision = nil
            syncState = .synced(Date())
        } catch APIError.unauthorized {
            handleUnauthorized()
            throw APIError.unauthorized
        } catch {
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
        syncState = .syncing
        do {
            let envelope = try await api.fetchState()
            stateRevision = StateRevision(updatedAt: envelope.updatedAt)
            conflictingServerRevision = nil
            guard let latestLocalSnapshot = unsavedSnapshot else { return }
            await save(latestLocalSnapshot)
        } catch APIError.unauthorized {
            handleUnauthorized()
        } catch {
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
        do {
            user = try await api.currentUser()
            phase = .signedIn
            try await refresh()
        } catch APIError.unauthorized {
            phase = .signedOut
        } catch {
            markServerUnavailableIfNeeded(error)
            alertMessage = error.localizedDescription
            phase = .signedOut
        }
    }

    private func save(_ snapshot: AppStatePayload) async {
        syncState = .syncing
        let revision = stateRevision
        do {
            let savedRevision = try await api.saveState(snapshot, ifMatch: revision)
            stateRevision = savedRevision
            conflictingServerRevision = nil
            if unsavedSnapshot == snapshot { unsavedSnapshot = nil }
            syncState = unsavedSnapshot == nil ? .synced(Date()) : .syncing
        } catch APIError.unauthorized {
            handleUnauthorized()
        } catch APIError.stateVersionConflict(let currentUpdatedAt) {
            pendingSave?.cancel()
            conflictingServerRevision = StateRevision(updatedAt: currentUpdatedAt)
            unsavedSnapshot = unsavedSnapshot ?? snapshot
            syncState = .conflict("其他设备已更新，需要核对")
        } catch {
            markServerUnavailableIfNeeded(error)
            syncState = .failed(error.localizedDescription)
        }
    }

    private func handleUnauthorized() {
        pendingSave?.cancel()
        state = .empty
        unsavedSnapshot = nil
        stateRevision = .empty
        conflictingServerRevision = nil
        user = nil
        phase = .signedOut
        syncState = .failed("登录已失效")
    }

    private func markServerUnavailableIfNeeded(_ error: Error) {
        if let apiError = error as? APIError, case .transport = apiError {
            serverState = .unavailable(error.localizedDescription)
        }
    }
}
