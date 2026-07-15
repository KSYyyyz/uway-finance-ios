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

struct RegistrationCapability: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?
    let codeEndpoint: String?
    let registerEndpoint: String?
    let phoneVerification: String?
    let createsIsolatedOrganizationAndAccountBook: Bool?
    let sessionCookie: String?

    var safeForClientUse: Bool {
        available
            && codeEndpoint == "/api/auth/registration-code"
            && registerEndpoint == "/api/auth/register"
            && phoneVerification == "sms_webhook"
            && createsIsolatedOrganizationAndAccountBook == true
            && sessionCookie == "http_only_secure_same_site_strict"
    }

    var statusDisplay: String {
        if safeForClientUse { return "手机验证注册可用" }
        if reason == "sms_provider_not_configured" { return "短信服务未配置" }
        return "注册暂不可用"
    }

    var unavailableMessage: String {
        reason == "sms_provider_not_configured"
            ? "服务器尚未配置短信验证码服务，当前不能注册新账号。"
            : "服务器暂未开放安全注册能力。"
    }

    static let unavailableFallback = RegistrationCapability(
        available: false,
        reason: "capabilities_unavailable",
        codeEndpoint: nil,
        registerEndpoint: nil,
        phoneVerification: nil,
        createsIsolatedOrganizationAndAccountBook: nil,
        sessionCookie: nil
    )
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

enum ClassificationPreferenceLearningState: String, Codable, CaseIterable, Sendable {
    case shadow
    case provisional
    case active

    var label: String {
        switch self {
        case .shadow: "影子学习"
        case .provisional: "暂行学习"
        case .active: "已生效"
        }
    }
}

struct ClassificationPreferenceMemoryCapability: Codable, Equatable, Sendable {
    let available: Bool
    let listEndpoint: String
    let revokeEndpoint: String
    let pagination: String
    let scope: String
    let source: String
    let minimumConsistentObservations: Int
    let minimumConsistency: Double
    let lifecycleStates: [String]
    let effect: String
    let idempotencyHeader: String
    let concurrencyControl: String
    let modelCanAccept: Bool
    let writesBusinessRecords: Bool
    let learningState: ClassificationPreferenceLearningState?
    let normalizationVersion: String?
    let companyScoped: Bool?
    let reasonCodes: [String]?
    let learningStates: [ClassificationPreferenceLearningState]?
    let similarity: String?
    let provisionalMinimumConsistentObservations: Int?

    var safeForClientUse: Bool {
        available
            && listEndpoint == "/api/v2/classification-preferences"
            && revokeEndpoint == "/api/v2/classification-preferences/:observationId/revoke"
            && pagination == "cursor"
            && scope == "account_book"
            && source == "explicit_authenticated_human_decisions"
            && minimumConsistentObservations == 3
            && minimumConsistency == 0.8
            && Set(lifecycleStates) == Set(["active", "revoked", "invalidated"])
            && effect == "closed_candidate_reordering_only"
            && idempotencyHeader == "Idempotency-Key"
            && concurrencyControl == "expectedVersion"
            && modelCanAccept == false
            && writesBusinessRecords == false
    }

    var semanticV2SafeForClientUse: Bool {
        safeForClientUse
            && normalizationVersion == "semantic-preference-v2"
            && companyScoped == true
            && Set(learningStates ?? []) == Set(ClassificationPreferenceLearningState.allCases)
            && similarity == "complete_link_semantic"
            && provisionalMinimumConsistentObservations == 2
    }

    var statusDisplay: String {
        guard safeForClientUse else { return "未开放" }
        if semanticV2SafeForClientUse { return "账套级语义偏好 v2 可用" }
        guard let learningState else { return "账套级安全可用（兼容模式）" }
        return "账套级安全可用 · \(learningState.label)"
    }
}

struct DocumentUploadCapability: Codable, Equatable, Sendable {
    let available: Bool
    let listEndpoint: String?
    let coverageEndpoint: String?
    let uploadEndpoint: String?
    let contentEndpoint: String?
    let revokeEndpoint: String?
    let acceptedMediaTypes: [String]?
    let maxBytes: Int?
    let contentImmutability: String?
    let lifecycle: [String]?
    let deletion: Bool?
    let accountBookScoped: Bool?
    let idempotencyHeader: String?

