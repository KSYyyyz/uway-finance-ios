import SwiftUI

protocol ClassificationPreferenceAPI: Sendable {
    func list(_ query: ClassificationPreferenceQuery) async throws -> ClassificationPreferenceListResponse
    func revoke(_ command: ClassificationPreferenceRevokeCommand) async throws -> ClassificationPreferenceRevokeResponse
}

actor LiveClassificationPreferenceAPI: ClassificationPreferenceAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func list(_ query: ClassificationPreferenceQuery) async throws -> ClassificationPreferenceListResponse {
        try await transport.send(.classificationPreferences(query))
    }

    func revoke(_ command: ClassificationPreferenceRevokeCommand) async throws -> ClassificationPreferenceRevokeResponse {
        try await transport.send(
            .revokeClassificationPreference(observationId: command.observationId),
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }
}

private struct ClassificationPreferenceAPIKey: EnvironmentKey {
    static let defaultValue: any ClassificationPreferenceAPI = UnavailableClassificationPreferenceAPI()
}

extension EnvironmentValues {
    var classificationPreferenceAPI: any ClassificationPreferenceAPI {
        get { self[ClassificationPreferenceAPIKey.self] }
        set { self[ClassificationPreferenceAPIKey.self] = newValue }
    }
}

actor UnavailableClassificationPreferenceAPI: ClassificationPreferenceAPI {
    func list(_ query: ClassificationPreferenceQuery) async throws -> ClassificationPreferenceListResponse {
        throw APIError.unavailable("账套分类学习记录接口尚未配置")
    }

    func revoke(_ command: ClassificationPreferenceRevokeCommand) async throws -> ClassificationPreferenceRevokeResponse {
        throw APIError.unavailable("分类学习记录撤销接口尚未配置")
    }
}
