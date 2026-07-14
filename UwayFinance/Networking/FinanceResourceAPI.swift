import Foundation

/// Compiled shadow client for the 0.10.0 Finance Resource slice.
/// AppSession intentionally does not depend on this protocol while the server
/// continues to prefer only `legacy_state_v1`.
protocol FinanceResourceAPI: Sendable {
    func context(accountBookId: String?) async throws -> FinanceContextResponse
    func listBusinessRecords(_ query: BusinessRecordListQuery) async throws -> BusinessRecordListResponse
    func createBusinessRecord(_ command: CreateBusinessRecordCommand) async throws -> BusinessRecordEnvelope
    func updateBusinessRecord(_ command: UpdateBusinessRecordCommand) async throws -> BusinessRecordEnvelope
}

actor LiveFinanceResourceAPI: FinanceResourceAPI {
    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func context(accountBookId: String? = nil) async throws -> FinanceContextResponse {
        try await transport.send(.financeContext(accountBookId: accountBookId))
    }

    func listBusinessRecords(_ query: BusinessRecordListQuery) async throws -> BusinessRecordListResponse {
        try await transport.send(.businessRecords(query))
    }

    func createBusinessRecord(_ command: CreateBusinessRecordCommand) async throws -> BusinessRecordEnvelope {
        try await transport.send(
            .createBusinessRecord,
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }

    func updateBusinessRecord(_ command: UpdateBusinessRecordCommand) async throws -> BusinessRecordEnvelope {
        try await transport.send(
            .updateBusinessRecord(recordId: command.recordId),
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }
}
