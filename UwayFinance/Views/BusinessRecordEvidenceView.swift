import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct BusinessRecordEvidenceView: View {
    @StateObject private var store: BusinessRecordEvidenceStore
    let recordExternalId: String
    let autoPreviewFirstSupported: Bool
    @State private var showUpload = false
    @State private var revokeTarget: BusinessRecordEvidence?
    @State private var previewURL: URL?
    @State private var loadingContentID: String?

    init(
        api: any BusinessRecordEvidenceAPI,
        recordExternalId: String,
        maximumBytes: Int,
        autoPreviewFirstSupported: Bool = false
    ) {
        _store = StateObject(wrappedValue: BusinessRecordEvidenceStore(api: api, maximumBytes: maximumBytes))
        self.recordExternalId = recordExternalId
        self.autoPreviewFirstSupported = autoPreviewFirstSupported
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("票据与附件").font(.headline)
                    Text(coverageText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.accountBook?.permissions.writeBusinessRecords == true,
                   store.coverageLoadState != .available || store.coverage.allowsUpload {
                    Button("添加", systemImage: "paperclip") { showUpload = true }
                        .buttonStyle(.bordered)
                }
            }

            Toggle("显示已作废原件", isOn: Binding(
                get: { store.includeRevoked },
                set: { value in Task { await store.setIncludeRevoked(value) } }
            ))
            .font(.subheadline)

            if store.coverageLoadState == .available,
               store.coverage.isRequiredMissing {
                Label(
                    "仍缺：\(store.coverage.missingRequiredTypes.map(\.label).joined(separator: "、"))",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.warning)
            } else if store.coverageLoadState == .available,
                      store.coverage.requirementState == .notRequired {
                Text("此事项无需补充材料；历史附件仍可查看和审计。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading, store.items.isEmpty {
                ProgressView("正在核对附件覆盖…")
            } else if store.items.isEmpty {
                Label("尚无票据原件", systemImage: "doc.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.items) { evidence in
                    evidenceRow(evidence)
                    if evidence.id != store.items.last?.id { Divider() }
                }
            }

            if let message = store.message {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("附件状态：\(message)")
            }

            Text("附件原件固定保存并校验 SHA-256；存在附件不代表自动记账、接受事项或形成凭证。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .appCard()
        .task(id: recordExternalId) {
            await store.restore(recordExternalId: recordExternalId)
            if autoPreviewFirstSupported,
               let evidence = store.items.first(where: { $0.status == .active && $0.supportsAutomaticPreview }) {
                await openContent(evidence)
            }
        }
        .sheet(isPresented: $showUpload) {
            EvidenceUploadView(
                store: store,
                dismiss: { showUpload = false }
            )
        }
        .sheet(item: $revokeTarget) { evidence in
            EvidenceRevokeView(store: store, evidence: evidence)
        }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { oldValue, newValue in
            if newValue == nil { EvidencePreviewFileManager.remove(oldValue) }
        }
        .sensoryFeedback(.success, trigger: store.successTrigger)
        .onDisappear { removePreviewFile() }
    }

    private var coverageText: String {
        switch store.coverageLoadState {
        case .idle, .loading:
            return "正在读取材料覆盖状态"
        case .failed:
            return "覆盖状态未知，暂不能判断材料是否齐全"
        case .available:
            let coverage = store.coverage
            return "\(coverage.requirementState?.label ?? "覆盖已读取") · 有效 \(coverage.activeEvidenceCount) · 图片 \(coverage.activeImageCount) · 发票 \(coverage.invoiceEvidenceCount) · 付款 \(coverage.paymentEvidenceCount) · 合同 \(coverage.contractEvidenceCount)"
        }
    }

    private func evidenceRow(_ evidence: BusinessRecordEvidence) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(evidence.evidenceType.label, systemImage: symbol(for: evidence))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(evidence.status.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(evidence.status == .active ? AppTheme.brand : .secondary)
            }
            Text(evidence.fileName).font(.subheadline).lineLimit(2)
            VStack(alignment: .leading, spacing: 3) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(evidence.byteSize), countStyle: .file))
                Text("上传时间：\(evidence.createdAt)")
                Text("上传者：\(evidence.uploadedByUserId)")
                Text("SHA-256：\(evidence.sha256)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let note = evidence.note, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            if let reason = evidence.revokeReason, evidence.status == .revoked {
                Text("作废原因：\(reason)").font(.caption).foregroundStyle(AppTheme.warning)
            }
            HStack {
                Button(evidence.supportsAutomaticPreview ? "预览原件" : "查看原件", systemImage: "doc.viewfinder") {
                    Task { await openContent(evidence) }
                }
                .disabled(loadingContentID != nil)
                if loadingContentID == evidence.id { ProgressView().controlSize(.small) }
                Spacer()
                if evidence.status == .active,
                   store.accountBook?.permissions.writeBusinessRecords == true {
                    Button("标记作废", systemImage: "nosign", role: .destructive) {
                        if store.revokeDrafts[evidence.id] == nil {
                            store.setRevokeReason("", evidenceId: evidence.id)
                        }
                        revokeTarget = evidence
                    }
                    .disabled(store.busyEvidenceIDs.contains(evidence.id))
                }
            }
            .font(.subheadline)
        }
        .accessibilityElement(children: .contain)
    }

    private func symbol(for evidence: BusinessRecordEvidence) -> String {
        evidence.mediaType == "application/pdf" ? "doc.richtext" : "photo"
    }

    private func openContent(_ evidence: BusinessRecordEvidence) async {
        loadingContentID = evidence.id
        defer { loadingContentID = nil }
        do {
            let content = try await store.loadContent(evidence)
            removePreviewFile()
            previewURL = try EvidencePreviewFileManager.write(content)
        } catch {
            store.message = error.localizedDescription
        }
    }

    private func removePreviewFile() {
        guard let previewURL else { return }
        EvidencePreviewFileManager.remove(previewURL)
        self.previewURL = nil
    }
}

