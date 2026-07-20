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
    func login(identifier: String, password: String, useLegacyUsernameField: Bool) async throws -> SessionUser
    func usernameAvailability(_ request: UsernameAvailabilityRequest) async throws -> UsernameAvailabilityResponse
    func requestRegistrationCode(phone: String) async throws -> RegistrationCodeResponse
    func register(_ request: RegistrationRequest) async throws -> RegistrationResponse
    func requestPasswordReset(_ request: PasswordResetRequest) async throws -> PasswordResetChallengeResponse
    func confirmPasswordReset(_ request: PasswordResetConfirmRequest) async throws -> PasswordResetConfirmResponse
    func currentUser() async throws -> SessionUser
    func logout() async throws
    func fetchState() async throws -> StateEnvelope
    func saveState(_ state: AppStatePayload, ifMatch revision: StateRevision) async throws -> StateRevision
    func audit(_ event: AuditEventRequest) async throws
}

actor LiveFinanceAPI: FinanceAPI {
    private let transport: HTTPTransport
    private var authenticationTail: Task<Void, Never>?

    init(transport: HTTPTransport) { self.transport = transport }

    func health() async throws -> HealthResponse {
        try await transport.send(.health)
    }

    func capabilities() async throws -> ServerCapabilitiesResponse {
        try await transport.send(.capabilities)
    }

    func login(identifier: String, password: String, useLegacyUsernameField: Bool = false) async throws -> SessionUser {
        let request = LoginRequest(
            identifier: identifier,
            password: password,
            useLegacyUsernameField: useLegacyUsernameField
        )
        let envelope: SessionEnvelope = try await serializedAuthenticationRequest {
            try await self.transport.send(.login, body: request)
        }
        return envelope.user
    }

    func usernameAvailability(_ request: UsernameAvailabilityRequest) async throws -> UsernameAvailabilityResponse {
        try await transport.send(.usernameAvailability, body: request)
    }

    func requestRegistrationCode(phone: String) async throws -> RegistrationCodeResponse {
        try await transport.send(.registrationCode, body: RegistrationCodeRequest(phone: phone))
    }

    func register(_ request: RegistrationRequest) async throws -> RegistrationResponse {
        try await serializedAuthenticationRequest {
            try await self.transport.send(.register, body: request)
        }
    }

    func requestPasswordReset(_ request: PasswordResetRequest) async throws -> PasswordResetChallengeResponse {
        try await transport.send(.passwordResetRequest, body: request)
    }

    func confirmPasswordReset(_ request: PasswordResetConfirmRequest) async throws -> PasswordResetConfirmResponse {
        try await serializedAuthenticationRequest {
            try await self.transport.send(.passwordResetConfirm, body: request)
        }
    }

    func currentUser() async throws -> SessionUser {
        let envelope: SessionEnvelope = try await transport.send(.currentUser)
        return envelope.user
    }

    func logout() async throws {
        let _: OKResponse = try await serializedAuthenticationRequest {
            try await self.transport.send(.logout)
        }
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

    private func serializedAuthenticationRequest<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let previous = authenticationTail
        let request = Task<Value, Error> {
            if let previous { await previous.value }
            return try await operation()
        }
        authenticationTail = Task { _ = try? await request.value }
        return try await request.value
    }
}

private struct LoginRequest: Encodable, Sendable {
    let identifier: String
    let password: String
    let useLegacyUsernameField: Bool

    enum CodingKeys: String, CodingKey { case identifier, username, password }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(password, forKey: .password)
        if useLegacyUsernameField {
            try container.encode(identifier, forKey: .username)
        } else {
            try container.encode(identifier, forKey: .identifier)
        }
    }
}
