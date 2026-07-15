import SwiftUI

struct RecordDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.businessRecordEvidenceAPI) private var businessRecordEvidenceAPI
    let route: RecordDeepLinkRoute

    @State private var wasPreviouslyResolved = false
    @State private var editRecord: BusinessRecord?

    private var record: BusinessRecord? {
        session.state.records.first { $0.id == route.recordID }
    }

    var body: some View {
        Group {
            if let record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        amountCard(record)
                        factsCard(record)
                        statusCard(record)
                        if let capability = evidenceCapability {
                            BusinessRecordEvidenceView(
                                api: businessRecordEvidenceAPI,
                                recordExternalId: record.id,
                                maximumBytes: capability.maxBytes ?? 10_000_000
                            )
                        }
                    }
                    .padding()
                }
                .appScrollIndicatorsHidden()
                .onAppear { wasPreviouslyResolved = true }
            } else {
                let failure = RecordDeepLinkResolver.missingRecordFailure(
                    recordID: route.recordID,
                    wasPreviouslyResolved: wasPreviouslyResolved
                )
                ContentUnavailableView(
                    failure.title,
                    systemImage: wasPreviouslyResolved ? "trash" : "doc.text.magnifyingglass",
                    description: Text(failure.message)
                )
            }
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("经营事项")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let record, route.canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑", systemImage: "square.and.pencil") {
                        editRecord = record
                    }
                }
            }
        }
        .sheet(item: $editRecord) { record in
            RecordEditView(record: record)
        }
    }

    private var evidenceCapability: DocumentUploadCapability? {
        guard case .available(let contract) = session.serverState,
              contract.capabilities.documentUploadCapability.safeForClientUse else { return nil }
        return contract.capabilities.documentUploadCapability
    }

    private func amountCard(_ record: BusinessRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(record.direction.label, systemImage: record.direction == .income ? "arrow.down" : "arrow.up")
                    .foregroundStyle(record.direction == .income ? AppTheme.brand : .secondary)
                Spacer()
                if !route.canEdit {
                    Label("只读", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(record.direction == .income ? "+" : "-")\(FinanceFormat.currency(record.amount))")
                .font(.largeTitle.weight(.semibold).monospacedDigit())
            Text(record.description.isEmpty ? "无事项说明" : record.description)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func factsCard(_ record: BusinessRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("事项信息").font(.headline)
            detailRow("业务日期", record.date)
            detailRow("交易对方", displayValue(record.counterparty, fallback: "未填写"))
            detailRow("分类", displayValue(record.category, fallback: "未分类"))
            detailRow("项目", displayValue(record.project, fallback: "未关联"))
            detailRow("账户", displayValue(record.account, fallback: "未填写"))
            detailRow("事项编号", record.id)
        }
        .appCard()
    }

    private func statusCard(_ record: BusinessRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("处理状态").font(.headline)
            detailRow("收付款", record.settlementStatus == .settled ? "已收/付款" : "待收/付款")
            detailRow("发票", invoiceLabel(record.invoiceStatus))
            detailRow("代账", financeLabel(record.financeStatus))
            detailRow("合同", contractLabel(record.contractStatus))
        }
        .appCard()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.subheadline)
    }

    private func displayValue(_ value: String, fallback: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }

    private func invoiceLabel(_ value: InvoiceStatus) -> String {
        switch value {
        case .received: "已收到"
        case .pending: "待取得"
        case .notRequired: "无需发票"
        }
    }

    private func financeLabel(_ value: FinanceStatus) -> String {
        switch value {
        case .draft: "待交代"
        case .submitted: "已提交"
        case .booked: "已入账"
        }
    }

    private func contractLabel(_ value: ContractStatus) -> String {
        switch value {
        case .attached: "已附合同"
        case .missing: "缺合同"
        case .notRequired: "无需合同"
        }
    }
}

private struct RecordEditView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var record: BusinessRecord

    init(record: BusinessRecord) {
        _record = State(initialValue: record)
    }

    private var isValid: Bool {
        record.amount > 0
            && !record.counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !record.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("收支") {
                    Picker("方向", selection: $record.direction) {
                        ForEach(Direction.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("金额", value: $record.amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    TextField("业务日期", text: $record.date)
                        .textContentType(.none)
                }
                Section("经营事项") {
                    TextField("交易对方", text: $record.counterparty)
                    TextField("事项说明", text: $record.description, axis: .vertical)
                        .lineLimit(2...5)
                        .appScrollIndicatorsHidden()
                    TextField("分类", text: $record.category)
                    TextField("项目", text: $record.project)
                    TextField("账户", text: $record.account)
                }
                Section("状态") {
                    Picker("收付款", selection: $record.settlementStatus) {
                        Text("已收/付款").tag(SettlementStatus.settled)
                        Text("待收/付款").tag(SettlementStatus.unsettled)
                    }
                    Picker("发票", selection: $record.invoiceStatus) {
                        Text("已收到").tag(InvoiceStatus.received)
                        Text("待取得").tag(InvoiceStatus.pending)
                        Text("无需发票").tag(InvoiceStatus.notRequired)
                    }
                }
            }
            .appScrollIndicatorsHidden()
            .navigationTitle("编辑经营事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        session.updateRecord(record)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .interactiveDismissDisabled(session.syncState == .syncing)
    }
}
