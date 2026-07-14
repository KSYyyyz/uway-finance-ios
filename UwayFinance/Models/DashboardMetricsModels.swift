import Foundation

struct DashboardMetricsQuery: Equatable, Sendable {
    var period: String?
    var accountBookId: String?

    init(period: String? = nil, accountBookId: String? = nil) {
        self.period = period
        self.accountBookId = accountBookId
    }
}

struct DashboardMetricDefinition: Codable, Equatable, Sendable {
    let code: String
    let version: Int
    let moneyEncoding: String
    let basis: String
}

struct DashboardOverview: Codable, Equatable, Sendable {
    let paidIncome: V2DecimalAmount
    let paidExpense: V2DecimalAmount
    let netCashFlow: V2DecimalAmount
    let outstandingIncome: V2DecimalAmount
    let missingMaterialsCount: Int
    let periodRecordCount: Int
}

struct DashboardTrendPoint: Codable, Equatable, Sendable {
    let period: String
    let label: String
    let received: V2DecimalAmount
    let paid: V2DecimalAmount
}

enum DashboardClassificationState: String, Codable, Equatable, Sendable {
    case accepted
    case review
    case unclassified
}

struct DashboardGroupTrace: Codable, Equatable, Sendable {
    let origins: [String]
    let reasons: [String]
}

struct DashboardMetricGroup: Codable, Identifiable, Equatable, Sendable {
    var id: String { groupKey }

    let groupKey: String
    let label: String
    let direction: Direction
    let categoryCode: String?
    let categoryLabel: String
    let amount: V2DecimalAmount
    let recordCount: Int
    let recordIds: [String]
    let classificationState: DashboardClassificationState
    let trace: DashboardGroupTrace
}

struct DashboardClassificationCoverage: Codable, Equatable, Sendable {
    let accepted: Int
    let review: Int
    let unclassified: Int
}

struct DashboardMetricsSafety: Codable, Equatable, Sendable {
    let rawBusinessRecordsMerged: Bool
    let modelWritesBusinessRecords: Bool
    let reviewSuggestionsAffectRawFacts: Bool
}

struct DashboardMetricsResponse: Codable, Equatable, Sendable {
    let accountBook: FinanceAccountBookAccess
    let period: String
    let generatedAt: String
    let metricDefinition: DashboardMetricDefinition
    let overview: DashboardOverview
    let trend: [DashboardTrendPoint]
    let categoryGroups: [DashboardMetricGroup]
    let sameTypeGroups: [DashboardMetricGroup]
    let classificationCoverage: DashboardClassificationCoverage
    let safety: DashboardMetricsSafety
}
