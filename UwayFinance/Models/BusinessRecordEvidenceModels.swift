import Foundation

enum BusinessRecordEvidenceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case invoice
    case paymentProof = "payment_proof"
    case receipt
    case contract
    case bankSlip = "bank_slip"
    case expenseClaim = "expense_claim"
    case payroll
    case tax
    case other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .invoice: "发票"
        case .paymentProof: "付款凭证"
        case .receipt: "收据"
        case .contract: "合同"
        case .bankSlip: "银行回单"
        case .expenseClaim: "报销单"
        case .payroll: "工资资料"
        case .tax: "税务资料"
        case .other: "其他附件"
        }
    }
}

enum BusinessRecordEvidenceStatus: String, Codable, Sendable {
    case active
    case revoked

    var label: String { self == .active ? "有效" : "已作废" }
}

struct BusinessRecordEvidence: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let recordExternalId: String
    let evidenceType: BusinessRecordEvidenceType
    let fileName: String
    let mediaType: String
    let byteSize: Int
    let sha256: String
    let note: String?
    let status: BusinessRecordEvidenceStatus
    let version: Int
    let createdAt: String
    let revokedAt: String?
    let revokeReason: String?
    let uploadedByUserId: String
    let revokedByUserId: String?
    let contentUrl: String
}

struct BusinessRecordEvidenceListQuery: Equatable, Sendable {
    let accountBookId: String
    let recordExternalId: String
    let includeRevoked: Bool
}

struct BusinessRecordEvidenceListResponse: Codable, Equatable, Sendable {
    let items: [BusinessRecordEvidence]
}

struct BusinessRecordEvidenceCoverage: Codable, Equatable, Sendable {
    let activeEvidenceCount: Int
    let invoiceEvidenceCount: Int
    let paymentEvidenceCount: Int
}

struct BusinessRecordEvidenceCoverageResponse: Codable, Equatable, Sendable {
    let records: [String: BusinessRecordEvidenceCoverage]
}

struct SelectedEvidenceFile: Equatable, Sendable {
    let fileName: String
    let mediaType: String
    let data: Data

    var byteSize: Int { data.count }
}

struct BusinessRecordEvidenceUploadRequest: Equatable, Sendable {
    let accountBookId: String
    let recordExternalId: String
    let evidenceType: BusinessRecordEvidenceType
    let note: String
    let file: SelectedEvidenceFile
}

struct BusinessRecordEvidenceUploadCommand: Equatable, Sendable {
    let request: BusinessRecordEvidenceUploadRequest
    let idempotencyKey: IdempotencyKey
    let multipartBoundary: String

    init(request: BusinessRecordEvidenceUploadRequest, operationID: UUID = UUID()) {
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "evidence-upload", operationID: operationID)
        multipartBoundary = "UwayEvidenceBoundary-\(operationID.uuidString.lowercased())"
    }
}

struct BusinessRecordEvidenceUploadResponse: Codable, Equatable, Sendable {
    let evidence: BusinessRecordEvidence
    let fixed: Bool
    let contentImmutable: Bool
}

struct BusinessRecordEvidenceRevokeRequest: Codable, Equatable, Sendable {
    let accountBookId: String
    let expectedVersion: Int
    let reason: String
}

struct BusinessRecordEvidenceRevokeCommand: Equatable, Sendable {
    let evidenceId: String
    let request: BusinessRecordEvidenceRevokeRequest
    let idempotencyKey: IdempotencyKey

    init(evidenceId: String, request: BusinessRecordEvidenceRevokeRequest, operationID: UUID = UUID()) {
        self.evidenceId = evidenceId
        self.request = request
        idempotencyKey = IdempotencyKey(operation: "evidence-revoke", operationID: operationID)
    }
}

struct BusinessRecordEvidenceRevokeResponse: Codable, Equatable, Sendable {
    let evidence: BusinessRecordEvidence
    let contentDeleted: Bool
    let contentImmutable: Bool
}

struct BusinessRecordEvidenceContent: Equatable, Sendable {
    let evidenceId: String
    let fileName: String
    let mediaType: String
    let data: Data
    let eTag: String?
    let digest: String?
}

enum EvidenceMediaDetection {
    static func mediaType(for data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3, Array(bytes[0..<3]) == [0xff, 0xd8, 0xff] { return "image/jpeg" }
        if bytes.count >= 8, Array(bytes[0..<8]) == [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] { return "image/png" }
        if bytes.count >= 12,
           String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" { return "image/webp" }
        if bytes.count >= 5, String(bytes: bytes[0..<5], encoding: .ascii) == "%PDF-" { return "application/pdf" }
        if bytes.count >= 12, String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" {
            guard let brand = String(bytes: bytes[8..<12], encoding: .ascii)?.lowercased() else { return nil }
            if ["heic", "heix", "hevc", "hevx"].contains(brand) { return "image/heic" }
            if ["heif", "mif1", "msf1"].contains(brand) { return "image/heif" }
        }
        return nil
    }
}
