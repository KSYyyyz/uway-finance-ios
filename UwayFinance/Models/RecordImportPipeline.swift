import CoreFoundation
import CryptoKit
import Foundation

struct RecordImportIssue: Hashable {
    let row: Int
    let message: String
}

struct RecordImportCandidate: Identifiable, Hashable {
    let id: String
    let rowNumber: Int
    var record: BusinessRecord
    var companyEvidence: String
}

struct RecordImportPreview: Hashable {
    var eligible: [RecordImportCandidate]
    var pendingOwnership: [RecordImportCandidate]
    let duplicateCount: Int
    let excludedCount: Int
    let issues: [RecordImportIssue]
    let totalRows: Int
}

enum RecordImportPipelineError: LocalizedError, Equatable {
    case invalidFileType
    case unsupportedEncoding
    case emptyFile
    case tooManyRows(Int)
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            "请选择 .csv 文件"
        case .unsupportedEncoding:
            "无法读取文件编码，请将 CSV 保存为 UTF-8 或 GB18030 后重试"
        case .emptyFile:
            "CSV 中没有可导入的数据行"
        case .tooManyRows(let count):
            "当前文件有 \(count) 行；为符合 AI 接口限流，iOS 单批最多导入 30 行"
        case .fileTooLarge:
            "单个 CSV 文件不能超过 5MB"
        }
    }
}

enum RecordCSVParser {
    static let maximumFileSize = 5 * 1024 * 1024
    static let maximumBatchRows = 30

    private static let companyHeaders = ["是否公司账目", "公司账目", "账目归属", "业务归属", "归属主体", "所属账本", "账本名称", "账本", "账簿"]

