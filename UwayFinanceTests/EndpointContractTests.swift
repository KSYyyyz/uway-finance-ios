import XCTest
@testable import UwayFinance

final class EndpointContractTests: XCTestCase {
    func testCurrentBackendEndpointsRemainStable() {
        XCTAssertEqual(APIEndpoint.health.path, "/api/health")
        XCTAssertEqual(APIEndpoint.capabilities.path, "/api/capabilities")
        XCTAssertEqual(APIEndpoint.login.path, "/api/auth/login")
        XCTAssertEqual(APIEndpoint.usernameAvailability.path, "/api/auth/username-availability")
        XCTAssertEqual(APIEndpoint.registrationCode.path, "/api/auth/registration-code")
        XCTAssertEqual(APIEndpoint.registrationEmailResend.path, "/api/auth/registration-email/resend")
        XCTAssertEqual(APIEndpoint.registrationEmailConfirm.path, "/api/auth/registration-email/confirm")
        XCTAssertEqual(APIEndpoint.passwordResetRequest.path, "/api/auth/password-reset/request")
        XCTAssertEqual(APIEndpoint.passwordResetConfirm.path, "/api/auth/password-reset/confirm")
        XCTAssertEqual(APIEndpoint.currentUser.path, "/api/auth/me")
        XCTAssertEqual(APIEndpoint.logout.path, "/api/auth/logout")
        XCTAssertEqual(APIEndpoint.state.path, "/api/state")
        XCTAssertEqual(APIEndpoint.saveState.method, .put)
        XCTAssertEqual(APIEndpoint.auditEvent.path, "/api/audit-events")
    }

    func testHarnessEndpointsMatchSubprojectContract() {
        XCTAssertEqual(APIEndpoint.importAnalysis.method, .post)
        XCTAssertEqual(APIEndpoint.importAnalysis.path, "/api/import-analysis")
        XCTAssertEqual(APIEndpoint.importDecision(analysisId: "A-001").path, "/api/import-analysis/A-001/decision")
    }

    func testShadowFinanceResourceEndpointsMatchCandidateContract() {
        XCTAssertEqual(APIEndpoint.financeContext().path, "/api/v2/context")
        XCTAssertEqual(APIEndpoint.businessRecords(BusinessRecordListQuery(limit: 20)).method, .get)
        XCTAssertTrue(APIEndpoint.businessRecords(BusinessRecordListQuery(limit: 20)).path.hasPrefix("/api/v2/business-records?"))
        XCTAssertEqual(APIEndpoint.createBusinessRecord.method, .post)
        XCTAssertEqual(APIEndpoint.createBusinessRecord.path, "/api/v2/business-records")
        XCTAssertEqual(APIEndpoint.updateBusinessRecord(recordId: "103").method, .patch)
        XCTAssertEqual(APIEndpoint.updateBusinessRecord(recordId: "103").path, "/api/v2/business-records/103")
    }

    func testReviewDecisionDoesNotTrustAClientReviewer() throws {
        let body = ImportReviewDecision(accountBookId: "11", decision: "accept", reason: "已核对银行回单")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["accountBookId", "decision", "reason"]))
    }

    func testClassificationPreferenceEndpointsKeepAccountBookScopeAndRevokePath() {
        let list = APIEndpoint.classificationPreferences(ClassificationPreferenceQuery(
            accountBookId: "11", state: .active, limit: 10, cursor: "opaque+/next="
        ))
        XCTAssertEqual(list.method, .get)
        XCTAssertTrue(list.path.hasPrefix("/api/v2/classification-preferences?"))
        XCTAssertTrue(list.path.contains("accountBookId=11"))
        XCTAssertTrue(list.path.contains("state=active"))
        XCTAssertEqual(
            APIEndpoint.revokeClassificationPreference(observationId: "701/unsafe").path,
            "/api/v2/classification-preferences/701%2Funsafe/revoke"
        )
    }

    func testEvidenceEndpointsKeepRecordAndAccountBookScope() {
        let list = APIEndpoint.businessRecordEvidence(BusinessRecordEvidenceListQuery(
            accountBookId: "11", recordExternalId: "R/001", includeRevoked: true
        ))
        XCTAssertEqual(list.method, .get)
        XCTAssertTrue(list.path.hasPrefix("/api/v2/business-record-evidence?"))
        XCTAssertTrue(list.path.contains("accountBookId=11"))
        XCTAssertTrue(list.path.contains("recordExternalId=R/001") || list.path.contains("recordExternalId=R%2F001"))
        XCTAssertTrue(list.path.contains("includeRevoked=true"))
        XCTAssertEqual(
            APIEndpoint.businessRecordEvidenceCoverage(accountBookId: "11").path,
            "/api/v2/business-record-evidence-coverage?accountBookId=11"
        )
        XCTAssertEqual(APIEndpoint.uploadBusinessRecordEvidence.method, .post)
        XCTAssertEqual(
            APIEndpoint.businessRecordEvidenceContent(evidenceId: "801/unsafe").path,
            "/api/v2/business-record-evidence/801%2Funsafe/content"
        )
        XCTAssertEqual(
            APIEndpoint.revokeBusinessRecordEvidence(evidenceId: "801/unsafe").path,
            "/api/v2/business-record-evidence/801%2Funsafe/revoke"
        )
    }
}
