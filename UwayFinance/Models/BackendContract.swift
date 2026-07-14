import Foundation

enum FinanceDataMode: String, Equatable, Sendable {
    case legacyStateCompatibility = "legacy_state_compatibility"

    var displayName: String { "旧状态兼容同步" }
}

struct ServerCapabilities: Equatable, Sendable {
    let financeDataMode: FinanceDataMode
    let financeDomainV2Mirror: Bool
    let financeResourceAPI: Bool
    let importHarnessStatuses: Set<String>

    static func current(financeSchemaVersion: String?) -> ServerCapabilities {
        ServerCapabilities(
            financeDataMode: .legacyStateCompatibility,
            financeDomainV2Mirror: financeSchemaVersion == BackendContract.financeDomainV2Schema,
            financeResourceAPI: false,
            importHarnessStatuses: ["accepted", "review", "rejected"]
        )
    }
}

struct BackendContract: Equatable, Sendable {
    static let financeDomainV2Schema = "20260714_001_finance_domain_v2"

    let serverVersion: String
    let financeSchemaVersion: String?
    let capabilities: ServerCapabilities

    init(health: HealthResponse) {
        serverVersion = health.version
        financeSchemaVersion = health.financeSchemaVersion
        capabilities = .current(financeSchemaVersion: health.financeSchemaVersion)
    }

    var financeSchemaDisplay: String {
        financeSchemaVersion ?? "未提供（兼容 0.8.x）"
    }
}
