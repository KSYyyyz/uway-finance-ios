import XCTest
@testable import UwayFinance

final class EndpointContractTests: XCTestCase {
    func testCurrentBackendEndpointsRemainStable() {
        XCTAssertEqual(APIEndpoint.login.path, "/api/auth/login")
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

    func testReviewDecisionDoesNotTrustAClientReviewer() throws {
        let body = ImportReviewDecision(decision: "accept", reason: "已核对银行回单")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["decision", "reason"]))
    }
}
