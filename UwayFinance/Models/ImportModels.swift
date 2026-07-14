import Foundation

/// Source coordinates are kept separate from the normalized record so the server can
/// create immutable Harness facts and verify their fingerprints.
struct ImportSource: Codable, Hashable {
    let sourceId: String
    let rowPath: String
}

struct ImportRecordInput: Codable, Hashable {
    let date: String
    let direction: Direction
    @LegacyMoney var amount: Double
    var category: String? = nil
    var counterparty: String? = nil
    var project: String? = nil
    var account: String? = nil
    var description: String? = nil
}

struct CompanyOwnershipEvidence: Codable, Hashable {
    let verified: Bool
    let evidenceText: String
    let fieldPath: String
    let fingerprint: String
}

/// Exact request accepted by `server/mainlineImportAnalysisSchema`.
/// Candidate accounts, locked facts and thresholds are deliberately generated server-side.
struct ImportAnalysisRequest: Codable, Hashable {
    let analysisId: String
    let batchId: String
    let rowId: String
    let sourceFingerprint: String
    let existingFingerprints: [String]
    let source: ImportSource
    let record: ImportRecordInput
    let companyOwnership: CompanyOwnershipEvidence
}

struct HarnessClassification: Codable, Hashable {
    let decision: String
    let accountCode: String?
    let businessType: String?
    let evidenceRefs: [String]
    let reasonCode: String?
    let needsReview: Bool
}

struct HarnessIssue: Codable, Hashable {
    let code: String
    let severity: String
    let message: String
    let evidenceRefs: [String]?
}

struct HarnessResult: Codable, Hashable {
    let analysisId: String
    let status: String
    let classification: HarnessClassification?
    let confidence: Double
    let validatedEvidenceRefs: [String]
    let issues: [HarnessIssue]
    let sourceFingerprint: String
    let resolution: ImportReviewResolution?
}

struct ImportReviewDecision: Codable, Hashable {
    let decision: String
    let reason: String
}

struct ImportReviewResolution: Codable, Hashable {
    let decision: String
    let reviewer: String
}

struct ImportReviewDecisionResponse: Codable, Hashable {
    let analysisId: String
    let status: String
    let sourceFingerprint: String
    let resolution: ImportReviewResolution
}

struct DocumentUpload: Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
    let purpose: String
}

struct DocumentUploadReceipt: Codable, Sendable {
    let documentId: String
    let status: String
    let uploadURL: URL?
}

struct OCRJob: Codable, Identifiable, Sendable {
    let id: String
    let documentId: String
    let status: String
    let analysisId: String?
}
