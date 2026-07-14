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

struct UnifiedDashboardMetricsCapability: Codable, Equatable, Sendable {
    let available: Bool
    let endpoint: String?
    let moneyEncoding: String?
    let source: String?
    let rawRecordsMerged: Bool?
    let classificationStates: [String]?
}

struct AIClassificationCapability: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?
    let contract: String?
    let deterministicGroupingAvailable: Bool?
    let modelCanAccept: Bool?
    let writesBusinessRecords: Bool?
}

struct ClassificationReviewCapability: Codable, Equatable, Sendable {
    let available: Bool
    let listEndpoint: String
    let analyzeEndpoint: String
    let decisionEndpoint: String
    let pagination: String
    let defaultPageSize: Int
    let decisions: [String]
    let idempotencyHeader: String
    let concurrencyControl: [String]
    let modelCanAccept: Bool
    let deterministicRuleMayAccept: Bool
    let rawBusinessRecordsChanged: Bool
}

struct LegacyStateCapability: Codable, Equatable, Sendable {
    let readable: Bool
    let writable: Bool
    let conflictControl: String
    let versionSource: String?
    let etagHeader: String?
    let conditionalWriteHeader: String?
}

struct BusinessRecordResourceCapability: Codable, Equatable, Sendable {
    let list: Bool
    let create: Bool
    let update: Bool
    let delete: Bool
    let pagination: String
    let moneyEncoding: String
    let idempotencyHeader: String
    let concurrencyControl: String
}

struct CutoverReadinessCapability: Codable, Equatable, Sendable {
    let available: Bool
    let endpoint: String
    let pagination: String
    let requiresZeroDifferences: Bool
    let requiresZeroShadowOnlyRecords: Bool
    let clientWritesEnabled: Bool
}

struct FinanceResourceCapability: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?
    let cutoverState: String?
    let contextEndpoint: String?
    let cutoverReadiness: CutoverReadinessCapability?
    let businessRecords: BusinessRecordResourceCapability?

    static let unavailable = FinanceResourceCapability(
        available: false,
        reason: "capabilities_unavailable",
        cutoverState: nil,
        contextEndpoint: nil,
        cutoverReadiness: nil,
        businessRecords: nil
    )

    var statusDisplay: String {
        if available, cutoverState == "shadow" { return "Shadow 可用（未切换）" }
        return available ? "可用" : "尚未开放"
    }
}

struct SyncCapabilitiesResponse: Codable, Equatable, Sendable {
    let preferredMode: String
    let availableModes: [String]
    let legacyState: LegacyStateCapability
    let financeResources: FinanceResourceCapability
}

struct MoneyCapabilitiesResponse: Codable, Equatable, Sendable {
    let legacyStateEncoding: String
    let financeV2Encoding: String
    let databasePrecision: Int
    let databaseScale: Int
}

struct ImportAnalysisCapability: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?
    let contract: String
    let decisions: [String]

    static let unavailableFallback = ImportAnalysisCapability(
        available: false,
        reason: "capabilities_unavailable",
        contract: "import_harness_v1",
        decisions: ["accepted", "review", "rejected"]
    )

    static let serviceUnavailable = ImportAnalysisCapability(
        available: false,
        reason: "service_unavailable",
        contract: "import_harness_v1",
        decisions: ["accepted", "review", "rejected"]
    )

    var statusDisplay: String {
        if available { return "可用" }
        switch reason {
        case "provider_not_configured": return "未配置模型服务"
        case "capabilities_unavailable": return "能力信息不可用"
        case "service_unavailable": return "服务不可用"
        default: return "暂不可用"
        }
    }

    var unavailableMessage: String {
        switch reason {
        case "provider_not_configured": return "服务器尚未配置 DeepSeek 分析服务，暂时不能进行 AI 核验。"
        case "capabilities_unavailable": return "当前服务器未公布导入分析能力，为避免误发请求，已暂停 AI 核验。"
        case "service_unavailable": return "服务器暂时不可用，恢复连接后才能进行 AI 核验。"
        default: return "服务器暂未开放导入分析能力。"
        }
    }
}

struct FeatureCapabilitiesResponse: Codable, Equatable, Sendable {
    let importAnalysis: ImportAnalysisCapability
    let unifiedDashboardMetrics: UnifiedDashboardMetricsCapability
    let classificationReview: ClassificationReviewCapability?
    let workflowTasks: CapabilityAvailability
    let aiClassification: AIClassificationCapability
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
    let legacyState: LegacyStateCapability
    let financeDomainV2Mirror: Bool
    let financeResources: FinanceResourceCapability
    let importHarnessStatuses: Set<String>
    let importAnalysis: ImportAnalysisCapability
    let unifiedDashboardMetrics: Bool
    let dashboardMetrics: UnifiedDashboardMetricsCapability
    let classificationReview: ClassificationReviewCapability?
    let workflowTasks: Bool
    let aiClassification: Bool
    let aiClassificationCapability: AIClassificationCapability
    let deterministicGroupingAvailable: Bool
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
            legacyState: response.sync.legacyState,
            financeDomainV2Mirror: BackendContract.isFinanceDomainV2Schema(financeSchemaVersion),
            financeResources: response.sync.financeResources,
            importHarnessStatuses: Set(response.features.importAnalysis.decisions),
            importAnalysis: response.features.importAnalysis,
            unifiedDashboardMetrics: response.features.unifiedDashboardMetrics.available,
            dashboardMetrics: response.features.unifiedDashboardMetrics,
            classificationReview: response.features.classificationReview,
            workflowTasks: response.features.workflowTasks.available,
            aiClassification: response.features.aiClassification.available,
            aiClassificationCapability: response.features.aiClassification,
            deterministicGroupingAvailable: response.features.aiClassification.deterministicGroupingAvailable ?? false,
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
            legacyState: LegacyStateCapability(
                readable: true,
                writable: true,
                conflictControl: "unknown",
                versionSource: nil,
                etagHeader: nil,
                conditionalWriteHeader: nil
            ),
            financeDomainV2Mirror: BackendContract.isFinanceDomainV2Schema(financeSchemaVersion),
            financeResources: .unavailable,
            importHarnessStatuses: ["accepted", "review", "rejected"],
            importAnalysis: .unavailableFallback,
            unifiedDashboardMetrics: false,
            dashboardMetrics: UnifiedDashboardMetricsCapability(
                available: false,
                endpoint: nil,
                moneyEncoding: nil,
                source: nil,
                rawRecordsMerged: nil,
                classificationStates: nil
            ),
            classificationReview: nil,
            workflowTasks: false,
            aiClassification: false,
            aiClassificationCapability: AIClassificationCapability(
                available: false,
                reason: "capabilities_unavailable",
                contract: nil,
                deterministicGroupingAvailable: false,
                modelCanAccept: false,
                writesBusinessRecords: false
            ),
            deterministicGroupingAvailable: false,
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

    var financeResourceAPI: Bool { financeResources.available }
}

struct BackendContract: Equatable, Sendable {
    static let apiContractVersion = "20260714_007"
    static let financeDomainV2Schema = "20260714_002_finance_resource_api"
    static let classificationReviewSchema = "20260714_003_classification_review"

    static func isFinanceDomainV2Schema(_ value: String?) -> Bool {
        value == financeDomainV2Schema || value == classificationReviewSchema
    }

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
