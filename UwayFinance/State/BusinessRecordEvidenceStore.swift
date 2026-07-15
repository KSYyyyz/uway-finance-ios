import Combine
import Foundation

@MainActor
final class BusinessRecordEvidenceStore: ObservableObject {
    @Published private(set) var accountBook: FinanceAccountBookAccess?
    @Published private(set) var recordExternalId: String?
    @Published private(set) var items: [BusinessRecordEvidence] = []
    @Published private(set) var coverage = BusinessRecordEvidenceCoverage(
        activeEvidenceCount: 0,
        invoiceEvidenceCount: 0,
        paymentEvidenceCount: 0
    )
    @Published var includeRevoked = true
    @Published private(set) var selectedFile: SelectedEvidenceFile?
    @Published var selectedType: BusinessRecordEvidenceType = .invoice
    @Published var uploadNote = ""
    @Published private(set) var revokeDrafts: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isUploading = false
    @Published private(set) var busyEvidenceIDs: Set<String> = []
    @Published var message: String?
    @Published private(set) var successTrigger = 0

    private let api: any BusinessRecordEvidenceAPI
    private let maximumBytes: Int
    private var pendingUpload: BusinessRecordEvidenceUploadCommand?
    private var pendingRevokes: [String: BusinessRecordEvidenceRevokeCommand] = [:]

    init(api: any BusinessRecordEvidenceAPI, maximumBytes: Int = 10_000_000) {
        self.api = api
        self.maximumBytes = maximumBytes
    }

