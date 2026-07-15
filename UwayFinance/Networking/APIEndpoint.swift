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
    static let capabilities = APIEndpoint(method: .get, path: "/api/capabilities")
    static let login = APIEndpoint(method: .post, path: "/api/auth/login")
    static let registrationCode = APIEndpoint(method: .post, path: "/api/auth/registration-code")
    static let register = APIEndpoint(method: .post, path: "/api/auth/register")
    static let currentUser = APIEndpoint(method: .get, path: "/api/auth/me")
    static let logout = APIEndpoint(method: .post, path: "/api/auth/logout")
    static let state = APIEndpoint(method: .get, path: "/api/state")
    static let saveState = APIEndpoint(method: .put, path: "/api/state")
    static let auditEvent = APIEndpoint(method: .post, path: "/api/audit-events")
    static let importAnalysis = APIEndpoint(method: .post, path: "/api/import-analysis")

    static func financeContext(accountBookId: String? = nil) -> APIEndpoint {
        APIEndpoint(method: .get, path: path(
            "/api/v2/context",
            queryItems: accountBookId.map { [URLQueryItem(name: "accountBookId", value: $0)] } ?? []
        ))
    }

    static func businessRecords(_ query: BusinessRecordListQuery) -> APIEndpoint {
        var items = [URLQueryItem(name: "limit", value: String(query.limit))]
        if let value = query.accountBookId { items.append(URLQueryItem(name: "accountBookId", value: value)) }
        if let value = query.cursor { items.append(URLQueryItem(name: "cursor", value: value)) }
        if let value = query.direction { items.append(URLQueryItem(name: "direction", value: value.rawValue)) }
        if let value = query.financeStatus { items.append(URLQueryItem(name: "financeStatus", value: value.rawValue)) }
        return APIEndpoint(method: .get, path: path("/api/v2/business-records", queryItems: items))
    }

    static let createBusinessRecord = APIEndpoint(method: .post, path: "/api/v2/business-records")

    static func cutoverReadiness(_ query: CutoverReadinessQuery) -> APIEndpoint {
        var items = [URLQueryItem(name: "limit", value: String(query.limit))]
        if let value = query.accountBookId { items.append(URLQueryItem(name: "accountBookId", value: value)) }
        if let value = query.cursor { items.append(URLQueryItem(name: "cursor", value: value)) }
        return APIEndpoint(method: .get, path: path("/api/v2/cutover-readiness", queryItems: items))
    }

    static func dashboardMetrics(_ query: DashboardMetricsQuery) -> APIEndpoint {
        var items: [URLQueryItem] = []
        if let value = query.period { items.append(URLQueryItem(name: "period", value: value)) }
        if let value = query.accountBookId { items.append(URLQueryItem(name: "accountBookId", value: value)) }
        return APIEndpoint(method: .get, path: path("/api/v2/dashboard-metrics", queryItems: items))
    }

    static func classificationReviews(_ query: ClassificationReviewQuery) -> APIEndpoint {
        var items = [
            URLQueryItem(name: "state", value: query.state.rawValue),
            URLQueryItem(name: "limit", value: String(query.limit)),
        ]
        if let value = query.cursor { items.append(URLQueryItem(name: "cursor", value: value)) }
        if let value = query.accountBookId { items.append(URLQueryItem(name: "accountBookId", value: value)) }
        if let value = query.period { items.append(URLQueryItem(name: "period", value: value)) }
        return APIEndpoint(method: .get, path: path("/api/v2/classification-reviews", queryItems: items))
    }

    static func analyzeClassification(recordId: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: classificationPath(recordId: recordId, suffix: "analyze"))
    }

    static func decideClassification(recordId: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: classificationPath(recordId: recordId, suffix: "decision"))
    }

    static func classificationPreferences(_ query: ClassificationPreferenceQuery) -> APIEndpoint {
        var items = [
            URLQueryItem(name: "accountBookId", value: query.accountBookId),
            URLQueryItem(name: "state", value: query.state.rawValue),
            URLQueryItem(name: "limit", value: String(query.limit)),
        ]
        if let value = query.cursor { items.append(URLQueryItem(name: "cursor", value: value)) }
        return APIEndpoint(method: .get, path: path("/api/v2/classification-preferences", queryItems: items))
    }

    static func revokeClassificationPreference(observationId: String) -> APIEndpoint {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = observationId.addingPercentEncoding(withAllowedCharacters: allowed) ?? observationId
        return APIEndpoint(method: .post, path: "/api/v2/classification-preferences/\(encoded)/revoke")
    }

    static func businessRecordEvidence(_ query: BusinessRecordEvidenceListQuery) -> APIEndpoint {
        APIEndpoint(method: .get, path: path(
            "/api/v2/business-record-evidence",
            queryItems: [
                URLQueryItem(name: "recordExternalId", value: query.recordExternalId),
                URLQueryItem(name: "includeRevoked", value: query.includeRevoked ? "true" : "false"),
                URLQueryItem(name: "accountBookId", value: query.accountBookId),
            ]
        ))
    }

    static func businessRecordEvidenceCoverage(accountBookId: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: path(
            "/api/v2/business-record-evidence-coverage",
            queryItems: [URLQueryItem(name: "accountBookId", value: accountBookId)]
        ))
    }

    static let uploadBusinessRecordEvidence = APIEndpoint(
        method: .post,
        path: "/api/v2/business-record-evidence"
    )

    static func businessRecordEvidenceContent(evidenceId: String) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/api/v2/business-record-evidence/\(encodedPathComponent(evidenceId))/content"
        )
    }

    static func revokeBusinessRecordEvidence(evidenceId: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "/api/v2/business-record-evidence/\(encodedPathComponent(evidenceId))/revoke"
        )
    }

    static func updateBusinessRecord(recordId: String) -> APIEndpoint {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = recordId.addingPercentEncoding(withAllowedCharacters: allowed) ?? recordId
        return APIEndpoint(method: .patch, path: "/api/v2/business-records/\(encoded)")
    }

    static func importDecision(analysisId: String) -> APIEndpoint {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = analysisId.addingPercentEncoding(withAllowedCharacters: allowed) ?? analysisId
        return APIEndpoint(method: .post, path: "/api/import-analysis/\(encoded)/decision")
    }

    private static func path(_ path: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path }
        var components = URLComponents()
        components.path = path
        components.queryItems = queryItems
        return components.string ?? path
    }

    private static func classificationPath(recordId: String, suffix: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = recordId.addingPercentEncoding(withAllowedCharacters: allowed) ?? recordId
        return "/api/v2/classification-reviews/\(encoded)/\(suffix)"
    }

    private static func encodedPathComponent(_ value: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
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
