import XCTest
@testable import UwayFinance

final class FinanceResourceAPITests: XCTestCase {
    override func tearDown() {
        FinanceResourceURLProtocol.handler = nil
        FinanceResourceURLProtocol.capturedRequests = []
        FinanceResourceURLProtocol.capturedBodies = []
        super.tearDown()
    }

    func testContextDecodesAuthenticatedAccountBookAccess() async throws {
        FinanceResourceURLProtocol.handler = fixtureResponse(named: "finance-context-v0.10.0")
        let api = makeAPI()

        let context = try await api.context(accountBookId: "11")

        XCTAssertEqual(context.selectedAccountBook.id, "11")
        XCTAssertEqual(context.selectedAccountBook.organization.id, "7")
        XCTAssertTrue(context.selectedAccountBook.permissions.writeBusinessRecords)
        let query = try XCTUnwrap(URLComponents(url: capturedRequest().url!, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
    }

    func testBusinessRecordListUsesCursorFiltersAndExactDecimalMoney() async throws {
        FinanceResourceURLProtocol.handler = fixtureResponse(named: "business-records-page-v0.10.0")
        let api = makeAPI()

        let response = try await api.listBusinessRecords(BusinessRecordListQuery(
            accountBookId: "11",
            limit: 1,
            cursor: "opaque+/cursor=",
            direction: .expense,
            financeStatus: .draft
        ))

        XCTAssertEqual(response.items.first?.preciseAmount.cents, 303)
        XCTAssertNotNil(response.page.nextCursor)
        let query = try XCTUnwrap(URLComponents(url: capturedRequest().url!, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, "opaque+/cursor=")
        XCTAssertEqual(query.first(where: { $0.name == "direction" })?.value, "expense")
        XCTAssertEqual(query.first(where: { $0.name == "financeStatus" })?.value, "draft")
    }

    func testCreateReusesStableIdempotencyHeaderAndEncodesDecimalString() async throws {
        FinanceResourceURLProtocol.handler = fixtureResponse(named: "business-record-response-v0.10.0")
        let api = makeAPI()
        let request = BusinessRecordCreateRequest(
            accountBookId: "11",
            eventDate: "2026-07-04",
            direction: .expense,
            amount: V2DecimalAmount(MoneyAmount(cents: 30)),
            category: "软件服务",
            counterparty: "OpenAI",
            project: "Uway",
            account: "基本户",
            description: "Codex 续费"
        )
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let command = CreateBusinessRecordCommand(request: request, operationID: operationID)

        let first = try await api.createBusinessRecord(command)
        _ = try await api.createBusinessRecord(command)

        XCTAssertEqual(first.record.preciseAmount.cents, 30)
        XCTAssertEqual(FinanceResourceURLProtocol.capturedRequests.count, 2)
        let headers = FinanceResourceURLProtocol.capturedRequests.compactMap {
            $0.value(forHTTPHeaderField: "Idempotency-Key")
        }
        XCTAssertEqual(Set(headers), Set(["ios-create-record-00000000-0000-0000-0000-000000000001"]))
        let body = try XCTUnwrap(FinanceResourceURLProtocol.capturedBodies.last ?? nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["amount"] as? String, "0.30")
    }

    func testUpdateSendsExpectedVersionAndRecognizesVersionConflict() async throws {
        FinanceResourceURLProtocol.handler = fixtureResponse(named: "version-conflict-v0.10.0", statusCode: 409)
        let api = makeAPI()
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let command = UpdateBusinessRecordCommand(
            recordId: "103",
            request: BusinessRecordPatchRequest(
                accountBookId: "11",
                expectedVersion: 3,
                changes: BusinessRecordChanges(description: "过期设备覆盖")
            ),
            operationID: operationID
        )

        do {
            _ = try await api.updateBusinessRecord(command)
            XCTFail("stale update should throw a recognizable conflict")
        } catch APIError.versionConflict(let expectedVersion, let currentVersion) {
            XCTAssertEqual(expectedVersion, 3)
            XCTAssertEqual(currentVersion, 4)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let request = capturedRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "ios-update-record-00000000-0000-0000-0000-000000000002")
        let body = try XCTUnwrap(FinanceResourceURLProtocol.capturedBodies.last ?? nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["expectedVersion"] as? Int, 3)
    }

    private func makeAPI() -> LiveFinanceResourceAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FinanceResourceURLProtocol.self]
        let transport = HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        )
        return LiveFinanceResourceAPI(transport: transport)
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
        guard let request = FinanceResourceURLProtocol.capturedRequests.last else {
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

private final class FinanceResourceURLProtocol: URLProtocol {
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
        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        var data = Data()
        while true {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
