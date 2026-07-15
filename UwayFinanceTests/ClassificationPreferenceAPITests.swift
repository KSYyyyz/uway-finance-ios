import XCTest
@testable import UwayFinance

final class ClassificationPreferenceAPITests: XCTestCase {
    override func tearDown() {
        ClassificationPreferenceURLProtocol.handler = nil
        ClassificationPreferenceURLProtocol.capturedRequests = []
        ClassificationPreferenceURLProtocol.capturedBodies = []
        super.tearDown()
    }

    func testListKeepsAccountBookScopeStateAndOpaqueCursor() async throws {
        ClassificationPreferenceURLProtocol.handler = fixtureResponse(named: "classification-preferences-active-v0.12.0")
        let response = try await makeAPI().list(ClassificationPreferenceQuery(
            accountBookId: "11",
            state: .active,
            limit: 10,
            cursor: "opaque+/cursor="
        ))

        XCTAssertEqual(response.accountBook.id, "11")
        XCTAssertEqual(response.items.count, 2)
        XCTAssertTrue(response.items.allSatisfy { $0.accountBookId == "11" })
        XCTAssertEqual(response.items.first?.features.serviceTokens, ["codex_openai"])
        XCTAssertEqual(response.items.first?.lifecycle.state, .active)
        XCTAssertEqual(response.page.nextCursor, "opaque+/preference=")
        XCTAssertTrue(response.safety.accountBookScoped)
        XCTAssertFalse(response.safety.modelCanAccept)
        XCTAssertFalse(response.safety.writesBusinessRecords)

        let query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!, resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
        XCTAssertEqual(query.first(where: { $0.name == "state" })?.value, "active")
        XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, "opaque+/cursor=")
    }

    func testRevokeUsesStableIdempotencyKeyExpectedVersionAndReason() async throws {
        ClassificationPreferenceURLProtocol.handler = fixtureResponse(named: "classification-preference-revoke-v0.12.0")
        let api = makeAPI()
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000120"))
        let command = ClassificationPreferenceRevokeCommand(
            observationId: "701",
            request: ClassificationPreferenceRevokeRequest(
                accountBookId: "11",
                expectedVersion: 1,
                reason: "这次判断不应继续参与分类"
            ),
            operationID: operationID
        )

        let first = try await api.revoke(command)
        _ = try await api.revoke(command)

        XCTAssertEqual(first.observation.lifecycle.state, .revoked)
        XCTAssertEqual(first.observation.version, 2)
        XCTAssertTrue(first.safety.recomputedFromActiveEvents)
        XCTAssertFalse(first.safety.modelCanAccept)
        XCTAssertFalse(first.safety.writesBusinessRecords)
        XCTAssertTrue(capturedRequest().url?.path.hasSuffix("/classification-preferences/701/revoke") == true)
        let keys = ClassificationPreferenceURLProtocol.capturedRequests.compactMap {
            $0.value(forHTTPHeaderField: "Idempotency-Key")
        }
        XCTAssertEqual(Set(keys), Set(["ios-classification-preference-revoke-00000000-0000-0000-0000-000000000120"]))
        let bodies = try ClassificationPreferenceURLProtocol.capturedBodies.map { try XCTUnwrap($0) }
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(
            try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? NSDictionary),
            try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[1]) as? NSDictionary)
        )
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? [String: Any])
        XCTAssertEqual(body["accountBookId"] as? String, "11")
        XCTAssertEqual(body["expectedVersion"] as? Int, 1)
        XCTAssertEqual(body["reason"] as? String, "这次判断不应继续参与分类")
    }

    func testConflictForbiddenAndInvalidCursorRemainRecognizable() async throws {
        let api = makeAPI()
        ClassificationPreferenceURLProtocol.handler = fixtureResponse(
            named: "classification-preference-version-conflict-v0.12.0", statusCode: 409
        )
        do {
            _ = try await api.revoke(ClassificationPreferenceRevokeCommand(
                observationId: "701",
                request: ClassificationPreferenceRevokeRequest(
                    accountBookId: "11", expectedVersion: 1, reason: "版本冲突测试"
                )
            ))
            XCTFail("preference version conflict must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 409)
            XCTAssertEqual(code, "CLASSIFICATION_PREFERENCE_VERSION_CONFLICT")
        }

        ClassificationPreferenceURLProtocol.handler = fixtureResponse(
            named: "classification-preference-forbidden-v0.12.0", statusCode: 403
        )
        do {
            _ = try await api.list(ClassificationPreferenceQuery(accountBookId: "11"))
            XCTFail("forbidden list must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "CLASSIFICATION_PREFERENCE_FORBIDDEN")
        }

        ClassificationPreferenceURLProtocol.handler = fixtureResponse(
            named: "classification-preference-invalid-cursor-v0.12.0", statusCode: 400
        )
        do {
            _ = try await api.list(ClassificationPreferenceQuery(accountBookId: "11", cursor: "bad"))
            XCTFail("invalid cursor must throw")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(code, "INVALID_CLASSIFICATION_PREFERENCE_CURSOR")
        }
    }

    private func makeAPI() -> LiveClassificationPreferenceAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ClassificationPreferenceURLProtocol.self]
        return LiveClassificationPreferenceAPI(transport: HTTPTransport(
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
        guard let request = ClassificationPreferenceURLProtocol.capturedRequests.last else {
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

private final class ClassificationPreferenceURLProtocol: URLProtocol {
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
