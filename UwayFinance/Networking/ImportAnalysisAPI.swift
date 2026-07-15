import SwiftUI

protocol ImportAnalysisAPI: Sendable {
    func accountBookContext() async throws -> FinanceContextResponse
    func analyze(_ request: ImportAnalysisRequest) async throws -> HarnessResult
    func decide(analysisId: String, decision: ImportReviewDecision) async throws -> ImportReviewDecisionResponse
}

actor LiveImportAnalysisAPI: ImportAnalysisAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) { self.transport = transport }

    func accountBookContext() async throws -> FinanceContextResponse {
        try await transport.send(.financeContext())
    }

    func analyze(_ request: ImportAnalysisRequest) async throws -> HarnessResult {
        try await transport.send(.importAnalysis, body: request)
    }

    func decide(analysisId: String, decision: ImportReviewDecision) async throws -> ImportReviewDecisionResponse {
        try await transport.send(.importDecision(analysisId: analysisId), body: decision)
    }
}

private struct ImportAnalysisAPIKey: EnvironmentKey {
    static let defaultValue: any ImportAnalysisAPI = UnavailableImportAnalysisAPI()
}

extension EnvironmentValues {
    var importAnalysisAPI: any ImportAnalysisAPI {
        get { self[ImportAnalysisAPIKey.self] }
        set { self[ImportAnalysisAPIKey.self] = newValue }
    }
}

actor UnavailableImportAnalysisAPI: ImportAnalysisAPI {
    func accountBookContext() async throws -> FinanceContextResponse {
        throw APIError.unavailable("导入分析账套上下文接口尚未配置")
    }

    func analyze(_ request: ImportAnalysisRequest) async throws -> HarnessResult {
        throw APIError.unavailable("导入分析接口尚未配置")
    }

    func decide(analysisId: String, decision: ImportReviewDecision) async throws -> ImportReviewDecisionResponse {
        throw APIError.unavailable("人工复核接口尚未配置")
    }
}
