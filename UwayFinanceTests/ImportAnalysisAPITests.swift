import XCTest
@testable import UwayFinance

final class ImportAnalysisAPITests: XCTestCase {
    override func tearDown() {
        ImportAnalysisURLProtocol.reset()
        super.tearDown()
    }

    func testContextAndAnalysisCarryAuthenticatedAccountBookScope() async throws {
        ImportAnalysisURLProtocol.handler = { request in
            let fixture = request.url?.path == "/api/v2/context"
                ? "finance-context-v0.10.0"
                : "harness-result"
            return (Self.response(request, status: 200), try Self.fixture(named: fixture))
        }
        let api = makeAPI()
        let context = try await api.accountBookContext()
        let request = try JSONDecoder().decode(
            ImportAnalysisRequest.self,
            from: Self.fixture(named: "import-analysis-request-account-book-v0.14.0")
        )

        _ = try await api.analyze(request)

        XCTAssertEqual(context.selectedAccountBook.id, "11")
        let captured = try XCTUnwrap(ImportAnalysisURLProtocol.requests.last)
        XCTAssertEqual(captured.url?.path, "/api/import-analysis")
        let encoded = try JSONDecoder().decode(ImportAnalysisRequest.self, from: Self.body(captured))
        XCTAssertEqual(encoded, request)
        XCTAssertEqual(encoded.accountBookId, "11")
    }

    func testDecisionCarriesAccountBookAndServerReviewerRemainsAuthoritative() async throws {
        ImportAnalysisURLProtocol.handler = { request in
            (Self.response(request, status: 200), try Self.fixture(named: "import-decision-response"))
        }
        let api = makeAPI()
        let command = ImportReviewDecision(accountBookId: "11", decision: "accept", reason: "已核对银行回单")

        let result = try await api.decide(analysisId: "analysis-001", decision: command)

        XCTAssertEqual(result.status, "accepted")
        XCTAssertEqual(result.resolution.reviewer, "finance-admin")
        let captured = try XCTUnwrap(ImportAnalysisURLProtocol.requests.last)
        XCTAssertEqual(captured.url?.path, "/api/import-analysis/analysis-001/decision")
        XCTAssertEqual(try JSONDecoder().decode(ImportReviewDecision.self, from: Self.body(captured)), command)
    }

    func testCanonicalRequestHashReuseConflictRemainsRecognizable() async throws {
        ImportAnalysisURLProtocol.handler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "code": "IMPORT_ANALYSIS_ID_REUSED",
                "error": "analysisId has already been used with different request content",
            ])
            return (Self.response(request, status: 409), data)
        }
        let api = makeAPI()
        let request = try JSONDecoder().decode(
            ImportAnalysisRequest.self,
            from: Self.fixture(named: "import-analysis-request-account-book-v0.14.0")
        )

        do {
            _ = try await api.analyze(request)
            XCTFail("canonical request mismatch must fail closed")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 409)
            XCTAssertEqual(code, "IMPORT_ANALYSIS_ID_REUSED")
        }
        XCTAssertEqual(
            try JSONDecoder().decode(ImportAnalysisRequest.self, from: Self.body(try XCTUnwrap(ImportAnalysisURLProtocol.requests.last))),
            request
        )
    }

    func testDecisionConflictRemainsRecognizableWithoutChangingRequest() async throws {
        ImportAnalysisURLProtocol.handler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "code": "IMPORT_ANALYSIS_DECISION_CONFLICT",
                "error": "analysis decision already exists with different content",
            ])
            return (Self.response(request, status: 409), data)
        }
        let api = makeAPI()
        let command = ImportReviewDecision(accountBookId: "11", decision: "reject", reason: "归属不符")

        do {
            _ = try await api.decide(analysisId: "analysis-001", decision: command)
            XCTFail("decision mismatch must fail closed")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 409)
            XCTAssertEqual(code, "IMPORT_ANALYSIS_DECISION_CONFLICT")
        }
        XCTAssertEqual(
            try JSONDecoder().decode(ImportReviewDecision.self, from: Self.body(try XCTUnwrap(ImportAnalysisURLProtocol.requests.last))),
            command
        )
    }

    private func makeAPI() -> LiveImportAnalysisAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImportAnalysisURLProtocol.self]
        return LiveImportAnalysisAPI(transport: HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        ))
    }

    private static func response(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: ImportAnalysisAPITests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private static func body(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
        defer { buffer.deallocate() }
        var data = Data()
        while true {
            let count = stream.read(buffer, maxLength: 4_096)
            if count < 0 { throw stream.streamError ?? APIError.invalidResponse }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class ImportAnalysisURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()
    private(set) static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
            defer { buffer.deallocate() }
            var data = Data()
            while true {
                let count = stream.read(buffer, maxLength: 4_096)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            captured.httpBodyStream = nil
            captured.httpBody = data
        }
        Self.lock.lock()
        Self.requests.append(captured)
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        do {
            let (response, data) = try handler(captured)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
