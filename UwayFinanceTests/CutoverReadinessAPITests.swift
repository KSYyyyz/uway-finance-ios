import XCTest
@testable import UwayFinance

final class CutoverReadinessAPITests: XCTestCase {
    override func tearDown() {
        CutoverReadinessURLProtocol.handler = nil
        CutoverReadinessURLProtocol.capturedRequests = []
        super.tearDown()
    }

    func testZeroDifferenceReportDecodesExactMoneyWithoutEnablingWrites() async throws {
        CutoverReadinessURLProtocol.handler = fixtureResponse(named: "cutover-readiness-zero-v0.10.1")
        let response = try await makeAPI().readiness(CutoverReadinessQuery(accountBookId: "11"))

        XCTAssertTrue(response.snapshot.digestsMatch)
        XCTAssertTrue(response.readiness.businessRecordReadCutoverEligible)
        XCTAssertFalse(response.readiness.businessRecordWriteCutoverEligible)
        XCTAssertFalse(response.readiness.fullFinanceCutoverEligible)
        XCTAssertEqual(response.differences.total, 0)
        XCTAssertEqual(response.summary.legacy.businessRecords.income.value.cents, 1_001)
        XCTAssertEqual(response.summary.legacy.businessRecords.expense.value.cents, 30)
        let query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!,
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
        XCTAssertEqual(query.first(where: { $0.name == "limit" })?.value, "50")
        XCTAssertEqual(capturedRequest().httpMethod, "GET")
        XCTAssertNil(capturedRequest().httpBody)
    }

    func testDifferenceReportPreservesBlockersAndOpaqueCursorPagination() async throws {
        CutoverReadinessURLProtocol.handler = fixtureResponse(named: "cutover-readiness-differences-v0.10.1")
        let cursor = "opaque+/cursor="
        let response = try await makeAPI().readiness(CutoverReadinessQuery(
            accountBookId: "11",
            limit: 1,
            cursor: cursor
        ))

        XCTAssertFalse(response.readiness.businessRecordReadCutoverEligible)
        XCTAssertEqual(response.readiness.blockers.map(\.code), [
            "LEGACY_V2_DIFFERENCES",
            "V2_SHADOW_ONLY_RECORDS",
            "BUSINESS_RECORD_DELETE_UNAVAILABLE",
            "BANK_TRANSACTION_RESOURCE_UNAVAILABLE",
        ])
        XCTAssertEqual(response.differences.total, 2)
        XCTAssertEqual(response.differences.items.first?.kind, .fieldMismatch)
        XCTAssertEqual(response.differences.items.first?.fields, ["amountCents"])
        XCTAssertNotNil(response.differences.page.nextCursor)
        XCTAssertEqual(response.summary.v2ShadowOnly.businessRecords.expense.value.cents, 100)

        let query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!,
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, cursor)
        XCTAssertEqual(query.first(where: { $0.name == "limit" })?.value, "1")
    }

    func testEmployeeForbiddenResponseRemainsRecognizable() async throws {
        CutoverReadinessURLProtocol.handler = fixtureResponse(
            named: "cutover-readiness-forbidden-v0.10.1",
            statusCode: 403
        )

        do {
            _ = try await makeAPI().readiness(CutoverReadinessQuery())
            XCTFail("employee role must not read full-book readiness")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "CUTOVER_READINESS_FORBIDDEN")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInvalidCursorResponseRemainsRecognizable() async throws {
        CutoverReadinessURLProtocol.handler = fixtureResponse(
            named: "cutover-readiness-invalid-cursor-v0.10.1",
            statusCode: 400
        )

        do {
            _ = try await makeAPI().readiness(CutoverReadinessQuery(cursor: "fabricated"))
            XCTFail("invalid cursor must fail without replacing local state")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(code, "INVALID_CUTOVER_CURSOR")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    private func makeAPI() -> LiveCutoverReadinessAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CutoverReadinessURLProtocol.self]
        let transport = HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        )
        return LiveCutoverReadinessAPI(transport: transport)
    }

    private func fixtureResponse(
        named name: String,
        statusCode: Int = 200
    ) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        let data = try! fixture(named: name)
        return { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
    }

    private func capturedRequest(file: StaticString = #filePath, line: UInt = #line) -> URLRequest {
        guard let request = CutoverReadinessURLProtocol.capturedRequests.last else {
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

private final class CutoverReadinessURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        do {
            Self.capturedRequests.append(request)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
