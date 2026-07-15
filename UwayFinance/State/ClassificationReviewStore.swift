import Combine
import Foundation

struct ClassificationReviewDraft: Equatable, Sendable {
    var action: ClassificationDecisionAction = .confirm
    var reason = ""
    var taxonomyCode: String?
    var normalizedItemName = ""
}

@MainActor
final class ClassificationReviewStore: ObservableObject {
    @Published private(set) var items: [ClassificationReviewItem] = []
    @Published private(set) var currentAccountBook: FinanceAccountBookAccess?
    @Published private(set) var taxonomy: [ClassificationTaxonomyItem] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var canGoBack = false
    @Published private(set) var isLoading = false
    @Published private(set) var busyRecordIDs: Set<String> = []
    @Published private(set) var analyses: [String: ClassificationAnalysisResult] = [:]
    @Published private(set) var drafts: [String: ClassificationReviewDraft] = [:]
    @Published var selectedState: ClassificationReviewState = .pending
    @Published var message: String?
    @Published private(set) var successTrigger = 0
    @Published private(set) var canReadBusinessRecords = false
    @Published private(set) var canWriteBusinessRecords = false

    private struct CursorPosition: Sendable { let value: String? }

    private let api: any ClassificationReviewAPI
    private var accountBookId: String?
    private var period: String?
    private var currentCursor: String?
    private var cursorStack: [CursorPosition] = []
    private var pendingAnalyze: [String: ClassificationAnalyzeCommand] = [:]
    private var pendingDecision: [String: ClassificationDecisionCommand] = [:]

    init(api: any ClassificationReviewAPI) {
        self.api = api
    }

    func restoreSession(accountBookId: String? = nil, period: String? = nil) async {
        self.accountBookId = accountBookId
        self.period = period
        currentCursor = nil
        cursorStack = []
        await loadCurrentPage()
    }

