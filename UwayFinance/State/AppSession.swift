import Combine
import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum Phase: Equatable { case starting, signedOut, signedIn }
    enum SyncState: Equatable { case idle, syncing, synced(Date), failed(String) }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var user: SessionUser?
    @Published var state: AppStatePayload = .empty
    @Published private(set) var syncState: SyncState = .idle
    @Published var alertMessage: String?

    private let api: any FinanceAPI
    private var didStart = false
    private var pendingSave: Task<Void, Never>?

    init(api: any FinanceAPI) { self.api = api }

    func start() async {
        guard !didStart else { return }
        didStart = true
        do {
            user = try await api.currentUser()
            phase = .signedIn
            try await refresh()
        } catch APIError.unauthorized {
            phase = .signedOut
        } catch {
            alertMessage = error.localizedDescription
            phase = .signedOut
        }
    }

    func login(username: String, password: String) async throws {
        user = try await api.login(username: username, password: password)
        phase = .signedIn
        try await refresh()
    }

    func logout() async {
        pendingSave?.cancel()
        try? await api.logout()
        state = .empty
        user = nil
        syncState = .idle
        phase = .signedOut
    }

    func refresh() async throws {
        syncState = .syncing
        do {
            let envelope = try await api.fetchState()
            state = envelope.data
            syncState = .synced(Date())
        } catch {
            syncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func addRecord(_ record: BusinessRecord) {
        state.records.insert(record, at: 0)
        queueSave()
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

    private func queueSave() {
        pendingSave?.cancel()
        syncState = .syncing
        let snapshot = state
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            do {
                _ = try await self.api.saveState(snapshot)
                guard !Task.isCancelled else { return }
                self.syncState = .synced(Date())
            } catch APIError.unauthorized {
                self.user = nil
                self.phase = .signedOut
                self.syncState = .failed("登录已失效")
            } catch {
                self.syncState = .failed(error.localizedDescription)
            }
        }
    }
}
