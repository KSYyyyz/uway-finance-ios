import CryptoKit
import Foundation
import SwiftUI

protocol BusinessRecordEvidenceAPI: Sendable {
    func context(accountBookId: String?) async throws -> FinanceContextResponse
    func list(_ query: BusinessRecordEvidenceListQuery) async throws -> BusinessRecordEvidenceListResponse
    func coverage(accountBookId: String) async throws -> BusinessRecordEvidenceCoverageResponse
    func upload(_ command: BusinessRecordEvidenceUploadCommand) async throws -> BusinessRecordEvidenceUploadResponse
    func content(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent
    func revoke(_ command: BusinessRecordEvidenceRevokeCommand) async throws -> BusinessRecordEvidenceRevokeResponse
}

actor LiveBusinessRecordEvidenceAPI: BusinessRecordEvidenceAPI {
    private let transport: HTTPTransport
    private let decoder = JSONDecoder()

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func context(accountBookId: String? = nil) async throws -> FinanceContextResponse {
        try await transport.send(.financeContext(accountBookId: accountBookId))
    }

    func list(_ query: BusinessRecordEvidenceListQuery) async throws -> BusinessRecordEvidenceListResponse {
        try await transport.send(.businessRecordEvidence(query))
    }

    func coverage(accountBookId: String) async throws -> BusinessRecordEvidenceCoverageResponse {
        try await transport.send(.businessRecordEvidenceCoverage(accountBookId: accountBookId))
    }

    func upload(_ command: BusinessRecordEvidenceUploadCommand) async throws -> BusinessRecordEvidenceUploadResponse {
        guard EvidenceMediaDetection.mediaType(for: command.request.file.data) == command.request.file.mediaType else {
            throw APIError.unavailable("所选文件内容与票据格式不一致")
        }
        let body = EvidenceMultipartEncoder.body(for: command)
        let payload = try await transport.sendRaw(
            .uploadBusinessRecordEvidence,
            body: body,
            contentType: "multipart/form-data; boundary=\(command.multipartBoundary)",
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
        do { return try decoder.decode(BusinessRecordEvidenceUploadResponse.self, from: payload.data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    func content(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent {
        let payload = try await transport.sendRaw(.businessRecordEvidenceContent(evidenceId: evidence.id))
        let digest = SHA256.hash(data: payload.data).map { String(format: "%02x", $0) }.joined()
        let responseETag = payload.header("ETag")?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard payload.data.count == evidence.byteSize,
              digest == evidence.sha256,
              responseETag == nil || responseETag == evidence.sha256 else {
            throw APIError.server(
                status: 409,
                code: "EVIDENCE_INTEGRITY_MISMATCH",
                message: "票据原件完整性校验失败，已停止打开"
            )
        }
        return BusinessRecordEvidenceContent(
            evidenceId: evidence.id,
            fileName: evidence.fileName,
            mediaType: payload.header("Content-Type") ?? evidence.mediaType,
            data: payload.data,
            eTag: payload.header("ETag"),
            digest: payload.header("Digest")
        )
    }

    func revoke(_ command: BusinessRecordEvidenceRevokeCommand) async throws -> BusinessRecordEvidenceRevokeResponse {
        try await transport.send(
            .revokeBusinessRecordEvidence(evidenceId: command.evidenceId),
            body: command.request,
            headers: ["Idempotency-Key": command.idempotencyKey.rawValue]
        )
    }
}

enum EvidenceMultipartEncoder {
    static func body(for command: BusinessRecordEvidenceUploadCommand) -> Data {
        var data = Data()
        let boundary = command.multipartBoundary
        let request = command.request
        appendField("accountBookId", value: request.accountBookId, boundary: boundary, to: &data)
        appendField("recordExternalId", value: request.recordExternalId, boundary: boundary, to: &data)
        appendField("evidenceType", value: request.evidenceType.rawValue, boundary: boundary, to: &data)
        appendField("note", value: request.note, boundary: boundary, to: &data)
        let safeName = request.file.fileName
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
        append("--\(boundary)\r\n", to: &data)
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\n", to: &data)
        append("Content-Type: \(request.file.mediaType)\r\n\r\n", to: &data)
        data.append(request.file.data)
        append("\r\n--\(boundary)--\r\n", to: &data)
        return data
    }

    private static func appendField(_ name: String, value: String, boundary: String, to data: inout Data) {
        append("--\(boundary)\r\n", to: &data)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n", to: &data)
        append("\(value)\r\n", to: &data)
    }

    private static func append(_ value: String, to data: inout Data) {
        data.append(Data(value.utf8))
    }
}

private struct BusinessRecordEvidenceAPIKey: EnvironmentKey {
    static let defaultValue: any BusinessRecordEvidenceAPI = UnavailableBusinessRecordEvidenceAPI()
}

extension EnvironmentValues {
    var businessRecordEvidenceAPI: any BusinessRecordEvidenceAPI {
        get { self[BusinessRecordEvidenceAPIKey.self] }
        set { self[BusinessRecordEvidenceAPIKey.self] = newValue }
    }
}

actor UnavailableBusinessRecordEvidenceAPI: BusinessRecordEvidenceAPI {
    func context(accountBookId: String?) async throws -> FinanceContextResponse { throw unavailable }
    func list(_ query: BusinessRecordEvidenceListQuery) async throws -> BusinessRecordEvidenceListResponse { throw unavailable }
    func coverage(accountBookId: String) async throws -> BusinessRecordEvidenceCoverageResponse { throw unavailable }
    func upload(_ command: BusinessRecordEvidenceUploadCommand) async throws -> BusinessRecordEvidenceUploadResponse { throw unavailable }
    func content(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent { throw unavailable }
    func revoke(_ command: BusinessRecordEvidenceRevokeCommand) async throws -> BusinessRecordEvidenceRevokeResponse { throw unavailable }

    private var unavailable: APIError { .unavailable("当前服务器未开放不可变票据证据能力") }
}