    func changeState(_ state: ClassificationReviewState) async {
        guard selectedState != state || currentCursor != nil else { return }
        selectedState = state
        currentCursor = nil
        cursorStack = []
        analyses = [:]
        message = nil
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

    func prepareDraft(for item: ClassificationReviewItem) {
        guard drafts[item.id] == nil else { return }
        drafts[item.id] = ClassificationReviewDraft(
            action: .confirm,
            reason: "",
            taxonomyCode: item.proposal.taxonomyCode,
            normalizedItemName: item.proposal.normalizedItemName
        )
    }

    func setAction(_ action: ClassificationDecisionAction, for recordID: String) {
        mutateDraft(recordID) { $0.action = action }
    }

    func setReason(_ reason: String, for recordID: String) {
        mutateDraft(recordID) { $0.reason = reason }
    }

    func setTaxonomyCode(_ code: String?, for recordID: String) {
        mutateDraft(recordID) { $0.taxonomyCode = code }
    }

    func setNormalizedItemName(_ value: String, for recordID: String) {
        mutateDraft(recordID) { $0.normalizedItemName = value }
    }

    func recordDeepLinkResolution(
        for item: ClassificationReviewItem,
        availableRecordIDs: Set<String>,
        legacyWritesAvailable: Bool
    ) -> RecordDeepLinkResolution {
        RecordDeepLinkResolver.resolve(
            recordID: item.id,
            availableRecordIDs: availableRecordIDs,
            canRead: canReadBusinessRecords,
            canEdit: canWriteBusinessRecords && legacyWritesAvailable,
            origin: .classification(state: selectedState.rawValue)
        )
    }

    func analyze(_ item: ClassificationReviewItem, aiAvailable: Bool) async {
        guard aiAvailable else {
            message = "AI 分类服务当前不可用，仍可进行人工更正或拒绝。"
            return
        }
        guard item.allowedActions.contains(.confirm) else {
            message = "当前账户只有查看权限，不能触发 AI 分析。"
            return
        }
        let recordID = item.id
        busyRecordIDs.insert(recordID)
        defer { busyRecordIDs.remove(recordID) }
        let command = pendingAnalyze[recordID] ?? ClassificationAnalyzeCommand(
            recordId: recordID,
            request: ClassificationVersionRequest(
                accountBookId: accountBookId ?? "",
                expectedRecordVersion: item.record.version,
                expectedClassificationVersion: item.proposal.version
            )
        )
        pendingAnalyze[recordID] = command
        do {
            let response = try await api.analyze(command)
            pendingAnalyze[recordID] = nil
            analyses[recordID] = response.analysis
            switch response.analysis.status {
            case .accepted:
                message = "确定性强规则已形成可审计分类；原始经营事项未被改写。"
            case .review:
                message = "AI 仅生成待复核建议，请人工确认、更正或拒绝。"
            case .rejected:
                message = "Harness 已失败关闭，本次建议不会形成正式分类。"
            }
            await loadCurrentPage(clearMessage: false)
        } catch {
            await handleOperationError(error, recordID: recordID, isAnalyze: true)
        }
    }

    func submitDecision(_ item: ClassificationReviewItem) async {
        prepareDraft(for: item)
        guard let draft = drafts[item.id] else { return }
        let reason = draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reason.count >= 2 else {
            message = "请填写至少两个字符的复核理由。"
            return
        }
        let taxonomyCode = draft.taxonomyCode ?? item.proposal.taxonomyCode
        if draft.action != .reject, taxonomyCode == nil {
            message = "确认或更正时必须选择闭集分类。"
            return
        }

        busyRecordIDs.insert(item.id)
        defer { busyRecordIDs.remove(item.id) }
        let request = ClassificationDecisionRequest(
            accountBookId: accountBookId ?? "",
            action: draft.action,
            expectedRecordVersion: item.record.version,
            expectedClassificationVersion: item.proposal.version,
            taxonomyCode: draft.action == .reject ? nil : taxonomyCode,
            normalizedItemName: draft.action == .reject ? nil : draft.normalizedItemName,
            reason: reason
        )
        let command = pendingDecision[item.id] ?? ClassificationDecisionCommand(recordId: item.id, request: request)
        pendingDecision[item.id] = command
        do {
            _ = try await api.decide(command)
            pendingDecision[item.id] = nil
            drafts[item.id] = nil
            analyses[item.id] = nil
            message = draft.action == .reject ? "分类建议已拒绝并留痕。" : "分类复核已提交并留痕。"
            successTrigger += 1
            await loadCurrentPage(clearMessage: false)
        } catch {
            await handleOperationError(error, recordID: item.id, isAnalyze: false)
        }
    }

    private func mutateDraft(_ recordID: String, mutation: (inout ClassificationReviewDraft) -> Void) {
        var draft = drafts[recordID] ?? ClassificationReviewDraft()
        mutation(&draft)
        drafts[recordID] = draft
        pendingDecision[recordID] = nil
    }

    private func loadCurrentPage(clearMessage: Bool = true) async {
        isLoading = true
        defer { isLoading = false }
        if clearMessage { message = nil }
        do {
            let response = try await api.list(ClassificationReviewQuery(
                state: selectedState,
                limit: 10,
                cursor: currentCursor,
                accountBookId: accountBookId,
                period: period
            ))
            accountBookId = response.accountBook.id
            currentAccountBook = response.accountBook
            canReadBusinessRecords = response.accountBook.permissions.readBusinessRecords
            canWriteBusinessRecords = response.accountBook.permissions.writeBusinessRecords
            items = response.items
            taxonomy = response.taxonomy
            nextCursor = response.page.nextCursor
            canGoBack = !cursorStack.isEmpty
            for item in response.items { prepareDraft(for: item) }
        } catch APIError.unauthorized {
            message = "登录已失效，请返回登录后重试。"
        } catch APIError.server(let status, _, let serverMessage) where status == 403 {
            items = []
            nextCursor = nil
            currentAccountBook = nil
            canReadBusinessRecords = false
            canWriteBusinessRecords = false
            message = serverMessage
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleOperationError(_ error: Error, recordID: String, isAnalyze: Bool) async {
        guard let apiError = error as? APIError else {
            message = error.localizedDescription
            return
        }
        if isConflict(apiError) {
            if isAnalyze { pendingAnalyze[recordID] = nil } else { pendingDecision[recordID] = nil }
            message = "服务端版本已变化，已刷新当前页；你的本地理由和更正草稿仍然保留。"
            await loadCurrentPage(clearMessage: false)
            return
        }
        if case .server(let status, let code, _) = apiError,
           status == 503 || code == "CLASSIFICATION_AI_UNAVAILABLE" {
            message = "AI 分类服务暂不可用，已保留当前任务；可稍后用同一请求重试或直接人工复核。"
            return
        }
        if case .server(let status, _, let serverMessage) = apiError, status == 403 {
            message = serverMessage
            return
        }
        if case .transport = apiError {
            message = "网络中断，草稿与幂等请求已保留；重试不会重复提交。"
            return
        }
        message = apiError.localizedDescription
    }

    private func isConflict(_ error: APIError) -> Bool {
        if case .versionConflict = error { return true }
        if case .server(let status, let code, _) = error {
            return status == 409 || code == "CLASSIFICATION_VERSION_CONFLICT" || code == "CLASSIFICATION_SOURCE_CHANGED"
        }
        return false
    }
}