    func restore(recordExternalId: String, requestedAccountBookId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let context = try await api.context(accountBookId: requestedAccountBookId)
            let incomingBook = context.selectedAccountBook
            if accountBook?.id != incomingBook.id || self.recordExternalId != recordExternalId {
                clearScopedState()
            }
            accountBook = incomingBook
            self.recordExternalId = recordExternalId
            await reload(clearMessage: true)
        } catch {
            message = error.localizedDescription
        }
    }

    func setIncludeRevoked(_ value: Bool) async {
        includeRevoked = value
        await reload(clearMessage: true)
    }

    func selectFile(data: Data, fileName: String) {
        guard data.count <= maximumBytes else {
            message = "单个附件不能超过 \(maximumBytes / 1_000_000) MB。"
            return
        }
        guard let mediaType = EvidenceMediaDetection.mediaType(for: data) else {
            message = "仅支持 JPG、PNG、WebP、HEIC、HEIF 或 PDF 原件。"
            return
        }
        selectedFile = SelectedEvidenceFile(fileName: fileName, mediaType: mediaType, data: data)
        pendingUpload = nil
        message = nil
    }

    func clearSelectedFile() {
        selectedFile = nil
        pendingUpload = nil
    }

    func updateUploadType(_ value: BusinessRecordEvidenceType) {
        selectedType = value
        pendingUpload = nil
    }

    func updateUploadNote(_ value: String) {
        uploadNote = value
        pendingUpload = nil
    }

    func upload() async -> Bool {
        guard let accountBook, let recordExternalId, let selectedFile else {
            message = "请先选择需要上传的票据照片或 PDF。"
            return false
        }
        guard accountBook.permissions.writeBusinessRecords else {
            message = "当前账套角色无权上传票据证据。"
            return false
        }
        let trimmedNote = uploadNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 1_000 else {
            message = "附件说明不能超过 1000 个字符。"
            return false
        }
        let request = BusinessRecordEvidenceUploadRequest(
            accountBookId: accountBook.id,
            recordExternalId: recordExternalId,
            evidenceType: selectedType,
            note: trimmedNote,
            file: selectedFile
        )
        let command = pendingUpload ?? BusinessRecordEvidenceUploadCommand(request: request)
        pendingUpload = command
        isUploading = true
        defer { isUploading = false }
        do {
            let response = try await api.upload(command)
            guard response.evidence.recordExternalId == recordExternalId,
                  response.fixed,
                  response.contentImmutable else {
                throw APIError.decoding("上传响应未确认不可变原件边界")
            }
            self.selectedFile = nil
            uploadNote = ""
            selectedType = .invoice
            pendingUpload = nil
            message = "原件已固定保存；附件不会自动记账或接受经营事项。"
            successTrigger += 1
            await reload(clearMessage: false)
            return true
        } catch {
            message = uploadFailureMessage(error)
            return false
        }
    }

    func setRevokeReason(_ reason: String, evidenceId: String) {
        revokeDrafts[evidenceId] = reason
        pendingRevokes[evidenceId] = nil
    }

    func revoke(_ evidence: BusinessRecordEvidence) async -> Bool {
        guard let accountBook, let recordExternalId,
              evidence.recordExternalId == recordExternalId else {
            message = "拒绝作废：附件不属于当前账套事项。"
            return false
        }
        guard accountBook.permissions.writeBusinessRecords else {
            message = "当前账套角色无权标记附件作废。"
            return false
        }
        let reason = (revokeDrafts[evidence.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...1_000).contains(reason.count) else {
            message = "请填写 3 至 1000 个字符的作废原因。"
            return false
        }
        let request = BusinessRecordEvidenceRevokeRequest(
            accountBookId: accountBook.id,
            expectedVersion: evidence.version,
            reason: reason
        )
        let command = pendingRevokes[evidence.id]
            ?? BusinessRecordEvidenceRevokeCommand(evidenceId: evidence.id, request: request)
        pendingRevokes[evidence.id] = command
        busyEvidenceIDs.insert(evidence.id)
        defer { busyEvidenceIDs.remove(evidence.id) }
        do {
            let response = try await api.revoke(command)
            guard response.evidence.recordExternalId == recordExternalId,
                  response.contentDeleted == false,
                  response.contentImmutable else {
                throw APIError.decoding("作废响应越过不可变内容边界")
            }
            pendingRevokes[evidence.id] = nil
            revokeDrafts[evidence.id] = nil
            message = "附件已标记作废，原始字节仍保留供审计。"
            successTrigger += 1
            await reload(clearMessage: false)
            return true
        } catch let error as APIError {
            if case .server(let status, let code, _) = error,
               status == 409 || code == "EVIDENCE_VERSION_CONFLICT" {
                pendingRevokes[evidence.id] = nil
                message = "附件状态已被其他设备更新；作废原因和当前筛选已保留，请核对后重试。"
                await reload(clearMessage: false)
                return false
            }
            if case .transport = error {
                message = "网络中断；作废原因和同一幂等请求已保留，重试不会重复提交。"
                return false
            }
            message = error.localizedDescription
            return false
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func loadContent(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent {
        guard evidence.recordExternalId == recordExternalId else {
            throw APIError.unavailable("附件不属于当前事项")
        }
        return try await api.content(evidence)
    }

    private func reload(clearMessage: Bool) async {
        guard let accountBook, let recordExternalId else { return }
        if clearMessage { message = nil }
        do {
            async let listed = api.list(BusinessRecordEvidenceListQuery(
                accountBookId: accountBook.id,
                recordExternalId: recordExternalId,
                includeRevoked: includeRevoked
            ))
            async let covered = api.coverage(accountBookId: accountBook.id)
            let (listResponse, coverageResponse) = try await (listed, covered)
            guard listResponse.items.allSatisfy({ $0.recordExternalId == recordExternalId }) else {
                clearScopedState()
                self.accountBook = accountBook
                self.recordExternalId = recordExternalId
                message = "服务端返回了其他事项的附件，已停止展示。"
                return
            }
            items = listResponse.items
            coverage = coverageResponse.records[recordExternalId] ?? BusinessRecordEvidenceCoverage(
                activeEvidenceCount: 0,
                invoiceEvidenceCount: 0,
                paymentEvidenceCount: 0
            )
        } catch {
            message = error.localizedDescription
        }
    }

    private func uploadFailureMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            if case .transport = apiError {
                return "网络中断；所选文件、类型、说明和同一幂等请求均已保留。"
            }
            if case .server(let status, let code, _) = apiError, status == 409 {
                if code == "IDEMPOTENCY_KEY_REUSED" { pendingUpload = nil }
                return "上传请求发生并发冲突；本地表单和所选文件已保留，请核对后重试。"
            }
        }
        return error.localizedDescription
    }

    private func clearScopedState() {
        items = []
        coverage = BusinessRecordEvidenceCoverage(
            activeEvidenceCount: 0,
            invoiceEvidenceCount: 0,
            paymentEvidenceCount: 0
        )
        selectedFile = nil
        selectedType = .invoice
        uploadNote = ""
        revokeDrafts = [:]
        pendingUpload = nil
        pendingRevokes = [:]
        busyEvidenceIDs = []
        includeRevoked = true
        message = nil
        accountBook = nil
        recordExternalId = nil
    }
}
