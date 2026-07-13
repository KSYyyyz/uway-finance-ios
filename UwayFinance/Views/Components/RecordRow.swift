import SwiftUI

struct RecordRow: View {
    let record: BusinessRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.direction == .income ? "arrow.down" : "arrow.up")
                .font(.callout.weight(.semibold))
                .foregroundStyle(record.direction == .income ? AppTheme.brand : .secondary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.counterparty.isEmpty ? "未填写交易对方" : record.counterparty)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(record.description.isEmpty ? record.category : record.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(record.direction == .income ? "+" : "-")\(FinanceFormat.currency(record.amount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(record.direction == .income ? AppTheme.brand : .primary)
                    .monospacedDigit()
                Text(record.statusLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension BusinessRecord {
    var statusLabel: String {
        if settlementStatus == .unsettled { return direction == .income ? "待收款" : "待付款" }
        if invoiceStatus == .pending || contractStatus == .missing || supportingDocumentStatus == .pending { return "缺材料" }
        if financeStatus == .draft { return "待交代账" }
        return "已处理"
    }
}

