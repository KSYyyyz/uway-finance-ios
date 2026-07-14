import Foundation

enum FinanceSyncMode: String, Codable, Equatable, Sendable {
    case legacyStateV1 = "legacy_state_v1"

    var displayName: String { "旧状态兼容同步" }
}

struct CapabilityAvailability: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?

    init(available: Bool, reason: String? = nil) {
        self.available = available
        self.reason = reason
    }
}

struct LegacyStateCapability: Codable, Equatable, Sendable {
    let readable: Bool
    let writable: Bool
    let conflictControl: String
}

struct SyncCapabilitiesResponse: Codable, Equatable, Sendable {
    let preferredMode: String
    let availableModes: [String]
    let legacyState: LegacyStateCapability
    let financeResources: CapabilityAvailability
}

struct MoneyCapabilitiesResponse: Codable, Equatable, Sendable {
    let legacyStateEncoding: String
    let financeV2Encoding: String
    let databasePrecision: Int
    let databaseScale: Int
}

struct ImportAnalysisCapability: Codable, Equatable, Sendable {
    let available: Bool
    let contract: String
    let decisions: [String]
}

struct FeatureCapabilitiesResponse: Codable, Equatable, Sendable {
    let importAnalysis: ImportAnalysisCapability
    let unifiedDashboardMetrics: CapabilityAvailability
    let workflowTasks: CapabilityAvailability
    let aiClassification: CapabilityAvailability
    let documentUpload: CapabilityAvailability
    let ocr: CapabilityAvailability
}

struct SafetyCapabilitiesResponse: Codable, Equatable, Sendable {
    let aiMayWriteBusinessRecords: Bool
    let aiMayPostJournalVouchers: Bool
    let acceptedImportRequiresHarnessOrHumanDecision: Bool
}

struct ServerCapabilitiesResponse: Codable, Equatable, Sendable {
    let version: String
    let apiContractVersion: String
    let financeSchemaVersion: String
    let sync: SyncCapabilitiesResponse
    let money: MoneyCapabilitiesResponse
    let features: FeatureCapabilitiesResponse
    let safety: SafetyCapabilitiesResponse
}

enum CapabilityNegotiationSource: Equatable, Sendable {
    case server
    case legacyFallback
}

struct ServerCapabilities: Equatable, Sendable {
    let syncMode: FinanceSyncMode
    let financeDomainV2Mirror: Bool
    let financeResourceAPI: Bool
    let importHarnessStatuses: Set<String>
    let importAnalysis: Bool
    let unifiedDashboardMetrics: Bool
    let workflowTasks: Bool
    let aiClassification: Bool
    let documentUpload: Bool
    let ocr: Bool
    let money: MoneyCapabilitiesResponse
    let safety: SafetyCapabilitiesResponse
    let source: CapabilityNegotiationSource

    static func negotiated(
        _ response: ServerCapabilitiesResponse,
        financeSchemaVersion: String?
    ) -> ServerCapabilities {
        let supportedMode = FinanceSyncMode(rawValue: response.sync.preferredMode)
        let modeIsAvailable = response.sync.availableModes.contains(response.sync.preferredMode)
        guard supportedMode == .legacyStateV1, modeIsAvailable else {
            return .legacyFallback(financeSchemaVersion: financeSchemaVersion)
        }

        return ServerCapabilities(
            syncMode: .legacyStateV1,
            financeDomainV2Mirror: financeSchemaVersion == BackendContract.financeDomainV2Schema,
            financeResourceAPI: response.sync.financeResources.available,
            importHarnessStatuses: Set(response.features.importAnalysis.decisions),
            importAnalysis: response.features.importAnalysis.available,
            unifiedDashboardMetrics: response.features.unifiedDashboardMetrics.available,
            workflowTasks: response.features.workflowTasks.available,
            aiClassification: response.features.aiClassification.available,
            documentUpload: response.features.documentUpload.available,
            ocr: response.features.ocr.available,
            money: response.money,
            safety: response.safety,
            source: .server
        )
    }

    static func legacyFallback(financeSchemaVersion: String?) -> ServerCapabilities {
        ServerCapabilities(
            syncMode: .legacyStateV1,
            financeDomainV2Mirror: financeSchemaVersion == BackendContract.financeDomainV2Schema,
            financeResourceAPI: false,
            importHarnessStatuses: ["accepted", "review", "rejected"],
            importAnalysis: true,
            unifiedDashboardMetrics: false,
            workflowTasks: false,
            aiClassification: false,
            documentUpload: false,
            ocr: false,
            money: MoneyCapabilitiesResponse(
                legacyStateEncoding: "json_number",
                financeV2Encoding: "decimal_string",
                databasePrecision: 18,
                databaseScale: 2
            ),
            safety: SafetyCapabilitiesResponse(
                aiMayWriteBusinessRecords: false,
                aiMayPostJournalVouchers: false,
                acceptedImportRequiresHarnessOrHumanDecision: true
            ),
            source: .legacyFallback
        )
    }
}

struct BackendContract: Equatable, Sendable {
    static let apiContractVersion = "20260714_001"
    static let financeDomainV2Schema = "20260714_001_finance_domain_v2"

    let serverVersion: String
    let financeSchemaVersion: String?
    let negotiatedAPIContractVersion: String?
    let capabilities: ServerCapabilities

    init(health: HealthResponse, negotiated: ServerCapabilitiesResponse? = nil) {
        serverVersion = health.version
        financeSchemaVersion = health.financeSchemaVersion ?? negotiated?.financeSchemaVersion
        negotiatedAPIContractVersion = negotiated?.apiContractVersion
        if let negotiated {
            capabilities = .negotiated(negotiated, financeSchemaVersion: financeSchemaVersion)
        } else {
            capabilities = .legacyFallback(financeSchemaVersion: financeSchemaVersion)
        }
    }

    var financeSchemaDisplay: String {
        financeSchemaVersion ?? "未提供（兼容 0.8.x）"
    }

    var apiContractDisplay: String {
        negotiatedAPIContractVersion ?? "未提供（安全降级）"
    }
}
