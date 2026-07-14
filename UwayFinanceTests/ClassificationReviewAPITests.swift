import XCTest
@testable import UwayFinance

final class ClassificationReviewAPITests: XCTestCase {
    override func tearDown() {
        ClassificationReviewURLProtocol.handler = nil
        ClassificationReviewURLProtocol.capturedRequests = []
        ClassificationReviewURLProtocol.capturedBodies = []
        super.tearDown()
    }

    func testListUsesOpaqueCursorAndMaximumTenRowsWithExactMoney() async throws {
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-reviews-pending-v0.11.0")
        let response = try await makeAPI().list(ClassificationReviewQuery(
            state: .pending,
            limit: 50,
            cursor: "opaque+/cursor=",
            accountBookId: "11",
            period: "2026-07"
        ))

        XCTAssertEqual(response.page.limit, 10)
        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.items[0].record.amount.value.cents, 117_000)
        XCTAssertEqual(response.items[0].proposal.classificationState, .review)
        XCTAssertEqual(response.items[1].proposal.classificationState, .unclassified)
        XCTAssertFalse(response.safety.rawBusinessRecordsChanged)
        XCTAssertFalse(response.safety.modelCanAccept)
        let query = try XCTUnwrap(URLComponents(url: capturedRequest().url!, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "limit" })?.value, "10")
        XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, "opaque+/cursor=")
        XCTAssertEqual(query.first(where: { $0.name == "state" })?.value, "pending")
        XCTAssertEqual(query.first(where: { $0.name == "period" })?.value, "2026-07")
    }

    func testAcceptedAndRejectedListsRemainDistinct() async throws {
        let api = makeAPI()
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-reviews-accepted-v0.11.0")
        let accepted = try await api.list(ClassificationReviewQuery(state: .accepted))
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-reviews-rejected-v0.11.0")
        let rejected = try await api.list(ClassificationReviewQuery(state: .rejected))

        XCTAssertEqual(accepted.items.first?.reviewState, .accepted)
        XCTAssertEqual(accepted.items.first?.proposal.origin, "human")
        XCTAssertEqual(rejected.items.first?.reviewState, .rejected)
        XCTAssertEqual(rejected.items.first?.proposal.persistedStatus, "rejected")
    }

    func testAnalyzeReusesStableIdempotencyKeyAndKeepsModelResultInReview() async throws {
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-analysis-review-v0.11.0")
        let api = makeAPI()
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000011"))
        let command = ClassificationAnalyzeCommand(
            recordId: "102",
            request: ClassificationVersionRequest(
                accountBookId: "11",
                expectedRecordVersion: 3,
                expectedClassificationVersion: 2
            ),
            operationID: operationID
        )

        let first = try await api.analyze(command)
        _ = try await api.analyze(command)

        XCTAssertEqual(first.analysis.status, .review)
        XCTAssertTrue(first.analysis.persistedClassification)
        XCTAssertFalse(first.analysis.writesBusinessRecord)
        XCTAssertFalse(first.safety.modelCanAccept)
        XCTAssertFalse(first.safety.modelWritesBusinessRecords)
        XCTAssertEqual(ClassificationReviewURLProtocol.capturedRequests.count, 2)
        let keys = ClassificationReviewURLProtocol.capturedRequests.compactMap {
            $0.value(forHTTPHeaderField: "Idempotency-Key")
        }
        XCTAssertEqual(Set(keys), Set(["ios-classification-analyze-00000000-0000-0000-0000-000000000011"]))
        let bodies = try ClassificationReviewURLProtocol.capturedBodies.map { try XCTUnwrap($0) }
        XCTAssertEqual(Set(bodies).count, 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? [String: Any])
        XCTAssertEqual(json["expectedRecordVersion"] as? Int, 3)
        XCTAssertEqual(json["expectedClassificationVersion"] as? Int, 2)
    }

    func testAcceptedRuleAndRejectedHarnessResultsPreserveFailClosedBoundary() async throws {
        let api = makeAPI()
        let command = ClassificationAnalyzeCommand(
            recordId: "102",
            request: ClassificationVersionRequest(accountBookId: "11", expectedRecordVersion: 3, expectedClassificationVersion: 2)
        )
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-analysis-accepted-v0.11.0")
        let accepted = try await api.analyze(command)
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-analysis-rejected-v0.11.0")
        let rejected = try await api.analyze(command)

        XCTAssertEqual(accepted.analysis.status, .accepted)
        XCTAssertEqual(accepted.analysis.origin, "rule")
        XCTAssertFalse(accepted.analysis.writesBusinessRecord)
        XCTAssertEqual(rejected.analysis.status, .rejected)
        XCTAssertFalse(rejected.analysis.persistedClassification)
        XCTAssertNil(rejected.analysis.taxonomyCode)
        XCTAssertEqual(rejected.analysis.issueCodes, ["EVIDENCE_INSUFFICIENT"])
    }

    func testDecisionUsesServerConfirmCorrectRejectVocabularyAndStableBody() async throws {
        let api = makeAPI()
        let baseID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000012"))
        let confirm = ClassificationDecisionCommand(
            recordId: "102",
            request: ClassificationDecisionRequest(
                accountBookId: "11", action: .confirm, expectedRecordVersion: 3,
                expectedClassificationVersion: 2, taxonomyCode: "software_cloud",
                normalizedItemName: "Codex / OpenAI", reason: "已核对订阅合同"
            ),
            operationID: baseID
        )
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-decision-confirm-v0.11.0")
        let confirmed = try await api.decide(confirm)
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-decision-correct-v0.11.0")
        let corrected = try await api.decide(ClassificationDecisionCommand(
            recordId: "102",
            request: ClassificationDecisionRequest(
                accountBookId: "11", action: .correct, expectedRecordVersion: 3,
                expectedClassificationVersion: 2, taxonomyCode: "professional_services",
                normalizedItemName: "研发外包服务", reason: "合同属于外包服务"
            )
        ))
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-decision-reject-v0.11.0")
        let rejected = try await api.decide(ClassificationDecisionCommand(
            recordId: "103",
            request: ClassificationDecisionRequest(
                accountBookId: "11", action: .reject, expectedRecordVersion: 1,
                expectedClassificationVersion: 0, taxonomyCode: nil,
                normalizedItemName: nil, reason: "证据不足"
            )
        ))

        XCTAssertEqual(confirmed.decision.action, .confirm)
        XCTAssertEqual(corrected.decision.action, .correct)
        XCTAssertEqual(rejected.decision.action, .reject)
        XCTAssertEqual(rejected.decision.classification.status, "rejected")
        let firstBody = try XCTUnwrap(ClassificationReviewURLProtocol.capturedBodies.first ?? nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: firstBody) as? [String: Any])
        XCTAssertEqual(json["action"] as? String, "confirm")
        XCTAssertEqual(json["normalizedItemName"] as? String, "Codex / OpenAI")
        XCTAssertNil(json["normalizedGroupName"])
    }

    func testRecordAndClassificationConflictsRemainRecognizable() async throws {
        let api = makeAPI()
        let command = makeDecisionCommand()
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-record-conflict-v0.11.0", statusCode: 409)
        do {
            _ = try await api.decide(command)
            XCTFail("record conflict must throw")
        } catch APIError.versionConflict(let expected, let current) {
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(current, 4)
        }

        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-version-conflict-v0.11.0", statusCode: 409)
        do {
            _ = try await api.decide(command)
            XCTFail("classification conflict must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 409)
            XCTAssertEqual(code, "CLASSIFICATION_VERSION_CONFLICT")
        }
    }

    func testForbiddenAndAIUnavailableResponsesRemainRecognizable() async throws {
        let api = makeAPI()
        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-forbidden-v0.11.0", statusCode: 403)
        do {
            _ = try await api.list(ClassificationReviewQuery())
            XCTFail("forbidden list must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "CLASSIFICATION_REVIEW_FORBIDDEN")
        }

        ClassificationReviewURLProtocol.handler = fixtureResponse(named: "classification-ai-unavailable-v0.11.0", statusCode: 503)
        do {
            _ = try await api.analyze(ClassificationAnalyzeCommand(
                recordId: "102",
                request: ClassificationVersionRequest(accountBookId: "11", expectedRecordVersion: 3, expectedClassificationVersion: 2)
            ))
            XCTFail("unavailable AI must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 503)
            XCTAssertEqual(code, "CLASSIFICATION_AI_UNAVAILABLE")
        }
    }

    private func makeDecisionCommand() -> ClassificationDecisionCommand {
        ClassificationDecisionCommand(
            recordId: "102",
            request: ClassificationDecisionRequest(
                accountBookId: "11", action: .confirm, expectedRecordVersion: 3,
                expectedClassificationVersion: 2, taxonomyCode: "software_cloud",
                normalizedItemName: "Codex / OpenAI", reason: "已核对合同"
            )
        )
    }

    private func makeAPI() -> LiveClassificationReviewAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ClassificationReviewURLProtocol.self]
        return LiveClassificationReviewAPI(transport: HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        ))
    }

    private func fixtureResponse(named name: String, statusCode: Int = 200) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        let data = try! fixture(named: name)
        return { request in
            (HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
    }

    private func capturedRequest(file: StaticString = #filePath, line: UInt = #line) -> URLRequest {
        guard let request = ClassificationReviewURLProtocol.capturedRequests.last else {
            XCTFail("expected a captured request", file: file, line: line)
            return URLRequest(url: URL(string: "https://invalid.local")!)
        }
        return request
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}

private final class ClassificationReviewURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var capturedRequests: [URLRequest] = []
    static var capturedBodies: [Data?] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        do {
            Self.capturedRequests.append(request)
            Self.capturedBodies.append(Self.bodyData(from: request))
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        let size = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        var data = Data()
        while true {
            let count = stream.read(buffer, maxLength: size)
            if count < 0 { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