    static func parse(data: Data, fileName: String, existing: [BusinessRecord]) throws -> RecordImportPreview {
        guard data.count <= maximumFileSize else { throw RecordImportPipelineError.fileTooLarge }
        guard let text = decode(data) else { throw RecordImportPipelineError.unsupportedEncoding }
        let rows = parseRows(text)
        guard rows.count >= 2 else { throw RecordImportPipelineError.emptyFile }

        let totalRows = rows.count - 1
        guard totalRows <= maximumBatchRows else { throw RecordImportPipelineError.tooManyRows(totalRows) }

        let headers = rows[0]
        let normalizedHeaders = headers.map(normalizeHeader)
        let companyColumn = companyHeaders
            .map(normalizeHeader)
            .compactMap { normalizedHeaders.firstIndex(of: $0) }
            .first
        let isUwayTemplate = hasHeader(headers, "代账交接状态", "事项编号")
            || (hasHeader(headers, "交易对方") && hasHeader(headers, "收付款状态") && hasHeader(headers, "项目"))

        var existingKeys = Set(existing.map(recordSignature))
        var pendingKeys = Set<String>()
        var eligible: [RecordImportCandidate] = []
        var pending: [RecordImportCandidate] = []
        var issues: [RecordImportIssue] = []
        var duplicateCount = 0
        var excludedCount = 0
        let importedAt = ISO8601DateFormatter().string(from: Date())

        for (index, row) in rows.dropFirst().enumerated() {
            let rowNumber = index + 2
            let read = rowReader(headers: headers, row: row)
            let date = normalizeDate(read("日期", "发生日期", "交易日期", "记账日期", "发生时间"))
            let rawAmount = read("金额", "交易金额", "收支金额")
            let direction = parseDirection(read("收支方向", "方向", "类型", "收支类型", "交易类型"), amount: rawAmount)
            let amount = normalizeAmount(rawAmount)

            guard !date.isEmpty else {
                issues.append(.init(row: rowNumber, message: "日期无法识别，本行未导入"))
                continue
            }
            guard let direction else {
                issues.append(.init(row: rowNumber, message: "收入或支出方向无法识别，本行未导入"))
                continue
            }
            guard amount.isFinite, amount > 0 else {
                issues.append(.init(row: rowNumber, message: "金额无法识别或不大于 0，本行未导入"))
                continue
            }

            let companyValue = companyColumn.flatMap { row.indices.contains($0) ? row[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil } ?? ""
            if isClearlyNonCompany(companyValue) {
                excludedCount += 1
                continue
            }

            let companyConfirmed = isUwayTemplate || isCompany(companyValue)
            let counterparty = read("交易对方", "对方名称", "对方户名", "商户名称", "收付款方", "收款方", "付款方")
            let description = read("说明", "事项说明", "摘要", "用途", "备注", "交易备注", "商品说明")
            let record = BusinessRecord(
                id: read("事项编号", "编号").nilIfEmpty ?? stableID("CSV", "\(date)|\(direction.rawValue)|\(amount)|\(counterparty)|\(description)|\(rowNumber)"),
                date: date,
                direction: direction,
                amount: amount,
                category: read("类别", "分类", "一级分类", "费用类别", "收支分类", "科目"),
                counterparty: counterparty,
                project: read("项目", "归属项目", "项目名称", "业务项目"),
                account: read("账户/垫付人", "账户", "垫付人", "支付账户", "收款账户"),
                settlementStatus: settlementStatus(read("收付款状态", "结算状态")),
                invoiceStatus: invoiceStatus(read("发票", "发票状态")),
                financeStatus: financeStatus(read("代账交接状态", "代账状态")),
                contractStatus: contractStatus(read("合同", "合同状态")),
                description: description,
                dueDate: normalizeDate(read("到期日", "预计收付款日期")).nilIfEmpty,
                bankReference: read("银行流水号", "流水号").nilIfEmpty,
                source: .csv,
                importedAt: importedAt,
                supportingDocumentStatus: supportingDocumentStatus(read("配套材料", "凭证材料", "附件材料")),
                supportingDocumentNote: read("待补说明", "材料说明", "缺失说明").nilIfEmpty
            )

            let signature = recordSignature(record)
            if existingKeys.contains(signature) || pendingKeys.contains(signature) {
                duplicateCount += 1
                continue
            }

            let evidence: String
            if isUwayTemplate {
                evidence = "Uway 公司账模板"
            } else if let companyColumn {
                evidence = "\(headers[companyColumn])=\(companyValue)"
            } else {
                evidence = "未找到公司归属列"
            }
            let candidate = RecordImportCandidate(id: record.id, rowNumber: rowNumber, record: record, companyEvidence: evidence)

            if companyConfirmed {
                existingKeys.insert(signature)
                eligible.append(candidate)
            } else {
                pendingKeys.insert(signature)
                pending.append(candidate)
            }
        }

        return RecordImportPreview(
            eligible: eligible,
            pendingOwnership: pending,
            duplicateCount: duplicateCount,
            excludedCount: excludedCount,
            issues: Array(issues.prefix(100)),
            totalRows: totalRows
        )
    }

    static func parseRows(_ text: String) -> [[String]] {
        let source = text.trimmingPrefix("\u{feff}")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if character == "\"" {
                if quoted, next < source.endIndex, source[next] == "\"" {
                    field.append("\"")
                    index = source.index(after: next)
                    continue
                }
                quoted.toggle()
            } else if character == ",", !quoted {
                row.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
                field = ""
            } else if (character == "\n" || character == "\r"), !quoted {
                if character == "\r", next < source.endIndex, source[next] == "\n" {
                    index = source.index(after: next)
                } else {
                    index = next
                }
                row.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
                field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
                continue
            } else {
                field.append(character)
            }
            index = next
        }

        row.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    private static func decode(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        return String(data: data, encoding: gb18030)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: #"[\s_\-/]"#, with: "", options: .regularExpression)
            .lowercased()
    }

    private static func hasHeader(_ headers: [String], _ aliases: String...) -> Bool {
        let normalized = Set(headers.map(normalizeHeader))
        return aliases.allSatisfy { normalized.contains(normalizeHeader($0)) }
    }

    private static func rowReader(headers: [String], row: [String]) -> RowReader {
        var values: [String: String] = [:]
        for (index, header) in headers.enumerated() {
            let key = normalizeHeader(header)
            guard values[key] == nil else { continue }
            values[key] = row.indices.contains(index) ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        return RowReader(values: values)
    }

    private static func normalizeDate(_ value: String) -> String {
        let plain = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: " T")).first?
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-") ?? ""
        let parts = plain.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func normalizeAmount(_ value: String) -> Double {
        let plain = value.replacingOccurrences(of: #"[¥￥,，\s]"#, with: "", options: .regularExpression)
        let signed = plain.hasPrefix("(") && plain.hasSuffix(")") ? "-\(plain.dropFirst().dropLast())" : plain
        return abs(Double(signed) ?? .nan)
    }

    private static func parseDirection(_ value: String, amount: String) -> Direction? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.range(of: "收入|收款|转入|进账|贷|income|credit", options: .regularExpression) != nil { return .income }
        if normalized.range(of: "支出|付款|转出|出账|借|expense|debit", options: .regularExpression) != nil { return .expense }
        let signed = amount.replacingOccurrences(of: #"[¥￥,，\s]"#, with: "", options: .regularExpression)
        guard let numeric = Double(signed), numeric != 0 else { return nil }
        return numeric > 0 ? .income : .expense
    }

    private static func isCompany(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !isClearlyNonCompany(normalized) else { return false }
        return normalized.range(of: "公司|企业|对公|公账|经营账", options: .regularExpression) != nil
            || ["是", "yes", "y", "true", "1"].contains(normalized)
    }

    private static func isClearlyNonCompany(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .range(of: "非公司|个人|私人|家庭|生活|总账本", options: .regularExpression) != nil
    }

    private static func settlementStatus(_ value: String) -> SettlementStatus {
        value.range(of: "已收|已付|已结算|settled", options: [.regularExpression, .caseInsensitive]) == nil ? .unsettled : .settled
    }

    private static func invoiceStatus(_ value: String) -> InvoiceStatus {
        if value.range(of: "已取得|有发票|received", options: [.regularExpression, .caseInsensitive]) != nil { return .received }
        if value.range(of: "无需|not_required", options: [.regularExpression, .caseInsensitive]) != nil { return .notRequired }
        return .pending
    }

    private static func contractStatus(_ value: String) -> ContractStatus {
        if value.range(of: "已附|有合同|attached", options: [.regularExpression, .caseInsensitive]) != nil { return .attached }
        if value.range(of: "无需|not_required", options: [.regularExpression, .caseInsensitive]) != nil { return .notRequired }
        return .missing
    }

    private static func financeStatus(_ value: String) -> FinanceStatus {
        if value.range(of: "代账已处理|booked", options: [.regularExpression, .caseInsensitive]) != nil { return .booked }
        if value.range(of: "已交代账|submitted", options: [.regularExpression, .caseInsensitive]) != nil { return .submitted }
        return .draft
    }

    private static func supportingDocumentStatus(_ value: String) -> SupportingDocumentStatus? {
        if value.isEmpty { return nil }
        if value.range(of: "齐全|complete", options: [.regularExpression, .caseInsensitive]) != nil { return .complete }
        if value.range(of: "无需|not_required", options: [.regularExpression, .caseInsensitive]) != nil { return .notRequired }
        return .pending
    }

    private static func recordSignature(_ record: BusinessRecord) -> String {
        [record.date, record.direction.rawValue, String(format: "%.2f", record.amount), record.counterparty, record.description]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    private static func stableID(_ prefix: String, _ value: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return "\(prefix)-\(String(hash, radix: 36).uppercased())"
    }
}

enum ImportAnalysisRequestFactory {
    static func fileFingerprint(_ data: Data) -> String {
        digest(data)
    }

    static func make(
        candidate: RecordImportCandidate,
        batchId: String,
        fileName: String,
        fileFingerprint: String,
        existingFingerprints: [String]
    ) -> ImportAnalysisRequest {
        let record = candidate.record
        let canonical = [
            record.date, record.direction.rawValue,
            String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), record.amount),
            record.category, record.counterparty, record.project, record.account, record.description,
        ].joined(separator: "\u{1f}")
        let sourceFingerprint = digest(Data("\(fileFingerprint)|\(candidate.rowNumber)|\(canonical)".utf8))
        let ownershipFingerprint = digest(Data("\(sourceFingerprint)|\(candidate.companyEvidence)".utf8))

        return ImportAnalysisRequest(
            analysisId: "analysis-\(UUID().uuidString.lowercased())",
            batchId: batchId,
            rowId: "row-\(candidate.rowNumber)",
            sourceFingerprint: sourceFingerprint,
            existingFingerprints: existingFingerprints,
            source: ImportSource(sourceId: String(fileName.prefix(160)), rowPath: "row[\(candidate.rowNumber)]"),
            record: ImportRecordInput(
                date: record.date,
                direction: record.direction,
                amount: record.amount,
                category: record.category.nilIfEmpty,
                counterparty: record.counterparty.nilIfEmpty,
                project: record.project.nilIfEmpty,
                account: record.account.nilIfEmpty,
                description: record.description.nilIfEmpty
            ),
            companyOwnership: CompanyOwnershipEvidence(
                verified: true,
                evidenceText: candidate.companyEvidence,
                fieldPath: "row[\(candidate.rowNumber)].companyOwnership",
                fingerprint: ownershipFingerprint
            )
        )
    }

    private static func digest(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct RowReader {
    let values: [String: String]

    func callAsFunction(_ aliases: String...) -> String {
        aliases.lazy
            .compactMap { values[$0.replacingOccurrences(of: "\u{feff}", with: "")
                .replacingOccurrences(of: #"[\s_\-/]"#, with: "", options: .regularExpression)
                .lowercased()] }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func trimmingPrefix(_ prefix: Character) -> String {
        first == prefix ? String(dropFirst()) : self
    }
}
