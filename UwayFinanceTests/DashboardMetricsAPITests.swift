import XCTest
@testable import UwayFinance

final class DashboardMetricsAPITests: XCTestCase {
    override func tearDown() {
        DashboardMetricsURLProtocol.handler = nil
        DashboardMetricsURLProtocol.capturedRequests = []
        super.tearDown()
    }

    func testMetricsDecodeExactMoneyGroupsTraceCoverageAndSafety() async throws {
        DashboardMetricsURLProtocol.handler = fixtureResponse(named: "dashboard-metrics-v0.10.2")
        let response = try await makeAPI().metrics(DashboardMetricsQuery(
            period: "2026-07",
            accountBookId: "11"
        ))

        XCTAssertEqual(response.period, "2026-07")
        XCTAssertEqual(response.metricDefinition.code, "cash_dashboard_v1")
        XCTAssertEqual(response.metricDefinition.moneyEncoding, "decimal_string")
        XCTAssertEqual(response.overview.paidIncome.value.cents, 1_000_000)
        XCTAssertEqual(response.overview.paidExpense.value.cents, 200_000)
        XCTAssertEqual(response.overview.netCashFlow.value.cents, 800_000)
        XCTAssertEqual(response.trend.last?.received.value.cents, 1_000_000)
        XCTAssertEqual(response.sameTypeGroups.first?.recordIds, ["102", "103"])
        XCTAssertEqual(response.sameTypeGroups.first?.classificationState, .accepted)
        XCTAssertEqual(response.sameTypeGroups.first?.trace.origins, ["rule"])
        XCTAssertEqual(response.classificationCoverage.review, 1)
        XCTAssertFalse(response.safety.rawBusinessRecordsMerged)
        XCTAssertFalse(response.safety.modelWritesBusinessRecords)
        XCTAssertFalse(response.safety.reviewSuggestionsAffectRawFacts)

        let request = capturedRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        let query = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "period" })?.value, "2026-07")
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
    }

    func testNegativeNetCashFlowRemainsExactSignedDecimalMoney() async throws {
        DashboardMetricsURLProtocol.handler = fixtureResponse(named: "dashboard-metrics-negative-v0.10.2")
        let response = try await makeAPI().metrics(DashboardMetricsQuery(period: "2026-07"))

        XCTAssertEqual(response.overview.paidExpense.value.cents, 1_183_000)
        XCTAssertEqual(response.overview.netCashFlow.value.cents, -183_000)
        XCTAssertEqual(response.overview.netCashFlow.value.decimalString, "-1830.00")
    }

    func testEmployeeForbiddenResponseRemainsRecognizable() async throws {
        DashboardMetricsURLProtocol.handler = fixtureResponse(
            named: "dashboard-metrics-forbidden-v0.10.2",
            statusCode: 403
        )

        do {
            _ = try await makeAPI().metrics(DashboardMetricsQuery(period: "2026-07"))
            XCTFail("employee role must not read full-book metrics")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "DASHBOARD_METRICS_FORBIDDEN")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInvalidPeriodResponseRemainsRecognizable() async throws {
        DashboardMetricsURLProtocol.handler = fixtureResponse(
            named: "dashboard-metrics-invalid-period-v0.10.2",
            statusCode: 400
        )

        do {
            _ = try await makeAPI().metrics(DashboardMetricsQuery(period: "2026-13"))
            XCTFail("invalid period must be rejected")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(code, "INVALID_DASHBOARD_METRICS_QUERY")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!,
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "period" })?.value, "2026-13")
    }

    private func makeAPI() -> LiveDashboardMetricsAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DashboardMetricsURLProtocol.self]
        let transport = HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        )
        return LiveDashboardMetricsAPI(transport: transport)
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
        guard let request = DashboardMetricsURLProtocol.capturedRequests.last else {
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

private final class DashboardMetricsURLProtocol: URLProtocol {
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
