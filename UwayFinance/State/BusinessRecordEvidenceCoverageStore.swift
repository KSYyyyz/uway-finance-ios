import Combine
import Foundation

@MainActor
final class BusinessRecordEvidenceCoverageStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case available
        case failed(String)
    }

    @Published private(set) var accountBook: FinanceAccountBookAccess?
    @Published private(set) var records: [String: BusinessRecordEvidenceCoverage] = [:]
    @Published private(set) var loadState: LoadState = .idle

    private let api: any BusinessRecordEvidenceAPI
    private var userScopeID: String?
    private var loadGeneration = UUID()

    init(api: any BusinessRecordEvidenceAPI) {
        self.api = api
    }

    func coverage(for recordExternalID: String) -> BusinessRecordEvidenceCoverage? {
        guard case .available = loadState else { return nil }
        return records[recordExternalID]
    }

    func load(userID: String?, requestedAccountBookID: String? = nil, force: Bool = false) async {
        guard let userID else {
            clear()
            return
        }
        if !force, userScopeID == userID, case .available = loadState { return }

        let generation = UUID()
        loadGeneration = generation
        loadState = .loading
        do {
            let context = try await api.context(accountBookId: requestedAccountBookID)
            guard loadGeneration == generation else { return }
            let incomingBook = context.selectedAccountBook
            if userScopeID != userID || accountBook?.id != incomingBook.id {
                records = [:]
            }
            userScopeID = userID
            accountBook = incomingBook

            let response = try await api.coverage(accountBookId: incomingBook.id)
            guard loadGeneration == generation,
                  userScopeID == userID,
                  accountBook?.id == incomingBook.id else { return }
            records = response.records
            loadState = .available
        } catch {
            guard loadGeneration == generation else { return }
            records = []
            loadState = .failed(error.localizedDescription)
        }
    }

    func clear() {
        loadGeneration = UUID()
        userScopeID = nil
        accountBook = nil
        records = [:]
        loadState = .idle
    }
}
