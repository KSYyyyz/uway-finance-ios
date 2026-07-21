import Foundation

enum FinanceFormat {
    static func currency(_ value: Double, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func monthTitle(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 2 else { return value }
        return "\(parts[0])年\(Int(parts[1]) ?? 0)月"
    }

    static func dayTitle(_ value: String) -> String {
        guard let date = date(from: value) else { return value }
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.component(.day, from: date)
        let weekday = ["日", "一", "二", "三", "四", "五", "六"][calendar.component(.weekday, from: date) - 1]
        return "\(day)日  周\(weekday)"
    }
}

struct LedgerDayGroup: Identifiable {
    let date: String
    let records: [BusinessRecord]
    var id: String { date }
    var income: Double { records.filter { $0.direction == .income }.reduce(0) { $0 + $1.amount } }
    var expense: Double { records.filter { $0.direction == .expense }.reduce(0) { $0 + $1.amount } }
}

struct LedgerMonthGroup: Identifiable {
    let month: String
    let days: [LedgerDayGroup]
    var id: String { month }
    var records: [BusinessRecord] { days.flatMap { $0.records } }
    var income: Double { records.filter { $0.direction == .income }.reduce(0) { $0 + $1.amount } }
    var expense: Double { records.filter { $0.direction == .expense }.reduce(0) { $0 + $1.amount } }
}

extension Array where Element == BusinessRecord {
    /// Orders records by their canonical `yyyy-MM-dd` business date while
    /// preserving the source order for records that occurred on the same day.
    var businessDateDescendingStable: [BusinessRecord] {
        enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date != rhs.element.date {
                    return lhs.element.date > rhs.element.date
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    var ledgerGroups: [LedgerMonthGroup] {
        let months = Dictionary(grouping: businessDateDescendingStable) { String($0.date.prefix(7)) }
        return months.keys.sorted(by: >).map { month in
            let records = months[month, default: []]
            let recordsByDay = Dictionary(grouping: records, by: \.date)
            let days = recordsByDay.keys
                .sorted(by: >)
                .map { date in
                    LedgerDayGroup(
                        date: date,
                        records: recordsByDay[date, default: []]
                    )
                }
            return LedgerMonthGroup(month: month, days: days)
        }
    }
}

enum PendingKind: String, CaseIterable, Identifiable {
    case settlement, material, reconciliation, bookkeeping
    var id: String { rawValue }
}

enum PendingSeverity: String { case high, medium }

struct PendingItem: Identifiable, Hashable {
    let id: String
    let recordId: String
    let kind: PendingKind
    let severity: PendingSeverity
    let title: String
    let detail: String
    let action: String
}

extension Array where Element == BusinessRecord {
    var pendingItems: [PendingItem] {
        flatMap { record -> [PendingItem] in
            var items: [PendingItem] = []
            if record.settlementStatus == .unsettled {
                items.append(PendingItem(
                    id: "\(record.id)-settlement", recordId: record.id, kind: .settlement,
                    severity: record.amount >= 10_000 ? .high : .medium,
                    title: record.direction == .income ? "待确认客户回款" : "待确认付款状态",
                    detail: "\(record.counterparty) · \(FinanceFormat.currency(record.amount))",
                    action: "核对实际收付款结果并保留银行依据"
                ))
            }
            if record.invoiceStatus == .pending || record.contractStatus == .missing || record.supportingDocumentStatus == .pending {
                items.append(PendingItem(
                    id: "\(record.id)-material", recordId: record.id, kind: .material,
                    severity: record.amount >= 10_000 ? .high : .medium,
                    title: "经营事项材料待补",
                    detail: "\(record.description) · \(FinanceFormat.currency(record.amount))",
                    action: "补充发票、合同或真实缺失原因"
                ))
            }
            if record.financeStatus == .draft {
                items.append(PendingItem(
                    id: "\(record.id)-bookkeeping", recordId: record.id, kind: .bookkeeping,
                    severity: .medium,
                    title: "事项尚未交代账",
                    detail: "\(record.counterparty) · \(record.date)",
                    action: "确认信息完整后提交代账处理"
                ))
            }
            return items
        }
        .sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity == .high }
            return lhs.id < rhs.id
        }
    }
}

struct ForecastPoint: Identifiable, Hashable {
    let date: Date
    let balance: Double
    var id: Date { date }
}

enum ForecastPeriod: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90
    var id: Int { rawValue }
    var label: String { "\(rawValue)天" }
}

enum ForecastCalculator {
    static func points(records: [BusinessRecord], period: ForecastPeriod, now: Date = Date()) -> [ForecastPoint] {
        let calendar = Calendar(identifier: .gregorian)
        let settled = records.filter { $0.settlementStatus == .settled }
        var balance = settled.reduce(0) { partial, record in
            partial + (record.direction == .income ? record.amount : -record.amount)
        }
        let planned = records.filter { $0.settlementStatus == .unsettled }
        return (0...period.rawValue).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let day = FinanceFormat.dateString(from: date)
            for record in planned where record.dueDate == day {
                balance += record.direction == .income ? record.amount : -record.amount
            }
            return ForecastPoint(date: date, balance: balance)
        }
    }
}
