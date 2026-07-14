import XCTest
@testable import UwayFinance

final class LegacyStateConditionalWriteAPITests: XCTestCase {
    override func tearDown() {
        ConditionalStateURLProtocol.handler = nil
        ConditionalStateURLProtocol.requests = []
        super.tearDown()
    }

    func testFirstEmptyLedgerWriteSendsQuotedZeroIfMatch() async throws {
        ConditionalStateURLProtocol.handler = fixtureResponse(named: "state-save-v0.11.0")
        let revision = try await makeAPI().saveState(.empty, ifMatch: .empty)

        XCTAssertEqual(capturedRequest().value(forHTTPHeaderField: "If-Match"), "\"0\"")
        XCTAssertEqual(revision, StateRevision(updatedAt: "2026-07-15T00:02:00.000Z"))
    }

    func testContinuousWriteSendsQuotedFetchedRevision() async throws {
        ConditionalStateURLProtocol.handler = fixtureResponse(named: "state-save-v0.11.0")
        let fetched = StateRevision(updatedAt: "2026-07-15T00:01:00.000Z")

        _ = try await makeAPI().saveState(.empty, ifMatch: fetched)

        XCTAssertEqual(
            capturedRequest().value(forHTTPHeaderField: "If-Match"),
            "\"2026-07-15T00:01:00.000Z\""
        )
    }

    func testStateVersionConflictDecodesCurrentRevisionWithoutLosingErrorIdentity() async throws {
        ConditionalStateURLProtocol.handler = fixtureResponse(
            named: "state-version-conflict-v0.11.0",
            statusCode: 409
        )

        do {
            _ = try await makeAPI().saveState(
                .empty,
                ifMatch: StateRevision(updatedAt: "2026-07-15T00:00:00.000Z")
            )
            XCTFail("stale revision must throw")
        } catch APIError.stateVersionConflict(let currentUpdatedAt) {
            XCTAssertEqual(currentUpdatedAt, "2026-07-15T00:01:00.000Z")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testEmptyStateEnvelopeRestoresZeroRevision() async throws {
        ConditionalStateURLProtocol.handler = fixtureResponse(named: "state-empty-v0.11.0")

        let envelope = try await makeAPI().fetchState()

        XCTAssertEqual(envelope.data, .empty)
        XCTAssertEqual(StateRevision(updatedAt: envelope.updatedAt), .empty)
    }

    private func makeAPI() -> LiveFinanceAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConditionalStateURLProtocol.self]
        return LiveFinanceAPI(transport: HTTPTransport(
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
        guard let request = ConditionalStateURLProtocol.requests.last else {
            XCTFail("expected request", file: file, line: line)
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

private final class ConditionalStateURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        do {
            Self.requests.append(request)
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
