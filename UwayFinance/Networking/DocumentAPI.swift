import SwiftUI

/// Stable client boundary for the future document/OCR service.
/// The first backend implementation should create a document, upload bytes with an idempotency key,
/// then start and poll an OCR job. The app never sends model provider credentials.
protocol DocumentAPI: Sendable {
    func upload(_ document: DocumentUpload, idempotencyKey: String) async throws -> DocumentUploadReceipt
    func startOCR(documentId: String, idempotencyKey: String) async throws -> OCRJob
    func fetchOCRJob(id: String) async throws -> OCRJob
}

actor ReservedDocumentAPI: DocumentAPI {
    func upload(_ document: DocumentUpload, idempotencyKey: String) async throws -> DocumentUploadReceipt {
        throw APIError.unavailable("附件上传接口已预留，等待后端启用")
    }

    func startOCR(documentId: String, idempotencyKey: String) async throws -> OCRJob {
        throw APIError.unavailable("OCR任务接口已预留，等待后端启用")
    }

    func fetchOCRJob(id: String) async throws -> OCRJob {
        throw APIError.unavailable("OCR任务接口已预留，等待后端启用")
    }
}

private struct DocumentAPIKey: EnvironmentKey {
    static let defaultValue: any DocumentAPI = ReservedDocumentAPI()
}

extension EnvironmentValues {
    var documentAPI: any DocumentAPI {
        get { self[DocumentAPIKey.self] }
        set { self[DocumentAPIKey.self] = newValue }
    }
}

