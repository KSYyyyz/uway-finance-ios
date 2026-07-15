import XCTest
@testable import UwayFinance

final class RegistrationAPITests: XCTestCase {
    override func tearDown() {
        RegistrationURLProtocol.reset()
        super.tearDown()
    }

    func testRequestsRegistrationCodeWithPhoneOnlyInJSONBody() async throws {
        RegistrationURLProtocol.handler = fixtureResponse(named: "registration-code-success-v0.14.0", statusCode: 202)

        let response = try await makeAPI().requestRegistrationCode(phone: "+8613800138000")

        XCTAssertEqual(response.challengeId, "challenge-20260716-abcdefghijklmnop")
        XCTAssertEqual(response.expiresInSeconds, 300)
        XCTAssertEqual(response.resendAfterSeconds, 60)
        let request = capturedRequests().first
        XCTAssertEqual(request?.url?.path, "/api/auth/registration-code")
        XCTAssertNil(request?.url?.query)
        XCTAssertEqual(request?.httpMethod, "POST")
        let body = try requestBody(try XCTUnwrap(request))
        XCTAssertEqual(try JSONDecoder().decode(RegistrationCodeRequest.self, from: body), RegistrationCodeRequest(phone: "+8613800138000"))
    }

    func testRegisterKeepsPasswordAndCodeOutOfURLAndDecodesIsolatedScope() async throws {
        RegistrationURLProtocol.handler = fixtureResponse(named: "registration-success-v0.14.0", statusCode: 201)
        let command = RegistrationRequest(
            username: "new_owner",
            password: "SecurePass2026",
            phone: "+8613800138000",
            challengeId: "reg_20260716_abcdefghijklmnop",
            code: "246810"
        )

        let response = try await makeAPI().register(command)

        XCTAssertEqual(response.user, SessionUser(id: "201", username: "new_owner"))
        XCTAssertEqual(response.organizationId, "301")
        XCTAssertEqual(response.accountBookId, "401")
        let request = try XCTUnwrap(capturedRequests().first)
        XCTAssertEqual(request.url?.path, "/api/auth/register")
        XCTAssertNil(request.url?.query)
        XCTAssertFalse(request.url?.absoluteString.contains(command.password) ?? true)
        XCTAssertFalse(request.url?.absoluteString.contains(command.code) ?? true)
        XCTAssertEqual(try JSONDecoder().decode(RegistrationRequest.self, from: requestBody(request)), command)
    }

    func testEveryFrozenRegistrationErrorKeepsServerIdentityAndHasChineseMessage() async throws {
        let fixtures = try JSONDecoder().decode([RegistrationErrorFixture].self, from: fixture(named: "registration-errors-v0.14.0"))
        XCTAssertEqual(fixtures.count, 8)

        for item in fixtures {
            RegistrationURLProtocol.resetRequests()
            RegistrationURLProtocol.handler = { request in
                let data = try JSONSerialization.data(withJSONObject: ["code": item.code, "error": item.error])
                return (HTTPURLResponse(
                    url: request.url!, statusCode: item.status, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!, data)
            }

            do {
                _ = try await makeAPI().requestRegistrationCode(phone: "+8613800138000")
                XCTFail("\(item.code) must fail")
            } catch APIError.server(let status, let code, _) {
                XCTAssertEqual(status, item.status)
                XCTAssertEqual(code, item.code)
                XCTAssertFalse(RegistrationErrorMessage.localized(
                    APIError.server(status: status, code: code, message: item.error)
                ).isEmpty)
            } catch {
                XCTFail("unexpected error for \(item.code): \(error)")
            }
        }
    }

    func testAuthenticationRequestsAreSerializedSoSlowACompletesBeforeB() async throws {
        RegistrationURLProtocol.handler = { request in
            let body = try Self.requestBody(request)
            let input = try JSONDecoder().decode(LoginInput.self, from: body)
            if input.username == "user-a" { Thread.sleep(forTimeInterval: 0.08) }
            let data = try JSONSerialization.data(withJSONObject: [
                "user": ["id": "id-\(input.username)", "username": input.username],
            ])
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
        let api = makeAPI()

        async let first = api.login(username: "user-a", password: "PasswordA1")
        try await Task.sleep(for: .milliseconds(5))
        async let second = api.login(username: "user-b", password: "PasswordB1")
        let users = try await [first, second]

        XCTAssertEqual(users.map(\.username), ["user-a", "user-b"])
        XCTAssertEqual(capturedRequests().count, 2)
        XCTAssertEqual(try decodedLoginUsernames(), ["user-a", "user-b"])
    }

    private func makeAPI() -> LiveFinanceAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RegistrationURLProtocol.self]
        return LiveFinanceAPI(transport: HTTPTransport(
            baseURL: URL(string: "https://finance.example.test")!,
            session: URLSession(configuration: configuration)
        ))
    }

    private func fixtureResponse(named name: String, statusCode: Int) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        let data = try! fixture(named: name)
        return { request in
            (HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func capturedRequests() -> [URLRequest] { RegistrationURLProtocol.capturedRequests() }

    private func decodedLoginUsernames() throws -> [String] {
        try capturedRequests().map { try JSONDecoder().decode(LoginInput.self, from: Self.requestBody($0)).username }
    }

    private static func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 4096)
            if count < 0 { throw stream.streamError ?? APIError.invalidResponse }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private func requestBody(_ request: URLRequest) throws -> Data { try Self.requestBody(request) }
}

private struct LoginInput: Decodable { let username: String }

private struct RegistrationErrorFixture: Decodable {
    let status: Int
    let code: String
    let error: String
}

private final class RegistrationURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()
    private static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    static func resetRequests() {
        lock.lock()
        requests = []
        lock.unlock()
    }

    static func capturedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var normalizedRequest = request
        if normalizedRequest.httpBody == nil, let stream = normalizedRequest.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 4096)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            normalizedRequest.httpBodyStream = nil
            normalizedRequest.httpBody = data
        }
        Self.lock.lock()
        Self.requests.append(normalizedRequest)
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        do {
            let (response, data) = try handler(normalizedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
