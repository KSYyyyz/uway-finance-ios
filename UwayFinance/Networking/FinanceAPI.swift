import Foundation

enum AuditAction: String, Codable {
    case recordCSVImport = "record_csv_import"
    case bankCSVImport = "bank_csv_import"
    case reconciliationConfirm = "reconciliation_confirm"
    case reconciliationIgnore = "reconciliation_ignore"
}

struct AuditEventRequest: Codable {
    let action: AuditAction
    let count: Int?
    let duplicateCount: Int?
    let errorCount: Int?
    let fileName: String?
}

protocol FinanceAPI: Sendable {
    func health() async throws -> HealthResponse
    func capabilities() async throws -> ServerCapabilitiesResponse
    func login(username: String, password: String) async throws -> SessionUser
    func currentUser() async throws -> SessionUser
    func logout() async throws
    func fetchState() async throws -> StateEnvelope
    func saveState(_ state: AppStatePayload, ifMatch revision: StateRevision) async throws -> StateRevision
    func audit(_ event: AuditEventRequest) async throws
}

actor LiveFinanceAPI: FinanceAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) { self.transport = transport }

    func health() async throws -> HealthResponse {
        try await transport.send(.health)
    }

    func capabilities() async throws -> ServerCapabilitiesResponse {
        try await transport.send(.capabilities)
    }

    func login(username: String, password: String) async throws -> SessionUser {
        struct LoginRequest: Codable { let username: String; let password: String }
        let envelope: SessionEnvelope = try await transport.send(
            .login,
            body: LoginRequest(username: username, password: password)
        )
        return envelope.user
    }

    func currentUser() async throws -> SessionUser {
        let envelope: SessionEnvelope = try await transport.send(.currentUser)
        return envelope.user
    }

    func logout() async throws {
        let _: OKResponse = try await transport.send(.logout)
    }

    func fetchState() async throws -> StateEnvelope {
        try await transport.send(.state)
    }

    func saveState(_ state: AppStatePayload, ifMatch revision: StateRevision) async throws -> StateRevision {
        let response: MutationResponse = try await transport.send(
            .saveState,
            body: state,
            headers: ["If-Match": revision.ifMatchHeaderValue]
        )
        guard let updatedAt = response.updatedAt else {
            throw APIError.decoding("条件写入响应缺少 updatedAt")
        }
        return StateRevision(updatedAt: updatedAt)
    }

    func audit(_ event: AuditEventRequest) async throws {
        let _: OKResponse = try await transport.send(.auditEvent, body: event)
    }
}
