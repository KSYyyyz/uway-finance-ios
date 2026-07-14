import Foundation

enum Direction: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }
    var label: String { self == .income ? "收入" : "支出" }
}

enum SettlementStatus: String, Codable { case settled, unsettled }
enum InvoiceStatus: String, Codable { case received, pending, notRequired = "not_required" }
enum FinanceStatus: String, Codable { case draft, submitted, booked }
enum ContractStatus: String, Codable { case attached, notRequired = "not_required", missing }
enum SupportingDocumentStatus: String, Codable { case complete, pending, notRequired = "not_required" }
enum RecordSource: String, Codable { case manual, csv }
enum BankMatchStatus: String, Codable { case unmatched, suggested, matched, ignored }
enum AnalysisDecision: String, Codable { case harnessAccepted = "harness_accepted", humanAccepted = "human_accepted" }

enum RecordScenario: String, Codable, CaseIterable, Identifiable {
    case formalIncome = "formal_income"
    case capitalIncome = "capital_income"
    case refundIncome = "refund_income"
    case formalExpense = "formal_expense"
    case dailyExpense = "daily_expense"
    case travel
    case employeeReimbursement = "employee_reimbursement"
    case payroll
    case taxAndBenefits = "tax_and_benefits"
    case otherExpense = "other_expense"

    var id: String { rawValue }
}

struct BusinessRecord: Codable, Identifiable, Hashable {
    var id: String
    var date: String
    var direction: Direction
    @LegacyMoney var amount: Double
    var category: String
    var counterparty: String
    var project: String
    var account: String
    var settlementStatus: SettlementStatus
    var invoiceStatus: InvoiceStatus
    var financeStatus: FinanceStatus
    var contractStatus: ContractStatus
    var description: String
    var dueDate: String? = nil
    var bankReference: String? = nil
    var source: RecordSource? = nil
    var importedAt: String? = nil
    var scenario: RecordScenario? = nil
    var businessPeriod: String? = nil
    var employeeName: String? = nil
    var supportingDocumentStatus: SupportingDocumentStatus? = nil
    var supportingDocumentNote: String? = nil
    var importAnalysisId: String? = nil
    var sourceFingerprint: String? = nil
    var analysisDecision: AnalysisDecision? = nil
}

struct BankTransaction: Codable, Identifiable, Hashable {
    var id: String
    var date: String
    var direction: Direction
    @LegacyMoney var amount: Double
    var counterparty: String
    var description: String
    var account: String
    var reference: String
    var sourceFile: String
    var importedAt: String
    var matchStatus: BankMatchStatus
    var matchedRecordId: String? = nil
    var suggestedRecordId: String? = nil
}

struct AppStatePayload: Codable, Equatable {
    var records: [BusinessRecord]
    var bankTransactions: [BankTransaction]
    var completedLessons: [String]
    var completedClose: [String]

    static let empty = AppStatePayload(
        records: [],
        bankTransactions: [],
        completedLessons: [],
        completedClose: []
    )
}

struct StateEnvelope: Codable {
    let data: AppStatePayload
    let updatedAt: String?
}

struct SessionUser: Codable, Identifiable, Equatable {
    let id: String
    let username: String
}

struct SessionEnvelope: Codable { let user: SessionUser }
struct HealthResponse: Codable, Equatable {
    let status: String
    let version: String
    let financeSchemaVersion: String?

    init(status: String, version: String, financeSchemaVersion: String? = nil) {
        self.status = status
        self.version = version
        self.financeSchemaVersion = financeSchemaVersion
    }
}
struct MutationResponse: Codable { let ok: Bool; let updatedAt: String? }
struct OKResponse: Codable { let ok: Bool }

extension BusinessRecord {
    var preciseAmount: MoneyAmount { $amount }
}

extension BankTransaction {
    var preciseAmount: MoneyAmount { $amount }
}
