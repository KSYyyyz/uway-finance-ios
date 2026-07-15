import Foundation

enum ClassificationPreferenceListState: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case revoked
    case invalidated
    case all

    var id: String { rawValue }
    var label: String {
        switch self {
        case .active: "生效中"
        case .revoked: "已撤销"
        case .invalidated: "已失效"
        case .all: "全部"
        }
    }
}

enum ClassificationPreferenceLifecycleState: String, Codable, Sendable {
    case active
    case revoked
    case invalidated

    var label: String {
        switch self {
        case .active: "生效中"
        case .revoked: "已撤销"
        case .invalidated: "已失效"
        }
    }
}

struct ClassificationPreferenceQuery: Equatable, Sendable {
    let accountBookId: String
    var state: ClassificationPreferenceListState
    var limit: Int
    var cursor: String?

    init(
        accountBookId: String,
        state: ClassificationPreferenceListState = .active,
        limit: Int = 10,
        cursor: String? = nil
    ) {
        self.accountBookId = accountBookId
        self.state = state
        self.limit = min(max(limit, 1), 100)
        self.cursor = cursor
    }
}

struct ClassificationPreferenceFeatures: Codable, Equatable, Sendable {
    let merchantTokens: [String]
    let serviceTokens: [String]
    let itemTokens: [String]
    let direction: Direction
    let eventTime: String
}

struct ClassificationPreferenceDecision: Codable, Equatable, Sendable {
    let action: ClassificationDecisionAction
    let taxonomyCode: String?
    let groupKey: String?
    let previousTaxonomyCode: String?
    let previousGroupKey: String?
}

struct ClassificationPreferenceLifecycle: Codable, Equatable, Sendable {
    let state: ClassificationPreferenceLifecycleState
    let reason: String?
    let changedAt: String?
}

struct ClassificationPreferenceObservation: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let accountBookId: String
    let recordId: String?
    let direction: Direction
    let features: ClassificationPreferenceFeatures
    let decision: ClassificationPreferenceDecision
    let lifecycle: ClassificationPreferenceLifecycle
    let version: Int
    let decidedAt: String
    let lastUsedAt: String?
}

struct ClassificationPreferencePage: Codable, Equatable, Sendable {
    let limit: Int
    let nextCursor: String?
}

struct ClassificationPreferenceSafety: Codable, Equatable, Sendable {
    let accountBookScoped: Bool
    let modelCanAccept: Bool
    let writesBusinessRecords: Bool
}

struct ClassificationPreferenceListResponse: Codable, Equatable, Sendable {
    let accountBook: FinanceAccountBookAccess
    let items: [ClassificationPreferenceObservation]
    let page: ClassificationPreferencePage
    let safety: ClassificationPreferenceSafety
}

struct ClassificationPreferenceRevokeRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let expectedVersion: Int
    let reason: String
}

struct ClassificationPreferenceRevokeSafety: Codable, Equatable, Sendable {
    let recomputedFromActiveEvents: Bool
    let modelCanAccept: Bool
    let writesBusinessRecords: Bool
}

struct ClassificationPreferenceRevokeResponse: Codable, Equatable, Sendable {
    let observation: ClassificationPreferenceObservation
    let safety: ClassificationPreferenceRevokeSafety
}

struct ClassificationPreferenceRevokeCommand: Equatable, Sendable {
    let observationId: String
    let request: ClassificationPreferenceRevokeRequest
    let idempotencyKey: IdempotencyKey

    init(
        observationId: String,
        request: ClassificationPreferenceRevokeRequest,
        operationID: UUID = UUID()
    ) {
        self.observationId = observationId
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "classification-preference-revoke", operationID: operationID)
    }
}