    var safeForClientUse: Bool {
        available
            && listEndpoint == "/api/v2/business-record-evidence"
            && coverageEndpoint == "/api/v2/business-record-evidence-coverage"
            && uploadEndpoint == "/api/v2/business-record-evidence"
            && contentEndpoint == "/api/v2/business-record-evidence/:evidenceId/content"
            && revokeEndpoint == "/api/v2/business-record-evidence/:evidenceId/revoke"
            && Set(acceptedMediaTypes ?? []) == Set([
                "image/jpeg", "image/png", "image/webp", "image/heic", "image/heif", "application/pdf",
            ])
            && maxBytes == 10_000_000
            && contentImmutability == "database_trigger_and_sha256"
            && Set(lifecycle ?? []) == Set(["active", "revoked"])
            && deletion == false
            && accountBookScoped == true
            && idempotencyHeader == "Idempotency-Key"
    }

    var statusDisplay: String { safeForClientUse ? "不可变原件可用" : "未开放" }

    static let unavailableFallback = DocumentUploadCapability(
        available: false,
        listEndpoint: nil,
        coverageEndpoint: nil,
        uploadEndpoint: nil,
        contentEndpoint: nil,
        revokeEndpoint: nil,
        acceptedMediaTypes: nil,
        maxBytes: nil,
        contentImmutability: nil,
        lifecycle: nil,
        deletion: nil,
        accountBookScoped: nil,
        idempotencyHeader: nil
    )
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
    let registration: RegistrationCapability?
    let importAnalysis: ImportAnalysisCapability
    let unifiedDashboardMetrics: UnifiedDashboardMetricsCapability
    let classificationReview: ClassificationReviewCapability?
    let classificationPreferenceMemory: ClassificationPreferenceMemoryCapability?
    let workflowTasks: CapabilityAvailability
    let aiClassification: AIClassificationCapability
    let documentUpload: DocumentUploadCapability
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
    let registration: RegistrationCapability
    let unifiedDashboardMetrics: Bool
    let dashboardMetrics: UnifiedDashboardMetricsCapability
    let classificationReview: ClassificationReviewCapability?
    let classificationPreferenceMemory: ClassificationPreferenceMemoryCapability?
    let workflowTasks: Bool
    let aiClassification: Bool
    let aiClassificationCapability: AIClassificationCapability
    let deterministicGroupingAvailable: Bool
    let documentUpload: Bool
    let documentUploadCapability: DocumentUploadCapability
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
            registration: response.features.registration ?? .unavailableFallback,
            unifiedDashboardMetrics: response.features.unifiedDashboardMetrics.available,
            dashboardMetrics: response.features.unifiedDashboardMetrics,
            classificationReview: response.features.classificationReview,
            classificationPreferenceMemory: response.features.classificationPreferenceMemory,
            workflowTasks: response.features.workflowTasks.available,
            aiClassification: response.features.aiClassification.available,
            aiClassificationCapability: response.features.aiClassification,
            deterministicGroupingAvailable: response.features.aiClassification.deterministicGroupingAvailable ?? false,
            documentUpload: response.features.documentUpload.available,
            documentUploadCapability: response.features.documentUpload,
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
            registration: .unavailableFallback,
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
            classificationPreferenceMemory: nil,
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
            documentUploadCapability: .unavailableFallback,
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
    static let apiContractVersion = "20260715_010"
    static let financeDomainV2Schema = "20260714_002_finance_resource_api"
    static let classificationReviewSchema = "20260714_003_classification_review"
    static let classificationPreferenceMemorySchema = "20260715_004_account_book_preference_memory"
    static let immutableRecordEvidenceSchema = "20260715_005_immutable_record_evidence"
    static let semanticPreferenceMemoryV2Schema = "20260715_006_semantic_preference_memory_v2"
    static let multiTenantRegistrationSchema = "20260715_007_multi_tenant_registration"

    static func isFinanceDomainV2Schema(_ value: String?) -> Bool {
        value == financeDomainV2Schema
            || value == classificationReviewSchema
            || value == classificationPreferenceMemorySchema
            || value == immutableRecordEvidenceSchema
            || value == semanticPreferenceMemoryV2Schema
            || value == multiTenantRegistrationSchema
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
