import SwiftUI
import UniformTypeIdentifiers

struct RecordImportView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.importAnalysisAPI) private var importAnalysisAPI
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importSession = RecordImportSession()
    @State private var filePickerVisible = false
    @State private var ownershipDialogVisible = false
    @State private var reviewPrompt: ImportReviewPrompt?

    private var importAnalysisCapability: ImportAnalysisCapability {
        session.importAnalysisCapability
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    safetyCard
                    fileCard
                    if let preview = importSession.preview {
                        summaryCard(preview)
                        if !preview.pendingOwnership.isEmpty { ownershipCard(preview) }
                        analysisCard(preview)
                        recordsCard(preview)
                        if !preview.issues.isEmpty { issuesCard(preview.issues) }
                    }
                    if let message = importSession.message { messageCard(message) }
                }
                .padding()
            }
            .appScrollIndicatorsHidden()
            .background(AppTheme.pageBackground)
            .navigationTitle("导入流水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if importSession.preview != nil {
                    Button {
                        importSession.commit(to: session)
                        dismiss()
                    } label: {
                        Label("确认导入 \(importSession.acceptedCount) 笔", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!importSession.canCommit)
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .fileImporter(
                isPresented: $filePickerVisible,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await importSession.load(url: url, existing: session.state.records) }
                case .failure(let error):
                    importSession.message = error.localizedDescription
                }
            }
            .confirmationDialog(
                "确认这些记录都属于公司账？",
                isPresented: $ownershipDialogVisible,
                titleVisibility: .visible
            ) {
                Button("确认均为公司账") { importSession.confirmPendingOwnership() }
                Button("不导入归属不明记录", role: .destructive) { importSession.excludePendingOwnership() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确认结果会作为公司归属证据发送给后端并写入审计链。含个人消费时请选择不导入。")
            }
            .sheet(item: $reviewPrompt) { prompt in
                ImportReviewDecisionView(choice: prompt.choice) { reason in
                    try await importSession.decide(
                        candidateID: prompt.candidateID,
                        decision: prompt.choice,
                        reason: reason,
                        using: importAnalysisAPI,
                        session: session
                    )
                }
            }
        }
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.title2)
                .foregroundStyle(AppTheme.brand)
            VStack(alignment: .leading, spacing: 4) {
                Text("先核验，后入账").font(.headline)
                Text("CSV 会先校验公司归属和重复项，再由服务器 AI Harness 判定。只有已准入记录才会追加到账本。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var fileCard: some View {
        Button {
            filePickerVisible = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: importSession.isReading ? "hourglass" : "doc.badge.plus")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(importSession.fileName.isEmpty ? "选择 CSV 文件" : importSession.fileName)
                        .font(.subheadline.weight(.semibold))
                    Text("支持 UTF-8 / GB18030，最大 5MB、单批 30 行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if importSession.isReading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(importSession.isReading || importSession.isAnalyzing)
        .appCard()
    }

    private func summaryCard(_ preview: RecordImportPreview) -> some View {
        HStack(spacing: 0) {
            metric("数据行", preview.totalRows, color: .primary)
            Divider().frame(height: 32)
            metric("公司账", preview.eligible.count, color: AppTheme.brand)
            Divider().frame(height: 32)
            metric("归属不明", preview.pendingOwnership.count, color: preview.pendingOwnership.isEmpty ? .secondary : AppTheme.warning)
            Divider().frame(height: 32)
            metric("已排除", preview.excludedCount + preview.duplicateCount + preview.issues.count, color: .secondary)
        }
        .appCard(padding: 12)
    }

    private func metric(_ title: String, _ value: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.headline.monospacedDigit()).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ownershipCard(_ preview: RecordImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(preview.pendingOwnership.count) 笔没有明确公司归属", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.warning)
            Text("系统不会根据消费内容猜测归属。请确认全部属于公司，或把这些记录排除。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("处理归属不明记录") { ownershipDialogVisible = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func analysisCard(_ preview: RecordImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(importAnalysisCapability.available ? AppTheme.brand : AppTheme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 证据核验").font(.subheadline.weight(.semibold))
                    Text("自动准入、人工复核或拦截；模型不能绕过后端候选与证据规则。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !importAnalysisCapability.available {
                Label(importAnalysisCapability.unavailableMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }

            if importSession.isAnalyzing {
                ProgressView(value: Double(importSession.analyzedCount), total: Double(max(preview.eligible.count, 1))) {
                    Text("核验中 \(importSession.analyzedCount)/\(preview.eligible.count)")
                        .font(.caption)
                }
            }

            HStack {
                Label("准入 \(importSession.acceptedCount)", systemImage: "checkmark.circle.fill").foregroundStyle(AppTheme.brand)
                Label("复核 \(importSession.reviewCount)", systemImage: "person.crop.circle.badge.questionmark").foregroundStyle(AppTheme.warning)
                Label("拦截 \(importSession.rejectedCount)", systemImage: "xmark.octagon.fill").foregroundStyle(AppTheme.danger)
            }
            .font(.caption)

            Button {
                Task { await importSession.analyze(using: importAnalysisAPI, session: session) }
            } label: {
                Label(importSession.analyses.isEmpty ? "开始核验 \(preview.eligible.count) 笔" : "重新核验", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!importSession.canAnalyze || !importAnalysisCapability.available)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func recordsCard(_ preview: RecordImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("导入预览").font(.headline).padding(.bottom, 8)
            ForEach(Array((preview.eligible + preview.pendingOwnership).enumerated()), id: \.element.id) { index, candidate in
                if index > 0 { Divider().padding(.leading, 44) }
                RecordImportCandidateRow(
                    candidate: candidate,
                    analysis: importSession.analyses[candidate.id],
                    failure: importSession.failures[candidate.id],
                    pendingOwnership: preview.pendingOwnership.contains(where: { $0.id == candidate.id })
                ) {
                    reviewPrompt = ImportReviewPrompt(candidateID: candidate.id, choice: $0)
                }
                .padding(.vertical, 10)
            }
        }
        .appCard()
    }

    private func issuesCard(_ issues: [RecordImportIssue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("需要修正的行", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
            ForEach(Array(issues.prefix(8).enumerated()), id: \.offset) { _, issue in
                Text("第 \(issue.row) 行：\(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func messageCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(AppTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
    }
}

private struct ImportReviewPrompt: Identifiable {
    let candidateID: String
    let choice: ImportDecisionChoice
    var id: String { "\(candidateID)-\(choice.rawValue)" }
}

private struct RecordImportCandidateRow: View {
    let candidate: RecordImportCandidate
    let analysis: HarnessResult?
    let failure: String?
    let pendingOwnership: Bool
    let review: (ImportDecisionChoice) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: candidate.record.direction == .income ? "arrow.down" : "arrow.up")
                .foregroundStyle(candidate.record.direction == .income ? AppTheme.brand : .secondary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(candidate.record.description.nilIfBlank ?? candidate.record.counterparty.nilIfBlank ?? "第 \(candidate.rowNumber) 行")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(FinanceFormat.currency(candidate.record.amount))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Text("\(candidate.record.date) · \(candidate.companyEvidence)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                status
            }
        }
    }

    @ViewBuilder private var status: some View {
        if pendingOwnership {
            statusLabel("待确认公司归属", symbol: "questionmark.circle", color: AppTheme.warning)
        } else if let failure {
            statusLabel(failure, symbol: "wifi.exclamationmark", color: AppTheme.danger)
        } else if let analysis {
            switch analysis.status {
            case "accepted":
                statusLabel(analysis.resolution == nil ? "Harness 已准入" : "人工复核已准入", symbol: "checkmark.circle.fill", color: AppTheme.brand)
            case "review":
                HStack {
                    statusLabel(analysis.issues.first?.message ?? "需要人工复核", symbol: "person.crop.circle.badge.questionmark", color: AppTheme.warning)
                    Spacer()
                    Menu("复核") {
                        Button("核对后准入", systemImage: "checkmark") { review(.accept) }
                        Button("拒绝导入", systemImage: "xmark", role: .destructive) { review(.reject) }
                    }
                    .font(.caption.weight(.semibold))
                }
            default:
                statusLabel(analysis.issues.first?.message ?? "Harness 已拦截", symbol: "xmark.octagon.fill", color: AppTheme.danger)
            }
        } else {
            statusLabel("等待 AI 核验", symbol: "clock", color: .secondary)
        }
    }

    private func statusLabel(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2)
            .foregroundStyle(color)
            .lineLimit(2)
    }
}

private struct ImportReviewDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    let choice: ImportDecisionChoice
    let submit: (String) async throws -> Void
    @State private var reason: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(choice: ImportDecisionChoice, submit: @escaping (String) async throws -> Void) {
        self.choice = choice
        self.submit = submit
        _reason = State(initialValue: choice.defaultReason)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("复核决定") {
                    Label(choice.title, systemImage: choice == .accept ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(choice == .accept ? AppTheme.brand : AppTheme.danger)
                }
                Section("审计理由") {
                    TextEditor(text: $reason)
                        .appScrollIndicatorsHidden()
                        .frame(minHeight: 110)
                    Text("理由会由后端连同当前登录审核人写入审计记录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(AppTheme.danger) }
                }
            }
            .appScrollIndicatorsHidden()
            .navigationTitle("人工复核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        Task {
                            isSubmitting = true
                            defer { isSubmitting = false }
                            do {
                                try await submit(reason)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(isSubmitting || reason.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSubmitting)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
