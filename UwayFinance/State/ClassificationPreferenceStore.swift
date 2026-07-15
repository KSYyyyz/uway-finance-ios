import Combine
import Foundation

@MainActor
final class ClassificationPreferenceStore: ObservableObject {
    @Published private(set) var accountBook: FinanceAccountBookAccess?
    @Published private(set) var items: [ClassificationPreferenceObservation] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var canGoBack = false
    @Published private(set) var isLoading = false
    @Published private(set) var busyObservationIDs: Set<String> = []
    @Published private(set) var revokeDrafts: [String: String] = [:]
    @Published var selectedState: ClassificationPreferenceListState = .active
    @Published var message: String?
    @Published private(set) var successTrigger = 0

    private struct CursorPosition: Sendable { let value: String? }

    private let api: any ClassificationPreferenceAPI
    private var currentCursor: String?
    private var cursorStack: [CursorPosition] = []
    private var pendingRevokes: [String: ClassificationPreferenceRevokeCommand] = [:]

    init(api: any ClassificationPreferenceAPI) {
        self.api = api
    }

    func restore(accountBook: FinanceAccountBookAccess) async {
        if self.accountBook?.id != accountBook.id {
            clearAccountScopedState()
            self.accountBook = accountBook
        }
        await loadCurrentPage()
    }

    func changeState(_ state: ClassificationPreferenceListState) async {
        guard selectedState != state || currentCursor != nil else { return }
        selectedState = state
        currentCursor = nil
        cursorStack = []
        await loadCurrentPage()
    }

    func refresh() async {
        await loadCurrentPage()
    }

    func nextPage() async {
        guard let nextCursor else { return }
        cursorStack.append(CursorPosition(value: currentCursor))
        currentCursor = nextCursor
        await loadCurrentPage()
    }

    func previousPage() async {
        guard let previous = cursorStack.popLast() else { return }
        currentCursor = previous.value
        await loadCurrentPage()
    }

    func setRevokeReason(_ reason: String, for observationID: String) {
        revokeDrafts[observationID] = reason
        pendingRevokes[observationID] = nil
    }

    func revoke(_ observation: ClassificationPreferenceObservation) async -> Bool {
        guard let accountBook else {
            message = "当前账套信息已失效，请返回重新打开。"
            return false
        }
        guard observation.accountBookId == accountBook.id else {
            message = "拒绝撤销：该学习记录不属于当前账套。"
            return false
        }
        let reason = (revokeDrafts[observation.id] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard reason.count >= 2 else {
            message = "请填写至少两个字的撤销理由。"
            return false
        }

        busyObservationIDs.insert(observation.id)
        defer { busyObservationIDs.remove(observation.id) }
        let request = ClassificationPreferenceRevokeRequest(
            accountBookId: accountBook.id,
            expectedVersion: observation.version,
            reason: reason
        )
        let command = pendingRevokes[observation.id]
            ?? ClassificationPreferenceRevokeCommand(observationId: observation.id, request: request)
        pendingRevokes[observation.id] = command

        do {
            let response = try await api.revoke(command)
            guard response.observation.accountBookId == accountBook.id,
                  response.safety.recomputedFromActiveEvents,
                  response.safety.modelCanAccept == false,
                  response.safety.writesBusinessRecords == false else {
                throw APIError.decoding("分类偏好撤销响应超出安全边界")
            }
            pendingRevokes[observation.id] = nil
            revokeDrafts[observation.id] = nil
            message = "该学习记录已撤销，服务端已根据剩余的有效人工决定重算。"
            successTrigger += 1
            await loadCurrentPage(clearMessage: false)
            return true
        } catch let error as APIError {
            return await handleRevokeError(error, observationID: observation.id)
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    private func loadCurrentPage(clearMessage: Bool = true) async {
        guard let accountBook else { return }
        isLoading = true
        defer { isLoading = false }
        if clearMessage { message = nil }
        do {
            let response = try await api.list(ClassificationPreferenceQuery(
                accountBookId: accountBook.id,
                state: selectedState,
                limit: 10,
                cursor: currentCursor
            ))
            guard response.accountBook.id == accountBook.id,
                  response.items.allSatisfy({ $0.accountBookId == accountBook.id }),
                  response.safety.accountBookScoped,
                  response.safety.modelCanAccept == false,
                  response.safety.writesBusinessRecords == false else {
                clearAccountScopedState(keepingAccountBook: true)
                message = "服务端返回了不同账套或不安全的学习记录，已停止展示。"
                return
            }
            self.accountBook = response.accountBook
            items = response.items
            nextCursor = response.page.nextCursor
            canGoBack = !cursorStack.isEmpty
        } catch APIError.unauthorized {
            message = "登录已失效，请返回登录后重试。"
        } catch APIError.server(let status, _, let serverMessage) where status == 403 {
            items = []
            nextCursor = nil
            message = serverMessage
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleRevokeError(_ error: APIError, observationID: String) async -> Bool {
        if case .server(let status, let code, _) = error,
           status == 409 || code == "CLASSIFICATION_PREFERENCE_VERSION_CONFLICT" || code == "CLASSIFICATION_PREFERENCE_NOT_ACTIVE" {
            pendingRevokes[observationID] = nil
            message = "该学习记录已被其他窗口更新。已保留撤销理由、当前筛选和分页，请核对新版本后重试。"
            await loadCurrentPage(clearMessage: false)
            return false
        }
        if case .server(let status, _, let serverMessage) = error, status == 403 || status == 404 {
            message = serverMessage
            return false
        }
        if case .transport = error {
            message = "网络中断，撤销理由与同一幂等请求已保留，重试不会重复提交。"
            return false
        }
        message = error.localizedDescription
        return false
    }

    private func clearAccountScopedState(keepingAccountBook: Bool = false) {
        items = []
        nextCursor = nil
        canGoBack = false
        currentCursor = nil
        cursorStack = []
        revokeDrafts = [:]
        pendingRevokes = [:]
        busyObservationIDs = []
        selectedState = .active
        message = nil
        if !keepingAccountBook { accountBook = nil }
    }
}
