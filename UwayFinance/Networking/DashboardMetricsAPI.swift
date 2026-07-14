import Foundation

/// Read-only Finance V2 shadow metrics client. AppSession deliberately does
/// not depend on this protocol and continues to synchronize through /api/state.
protocol DashboardMetricsAPI: Sendable {
    func metrics(_ query: DashboardMetricsQuery) async throws -> DashboardMetricsResponse
}

actor LiveDashboardMetricsAPI: DashboardMetricsAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func metrics(_ query: DashboardMetricsQuery) async throws -> DashboardMetricsResponse {
        try await transport.send(.dashboardMetrics(query))
    }
}