private struct EvidenceUploadView: View {
    @ObservedObject var store: BusinessRecordEvidenceStore
    let dismiss: () -> Void
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    private var noteBinding: Binding<String> {
        Binding(
            get: { store.uploadNote },
            set: { store.updateUploadNote($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("选择原件") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("从照片中选择", systemImage: "photo.on.rectangle")
                    }
                    Button("从文件中选择", systemImage: "folder") {
                        showFileImporter = true
                    }
                    if let file = store.selectedFile {
                        LabeledContent("已选择", value: file.fileName)
                        LabeledContent(
                            "大小",
                            value: ByteCountFormatter.string(fromByteCount: Int64(file.byteSize), countStyle: .file)
                        )
                        Button("移除所选文件", role: .destructive) { store.clearSelectedFile() }
                    }
                }
                Section("附件信息") {
                    Picker("类型", selection: Binding(
                        get: { store.selectedType },
                        set: { store.updateUploadType($0) }
                    )) {
                        ForEach(BusinessRecordEvidenceType.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("说明（可选）", text: noteBinding, axis: .vertical)
                    .lineLimit(2...5)
                    .appScrollIndicatorsHidden()
                }
                Section("安全边界") {
                    Text("上传后原件由数据库触发器与 SHA-256 固定；后续只能标记作废，不能删除或覆盖。AI 不会据此自动记账。")
                        .font(.footnote)
                }
                if let message = store.message { Section { Text(message).font(.footnote) } }
            }
            .appScrollIndicatorsHidden()
            .navigationTitle("添加票据附件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭", action: dismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("上传") {
                        Task { if await store.upload() { dismiss() } }
                    }
                    .disabled(store.selectedFile == nil || store.isUploading)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { return }
                        let ext = EvidenceMediaDetection.mediaType(for: data) == "image/png" ? "png" : "heic"
                        store.selectFile(data: data, fileName: "照片附件.\(ext)")
                    } catch {
                        store.message = "读取照片失败：\(error.localizedDescription)"
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.image, .pdf],
                allowsMultipleSelection: false,
                onCompletion: importFile
            )
        }
        .interactiveDismissDisabled(store.isUploading)
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            store.selectFile(data: data, fileName: url.lastPathComponent)
        } catch {
            store.message = "读取所选文件失败：\(error.localizedDescription)"
        }
    }
}

private struct EvidenceRevokeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: BusinessRecordEvidenceStore
    let evidence: BusinessRecordEvidence

    private var reason: Binding<String> {
        Binding(
            get: { store.revokeDrafts[evidence.id] ?? "" },
            set: { store.setRevokeReason($0, evidenceId: evidence.id) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标记作废") {
                    Text("作废只改变生命周期；原始文件、SHA-256、上传人与时间仍保留供审计。")
                        .font(.footnote)
                }
                Section("原因") {
                    TextEditor(text: reason)
                        .appScrollIndicatorsHidden()
                        .frame(minHeight: 120)
                    Text("必须填写 3 至 1000 个字符。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = store.message { Section { Text(message).font(.footnote) } }
            }
            .appScrollIndicatorsHidden()
            .navigationTitle("标记附件作废")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认作废", role: .destructive) {
                        Task { if await store.revoke(evidence) { dismiss() } }
                    }
                    .disabled(reason.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                }
            }
        }
    }
}
