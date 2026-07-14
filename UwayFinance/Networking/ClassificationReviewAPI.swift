import SwiftUI

protocol ClassificationReviewAPI: Sendable {
    func list(_ query: ClassificationReviewQuery) async throws -> ClassificationReviewListResponse
    func analyze(_ command: ClassificationAnalyzeCommand) async throws -> ClassificationAnalysisResponse
    func decide(_ command: ClassificationDecisionCommand) async throws -> ClassificationDecisionResponse
}

actor LiveClassificationReviewAPI: ClassificationReviewAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func list(_ query: ClassificationReviewQuery) async throws -> ClassificationReviewListResponse {
        try await transport.send(.classificationReviews(query))
    }

    func analyze(_ command: ClassificationAnalyzeCommand) async throws -> ClassificationAnalysisResponse {
        try await transport.send(
            .analyzeClassification(recordId: command.recordId),
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }

    func decide(_ command: ClassificationDecisionCommand) async throws -> ClassificationDecisionResponse {
        try await transport.send(
            .decideClassification(recordId: command.recordId),
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }
}

private struct ClassificationReviewAPIKey: EnvironmentKey {
    static let defaultValue: any ClassificationReviewAPI = UnavailableClassificationReviewAPI()
}

extension EnvironmentValues {
    var classificationReviewAPI: any ClassificationReviewAPI {
        get { self[ClassificationReviewAPIKey.self] }
        set { self[ClassificationReviewAPIKey.self] = newValue }
    }
}

actor UnavailableClassificationReviewAPI: ClassificationReviewAPI {
    func list(_ query: ClassificationReviewQuery) async throws -> ClassificationReviewListResponse {
        throw APIError.unavailable("分类复核接口尚未配置")
    }

    func analyze(_ command: ClassificationAnalyzeCommand) async throws -> ClassificationAnalysisResponse {
        throw APIError.unavailable("AI 分类建议暂不可用")
    }

    func decide(_ command: ClassificationDecisionCommand) async throws -> ClassificationDecisionResponse {
        throw APIError.unavailable("分类复核决定接口尚未配置")
    }
}
