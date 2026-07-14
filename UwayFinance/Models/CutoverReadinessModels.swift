import Foundation

struct CutoverReadinessQuery: Equatable, Sendable {
    var accountBookId: String?
    var limit: Int
    var cursor: String?

    init(accountBookId: String? = nil, limit: Int = 50, cursor: String? = nil) {
        self.accountBookId = accountBookId
        self.limit = min(max(limit, 1), 100)
        self.cursor = cursor
    }
}

struct CutoverSnapshot: Codable, Equatable, Sendable {
    let legacyStateUpdatedAt: String
    let legacyDigest: String
    let v2MirrorDigest: String
    let digestsMatch: Bool
}

struct CutoverEntitySummary: Codable, Equatable, Sendable {
    let count: Int
    let income: V2DecimalAmount
    let expense: V2DecimalAmount
}

struct CutoverLegacySummary: Codable, Equatable, Sendable {
    let businessRecords: CutoverEntitySummary
    let bankTransactions: CutoverEntitySummary
}

struct CutoverShadowSummary: Codable, Equatable, Sendable {
    let businessRecords: CutoverEntitySummary
}

struct CutoverSummary: Codable, Equatable, Sendable {
    let legacy: CutoverLegacySummary
    let v2Mirror: CutoverLegacySummary
    let v2ShadowOnly: CutoverShadowSummary
}

struct CutoverBlocker: Codable, Equatable, Sendable {
    let code: String
    let count: Int
    let message: String
}

struct CutoverReadinessState: Codable, Equatable, Sendable {
    let stage: String
    let legacyMirrorConsistent: Bool
    let businessRecordReadCutoverEligible: Bool
    let businessRecordWriteCutoverEligible: Bool
    let fullFinanceCutoverEligible: Bool
    let blockers: [CutoverBlocker]
}

enum CutoverDifferenceEntity: String, Codable, Equatable, Sendable {
    case businessRecord = "business_record"
    case bankTransaction = "bank_transaction"
}

enum CutoverDifferenceKind: String, Codable, Equatable, Sendable {
    case legacyDuplicateID = "legacy_duplicate_id"
    case missingInV2Mirror = "missing_in_v2_mirror"
    case fieldMismatch = "field_mismatch"
    case staleV2MirrorRow = "stale_v2_mirror_row"
    case shadowOnlyV2Record = "shadow_only_v2_record"
}

struct CutoverDifference: Codable, Equatable, Sendable {
    let key: String
    let entity: CutoverDifferenceEntity
    let externalId: String
    let kind: CutoverDifferenceKind
    let fields: [String]
}

struct CutoverDifferencePage: Codable, Equatable, Sendable {
    let limit: Int
    let nextCursor: String?
}

struct CutoverDifferences: Codable, Equatable, Sendable {
    let total: Int
    let items: [CutoverDifference]
    let page: CutoverDifferencePage
}

struct CutoverReadinessResponse: Codable, Equatable, Sendable {
    let accountBook: FinanceAccountBookAccess
    let generatedAt: String
    let snapshot: CutoverSnapshot
    let summary: CutoverSummary
    let readiness: CutoverReadinessState
    let differences: CutoverDifferences
}
