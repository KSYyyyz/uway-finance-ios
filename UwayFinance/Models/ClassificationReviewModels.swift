import Foundation

enum ClassificationReviewState: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case accepted
    case rejected

    var id: String { rawValue }
    var label: String {
        switch self {
        case .pending: "待复核"
        case .accepted: "已确认"
        case .rejected: "已拒绝"
        }
    }
}

enum ClassificationState: String, Codable, Sendable {
    case accepted
    case review
    case unclassified
}

enum ClassificationDecisionAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case confirm
    case correct
    case reject

    var id: String { rawValue }
    var label: String {
        switch self {
        case .confirm: "确认"
        case .correct: "更正"
        case .reject: "拒绝"
        }
    }
}

struct ClassificationReviewQuery: Equatable, Sendable {
    var state: ClassificationReviewState
    var limit: Int
    var cursor: String?
    var accountBookId: String?
    var period: String?

    init(
        state: ClassificationReviewState = .pending,
        limit: Int = 10,
        cursor: String? = nil,
        accountBookId: String? = nil,
        period: String? = nil
    ) {
        self.state = state
        self.limit = min(max(limit, 1), 10)
        self.cursor = cursor
        self.accountBookId = accountBookId
        self.period = period
    }
}

struct ClassificationTaxonomyItem: Codable, Identifiable, Equatable, Sendable {
    var id: String { "\(direction.rawValue):\(code)" }
    let code: String
    let name: String
    let direction: Direction
    let version: Int
}

struct ClassificationReviewRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let externalId: String
    let eventDate: String
    let direction: Direction
    let amount: V2DecimalAmount
    let category: String
    let counterparty: String
    let description: String
    let version: Int
}

struct ClassificationProposal: Codable, Equatable, Sendable {
    let classificationId: String?
    let version: Int
    let taxonomyCode: String?
    let taxonomyName: String
    let normalizedItemName: String
    let groupKey: String
    let classificationState: ClassificationState
    let persistedStatus: String?
    let origin: String
    let confidence: Double?
    let reasonCode: String
    let reason: String?
    let sourceFactHash: String
    let stale: Bool
    let reviewedAt: String?
}

struct ClassificationReviewSafety: Codable, Equatable, Sendable {
    let rawBusinessRecordChanged: Bool
    let modelCanAccept: Bool
}

struct ClassificationReviewListSafety: Codable, Equatable, Sendable {
    let rawBusinessRecordsChanged: Bool
    let modelCanAccept: Bool
}

struct ClassificationReviewItem: Codable, Identifiable, Equatable, Sendable {
    var id: String { record.id }
    let record: ClassificationReviewRecord
    let reviewState: ClassificationReviewState
    let proposal: ClassificationProposal
    let allowedActions: [ClassificationDecisionAction]
    let safety: ClassificationReviewSafety
}

struct ClassificationReviewFilters: Codable, Equatable, Sendable {
    let period: String?
    let state: String
}

struct ClassificationReviewPage: Codable, Equatable, Sendable {
    let limit: Int
    let nextCursor: String?
}

struct ClassificationReviewListResponse: Codable, Equatable, Sendable {
    let accountBook: FinanceAccountBookAccess
    let taxonomy: [ClassificationTaxonomyItem]
    let filters: ClassificationReviewFilters
    let items: [ClassificationReviewItem]
    let page: ClassificationReviewPage
    let safety: ClassificationReviewListSafety
}

struct ClassificationVersionRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let expectedRecordVersion: Int
    let expectedClassificationVersion: Int
}

enum ClassificationAnalysisStatus: String, Codable, Sendable {
    case accepted
    case review
    case rejected
}

struct ClassificationAnalysisResult: Codable, Equatable, Sendable {
    let id: String
    let status: ClassificationAnalysisStatus
    let origin: String
    let taxonomyCode: String?
    let normalizedItemName: String?
    let groupKey: String?
    let evidenceRefs: [String]
    let reasonCode: String
    let confidence: Double
    let issueCodes: [String]
    let writesBusinessRecord: Bool
    let classificationVersion: Int
    let persistedClassification: Bool
}

struct ClassificationAnalysisSafety: Codable, Equatable, Sendable {
    let rawBusinessRecordChanged: Bool
    let modelCanAccept: Bool
    let modelWritesBusinessRecords: Bool
}

struct ClassificationAnalysisResponse: Codable, Equatable, Sendable {
    let recordId: String
    let analysis: ClassificationAnalysisResult
    let safety: ClassificationAnalysisSafety
}

struct ClassificationDecisionRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let action: ClassificationDecisionAction
    let expectedRecordVersion: Int
    let expectedClassificationVersion: Int
    let taxonomyCode: String?
    let normalizedItemName: String?
    let reason: String
}

struct ClassificationDecisionResult: Codable, Equatable, Sendable {
    struct Classification: Codable, Equatable, Sendable {
        let id: String
        let version: Int
        let status: String
        let taxonomyCode: String?
        let taxonomyName: String?
        let normalizedItemName: String
        let groupKey: String
        let sourceFactHash: String
        let reviewedAt: String?
    }

    let action: ClassificationDecisionAction
    let classification: Classification
}

struct ClassificationDecisionResponse: Codable, Equatable, Sendable {
    let recordId: String
    let decision: ClassificationDecisionResult
    let safety: ClassificationReviewSafety
}

struct ClassificationAnalyzeCommand: Equatable, Sendable {
    let recordId: String
    let request: ClassificationVersionRequest
    let idempotencyKey: IdempotencyKey

    init(recordId: String, request: ClassificationVersionRequest, operationID: UUID = UUID()) {
        self.recordId = recordId
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "classification-analyze", operationID: operationID)
    }
}

struct ClassificationDecisionCommand: Equatable, Sendable {
    let recordId: String
    let request: ClassificationDecisionRequest
    let idempotencyKey: IdempotencyKey

    init(recordId: String, request: ClassificationDecisionRequest, operationID: UUID = UUID()) {
        self.recordId = recordId
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "classification-decision", operationID: operationID)
    }
}
