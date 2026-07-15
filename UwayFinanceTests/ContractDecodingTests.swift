import XCTest
@testable import UwayFinance

final class ContractDecodingTests: XCTestCase {
    func testCurrentStateEnvelopeDecodes() throws {
        let data = try fixture(named: "state-envelope")
        let envelope = try JSONDecoder().decode(StateEnvelope.self, from: data)
        XCTAssertEqual(envelope.data.records.count, 1)
        XCTAssertEqual(envelope.data.records[0].scenario, .formalExpense)
        XCTAssertEqual(envelope.data.records[0].analysisDecision, .harnessAccepted)
        XCTAssertEqual(envelope.data.records[0].importAnalysisId, "analysis-001")
        XCTAssertEqual(envelope.data.records[0].preciseAmount.cents, 248_000)
        XCTAssertEqual(envelope.data.bankTransactions[0].matchStatus, .suggested)
        XCTAssertEqual(envelope.data.bankTransactions[0].preciseAmount.cents, 248_000)
    }

    func testHarnessResultDecodesWithoutCreatingFacts() throws {
        let data = try fixture(named: "harness-result")
        let result = try JSONDecoder().decode(HarnessResult.self, from: data)
        XCTAssertEqual(result.status, "review")
        XCTAssertTrue(result.classification?.needsReview == true)
        XCTAssertEqual(result.validatedEvidenceRefs, ["row-1-description"])
    }

    func testCurrentAccountBookImportAnalysisRequestDecodes() throws {
        let data = try fixture(named: "import-analysis-request-account-book-v0.14.0")
        let request = try JSONDecoder().decode(ImportAnalysisRequest.self, from: data)
        XCTAssertEqual(request.accountBookId, "11")
        XCTAssertEqual(request.analysisId, "analysis-001")
        XCTAssertEqual(request.record.direction, .expense)
        XCTAssertEqual(request.record.amount, 2_480)
        XCTAssertEqual(request.record.description, "云服务器费用")
        XCTAssertTrue(request.companyOwnership.verified)
        XCTAssertEqual(request.sourceFingerprint, "fixture-fingerprint-001")
    }

    func testHistoricalImportRequestWithoutAccountBookFailsClosed() throws {
        let data = try fixture(named: "import-analysis-request")
        XCTAssertThrowsError(try JSONDecoder().decode(ImportAnalysisRequest.self, from: data))
    }

    func testCurrentDecisionRequestCarriesAccountBookScope() throws {
        let data = try fixture(named: "import-decision-request-account-book-v0.14.0")
        let request = try JSONDecoder().decode(ImportReviewDecision.self, from: data)
        XCTAssertEqual(request.accountBookId, "11")
        XCTAssertEqual(request.decision, "accept")
    }

    func testMainlineDecisionResponseDecodesServerReviewer() throws {
        let data = try fixture(named: "import-decision-response")
        let response = try JSONDecoder().decode(ImportReviewDecisionResponse.self, from: data)
        XCTAssertEqual(response.status, "accepted")
        XCTAssertEqual(response.resolution.decision, "accept")
        XCTAssertEqual(response.resolution.reviewer, "finance-admin")
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
