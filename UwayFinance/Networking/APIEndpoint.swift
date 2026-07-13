import Foundation

enum HTTPMethod: String, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIEndpoint: Hashable {
    let method: HTTPMethod
    let path: String

    static let health = APIEndpoint(method: .get, path: "/api/health")
    static let login = APIEndpoint(method: .post, path: "/api/auth/login")
    static let currentUser = APIEndpoint(method: .get, path: "/api/auth/me")
    static let logout = APIEndpoint(method: .post, path: "/api/auth/logout")
    static let state = APIEndpoint(method: .get, path: "/api/state")
    static let saveState = APIEndpoint(method: .put, path: "/api/state")
    static let auditEvent = APIEndpoint(method: .post, path: "/api/audit-events")
    static let importAnalysis = APIEndpoint(method: .post, path: "/api/import-analysis")

    static func importDecision(analysisId: String) -> APIEndpoint {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = analysisId.addingPercentEncoding(withAllowedCharacters: allowed) ?? analysisId
        return APIEndpoint(method: .post, path: "/api/import-analysis/\(encoded)/decision")
    }
}

/// Planned resource endpoints. They are intentionally not called until the Fastify mainline implements them.
enum FutureAPIEndpoint {
    static let createDocument = APIEndpoint(method: .post, path: "/api/documents")
    static func documentUpload(documentId: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/api/documents/\(documentId)/upload")
    }
    static func startOCR(documentId: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/api/documents/\(documentId)/ocr")
    }
    static func ocrJob(jobId: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/api/ocr-jobs/\(jobId)")
    }
}
