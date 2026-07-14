import Foundation

/// Read-only shadow diagnostic client. It is deliberately not an AppSession
/// dependency and cannot mutate legacy state or Finance Resource V2 data.
protocol CutoverReadinessAPI: Sendable {
    func readiness(_ query: CutoverReadinessQuery) async throws -> CutoverReadinessResponse
}

actor LiveCutoverReadinessAPI: CutoverReadinessAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func readiness(_ query: CutoverReadinessQuery) async throws -> CutoverReadinessResponse {
        try await transport.send(.cutoverReadiness(query))
    }
}
