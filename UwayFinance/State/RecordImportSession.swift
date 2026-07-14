import Combine
import Foundation

@MainActor
final class RecordImportSession: ObservableObject {
    @Published private(set) var preview: RecordImportPreview?
    @Published private(set) var analyses: [String: HarnessResult] = [:]
    @Published private(set) var failures: [String: String] = [:]
    @Published private(set) var fileName = ""
    @Published private(set) var isReading = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var analyzedCount = 0
    @Published var message: String?

    private var fileFingerprint = ""
    private var batchId = ""

    var acceptedCount: Int { analyses.values.filter { $0.status == "accepted" }.count }
    var reviewCount: Int { analyses.values.filter { $0.status == "review" }.count }
    var rejectedCount: Int { analyses.values.filter { $0.status == "rejected" }.count }
    var canAnalyze: Bool {
        guard let preview else { return false }
        return !isAnalyzing && !preview.eligible.isEmpty && preview.pendingOwnership.isEmpty
    }
    var canCommit: Bool { acceptedCount > 0 && !isAnalyzing }

    func load(url: URL, existing: [BusinessRecord]) async {
        reset()
        isReading = true
        defer { isReading = false }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            guard url.pathExtension.lowercased() == "csv" else {
                throw RecordImportPipelineError.invalidFileType
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let name = url.lastPathComponent
            preview = try RecordCSVParser.parse(data: data, fileName: name, existing: existing)
            fileName = name
            fileFingerprint = ImportAnalysisRequestFactory.fileFingerprint(data)
            batchId = "batch-\(UUID().uuidString.lowercased())"
            if preview?.eligible.isEmpty == true, preview?.pendingOwnership.isEmpty == true {
                message = "文件中没有可进入核验的公司账记录"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func confirmPendingOwnership() {
        guard var preview, !preview.pendingOwnership.isEmpty else { return }
        let confirmed = preview.pendingOwnership.map { candidate in
            var candidate = candidate
            candidate.companyEvidence = "用户在 iOS 导入流程明确确认：该记录属于公司账"
            return candidate
        }
        preview.eligible.append(contentsOf: confirmed)
        preview.pendingOwnership.removeAll()
        self.preview = preview
        clearAnalysis()
    }

    func excludePendingOwnership() {
        guard var preview, !preview.pendingOwnership.isEmpty else { return }
        preview.pendingOwnership.removeAll()
        self.preview = preview
        clearAnalysis()
    }

    func analyze(using api: any ImportAnalysisAPI, session: AppSession) async {
        let capability = session.importAnalysisCapability
        guard capability.available else {
            message = capability.unavailableMessage
            return
        }
        guard canAnalyze, let candidates = preview?.eligible else { return }
        clearAnalysis()
        isAnalyzing = true
        defer { isAnalyzing = false }

        let existingFingerprints = session.state.records.compactMap(\.sourceFingerprint)
        for candidate in candidates {
            let request = ImportAnalysisRequestFactory.make(
                candidate: candidate,
                batchId: batchId,
                fileName: fileName,
                fileFingerprint: fileFingerprint,
                existingFingerprints: existingFingerprints
            )
            do {
                analyses[candidate.id] = try await api.analyze(request)
            } catch APIError.unauthorized {
                session.invalidateExternalSession()
                message = APIError.unauthorized.localizedDescription
                return
            } catch {
                failures[candidate.id] = error.localizedDescription
            }
            analyzedCount += 1
        }

        if !failures.isEmpty {
            message = "\(failures.count) 笔未完成 AI 核验；失败记录不会写入账本"
        }
    }

    func decide(
        candidateID: String,
        decision: ImportDecisionChoice,
        reason: String,
        using api: any ImportAnalysisAPI,
        session: AppSession
    ) async throws {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedReason.count >= 3 else {
            throw APIError.unavailable("请填写至少 3 个字的复核理由")
        }
        guard let current = analyses[candidateID], current.status == "review" else {
            throw APIError.unavailable("该记录已不在待复核状态")
        }

        do {
            let response = try await api.decide(
                analysisId: current.analysisId,
                decision: ImportReviewDecision(decision: decision.rawValue, reason: normalizedReason)
            )
            analyses[candidateID] = HarnessResult(
                analysisId: response.analysisId,
                status: response.status,
                classification: current.classification,
                confidence: current.confidence,
                validatedEvidenceRefs: current.validatedEvidenceRefs,
                issues: current.issues,
                sourceFingerprint: response.sourceFingerprint,
                resolution: response.resolution
            )
        } catch APIError.unauthorized {
            session.invalidateExternalSession()
            throw APIError.unauthorized
        }
    }

    func commit(to session: AppSession) {
        guard let preview else { return }
        let records = preview.eligible.compactMap { candidate -> BusinessRecord? in
            guard let analysis = analyses[candidate.id], analysis.status == "accepted" else { return nil }
            var record = candidate.record
            record.importAnalysisId = analysis.analysisId
            record.sourceFingerprint = analysis.sourceFingerprint
            record.analysisDecision = analysis.resolution?.decision == "accept" ? .humanAccepted : .harnessAccepted
            return record
        }
        guard !records.isEmpty else { return }
        session.importRecords(
            records,
            fileName: fileName,
            duplicateCount: preview.duplicateCount,
            errorCount: preview.issues.count + failures.count
        )
    }

    func reset() {
        preview = nil
        fileName = ""
        fileFingerprint = ""
        batchId = ""
        message = nil
        clearAnalysis()
    }

    private func clearAnalysis() {
        analyses = [:]
        failures = [:]
        analyzedCount = 0
        message = nil
    }
}

enum ImportDecisionChoice: String, Identifiable {
    case accept
    case reject

    var id: String { rawValue }
    var title: String { self == .accept ? "核对后准入" : "拒绝导入" }
    var defaultReason: String {
        self == .accept ? "已核对原始文件与公司归属，同意导入" : "人工核对后不应进入公司账"
    }
}
