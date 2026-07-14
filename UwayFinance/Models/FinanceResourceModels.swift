import Foundation

/// Finance Resource V2 encodes money as a decimal string while reusing the
/// exact integer-cent domain representation.
struct V2DecimalAmount: Codable, Hashable, Sendable {
    let value: MoneyAmount

    init(_ value: MoneyAmount) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        do {
            value = try MoneyAmount(decimalString: text)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "V2 amount must be a decimal string with at most two fractional digits"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.decimalString)
    }
}

struct FinanceResourcePermissions: Codable, Equatable, Sendable {
    let readBusinessRecords: Bool
    let writeBusinessRecords: Bool
}

struct FinanceResourceOrganization: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

struct FinanceAccountBookAccess: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let baseCurrency: String
    let organization: FinanceResourceOrganization
    let role: String
    let permissions: FinanceResourcePermissions
}

struct FinanceContextResponse: Codable, Equatable, Sendable {
    let selectedAccountBook: FinanceAccountBookAccess
    let accountBooks: [FinanceAccountBookAccess]
}

struct BusinessRecordResourceSource: Codable, Equatable, Sendable {
    let system: String
    let kind: String
}

struct BusinessRecordResource: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let externalId: String
    let eventDate: String
    let direction: Direction
    let amount: V2DecimalAmount
    let category: String
    let counterparty: String
    let project: String
    let account: String
    let description: String
    let settlementStatus: SettlementStatus
    let invoiceStatus: InvoiceStatus
    let financeStatus: FinanceStatus
    let contractStatus: ContractStatus
    let dueDate: String?
    let bankReference: String?
    let scenario: RecordScenario?
    let businessPeriod: String?
    let employeeName: String?
    let supportingDocumentStatus: SupportingDocumentStatus?
    let supportingDocumentNote: String?
    let source: BusinessRecordResourceSource
    let version: Int
    let createdAt: String
    let updatedAt: String

    var preciseAmount: MoneyAmount { amount.value }
}

struct BusinessRecordPage: Codable, Equatable, Sendable {
    let limit: Int
    let nextCursor: String?
}

struct BusinessRecordListResponse: Codable, Equatable, Sendable {
    let accountBook: FinanceAccountBookAccess
    let items: [BusinessRecordResource]
    let page: BusinessRecordPage
}

struct BusinessRecordEnvelope: Codable, Equatable, Sendable {
    let record: BusinessRecordResource
}

struct BusinessRecordListQuery: Equatable, Sendable {
    var accountBookId: String?
    var limit: Int
    var cursor: String?
    var direction: Direction?
    var financeStatus: FinanceStatus?

    init(
        accountBookId: String? = nil,
        limit: Int = 20,
        cursor: String? = nil,
        direction: Direction? = nil,
        financeStatus: FinanceStatus? = nil
    ) {
        self.accountBookId = accountBookId
        self.limit = min(max(limit, 1), 100)
        self.cursor = cursor
        self.direction = direction
        self.financeStatus = financeStatus
    }
}

enum BusinessRecordCreateFinanceStatus: String, Codable, Sendable {
    case draft
    case submitted
}

struct BusinessRecordCreateRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let eventDate: String
    let direction: Direction
    let amount: V2DecimalAmount
    var category: String = ""
    var counterparty: String = ""
    var project: String = ""
    var account: String = ""
    var description: String = ""
    var settlementStatus: SettlementStatus = .unsettled
    var invoiceStatus: InvoiceStatus = .pending
    var financeStatus: BusinessRecordCreateFinanceStatus = .draft
    var contractStatus: ContractStatus = .missing
    var dueDate: String? = nil
    var bankReference: String? = nil
    var scenario: RecordScenario? = nil
    var businessPeriod: String? = nil
    var employeeName: String? = nil
    var supportingDocumentStatus: SupportingDocumentStatus? = nil
    var supportingDocumentNote: String? = nil
}

struct BusinessRecordChanges: Codable, Equatable, Sendable {
    var eventDate: String? = nil
    var direction: Direction? = nil
    var amount: V2DecimalAmount? = nil
    var category: String? = nil
    var counterparty: String? = nil
    var project: String? = nil
    var account: String? = nil
    var description: String? = nil
    var settlementStatus: SettlementStatus? = nil
    var invoiceStatus: InvoiceStatus? = nil
    var financeStatus: FinanceStatus? = nil
    var contractStatus: ContractStatus? = nil
    var dueDate: String? = nil
    var bankReference: String? = nil
    var scenario: RecordScenario? = nil
    var businessPeriod: String? = nil
    var employeeName: String? = nil
    var supportingDocumentStatus: SupportingDocumentStatus? = nil
    var supportingDocumentNote: String? = nil
}

struct BusinessRecordPatchRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let expectedVersion: Int
    let changes: BusinessRecordChanges
}

struct IdempotencyKey: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        guard (8...160).contains(rawValue.count) else { return nil }
        self.rawValue = rawValue
    }

    init(operation: String, operationID: UUID = UUID()) {
        rawValue = "ios-\(operation)-\(operationID.uuidString.lowercased())"
    }
}

struct CreateBusinessRecordCommand: Equatable, Sendable {
    let request: BusinessRecordCreateRequest
    let idempotencyKey: IdempotencyKey

    init(request: BusinessRecordCreateRequest, operationID: UUID = UUID()) {
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "create-record", operationID: operationID)
    }
}

struct UpdateBusinessRecordCommand: Equatable, Sendable {
    let recordId: String
    let request: BusinessRecordPatchRequest
    let idempotencyKey: IdempotencyKey

    init(recordId: String, request: BusinessRecordPatchRequest, operationID: UUID = UUID()) {
        self.recordId = recordId
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "update-record", operationID: operationID)
    }
}
