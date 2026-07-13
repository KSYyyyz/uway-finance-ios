import SwiftUI

struct NewRecordView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var direction: Direction = .expense
    @State private var amount = 0.0
    @State private var date = Date()
    @State private var counterparty = ""
    @State private var description = ""
    @State private var category = ""
    @State private var project = ""
    @State private var account = ""
    @State private var settlementStatus: SettlementStatus = .settled
    @State private var invoiceStatus: InvoiceStatus = .pending
    @State private var saved = false

    private var isValid: Bool {
        amount > 0 && !counterparty.trimmingCharacters(in: .whitespaces).isEmpty && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("收支") {
                    Picker("方向", selection: $direction) {
                        ForEach(Direction.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("金额", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    DatePicker("业务日期", selection: $date, displayedComponents: .date)
                }
                Section("经营事项") {
                    TextField("交易对方", text: $counterparty)
                    TextField("事项说明", text: $description, axis: .vertical)
                    TextField("分类", text: $category)
                    TextField("项目", text: $project)
                    TextField("账户", text: $account)
                }
                Section("状态") {
                    Picker("收付款", selection: $settlementStatus) {
                        Text("已收/付款").tag(SettlementStatus.settled)
                        Text("待收/付款").tag(SettlementStatus.unsettled)
                    }
                    Picker("发票", selection: $invoiceStatus) {
                        Text("已收到").tag(InvoiceStatus.received)
                        Text("待取得").tag(InvoiceStatus.pending)
                        Text("无需发票").tag(InvoiceStatus.notRequired)
                    }
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValid)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    private func save() {
        let record = BusinessRecord(
            id: "ios-\(UUID().uuidString.lowercased())",
            date: FinanceFormat.dateString(from: date),
            direction: direction,
            amount: amount,
            category: category,
            counterparty: counterparty,
            project: project,
            account: account,
            settlementStatus: settlementStatus,
            invoiceStatus: invoiceStatus,
            financeStatus: .draft,
            contractStatus: .notRequired,
            description: description,
            source: .manual,
            importedAt: ISO8601DateFormatter().string(from: Date()),
            supportingDocumentStatus: .pending
        )
        session.addRecord(record)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dismiss() }
    }
}

