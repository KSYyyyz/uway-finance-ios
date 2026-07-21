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

    func testRequestsRegistrationEmailCodeWithEmailOnlyAndIndistinguishableResponse() async throws {
        RegistrationURLProtocol.handler = fixtureResponse(
            named: "registration-email-code-success-v0.16.0",
            statusCode: 202
        )

        let response = try await makeAPI().requestRegistrationEmailCode(email: "owner@example.com")

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.expiresInSeconds, 600)
        XCTAssertEqual(response.resendAfterSeconds, 60)
        XCTAssertFalse(response.message.isEmpty)
        let request = try XCTUnwrap(capturedRequests().first)
        XCTAssertEqual(request.url?.path, "/api/auth/registration-email-code")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            try JSONDecoder().decode(RegistrationEmailCodeRequest.self, from: requestBody(request)),
            RegistrationEmailCodeRequest(email: "owner@example.com")
        )
    }

    func testRegisterKeepsPasswordAndCodeOutOfURLAndDecodesIsolatedScope() async throws {
        RegistrationURLProtocol.handler = fixtureResponse(named: "registration-success-v0.14.0", statusCode: 201)
        let command = RegistrationRequest(
            username: "new_owner",
            email: "owner@example.com",
            password: "SecurePass2026",
            phone: "+8613800138000",
            challengeId: "reg_20260716_abcdefghijklmnop",
            code: "246810",
            emailChallengeId: "email_20260721_abcdefghijklmnop",
            emailCode: "135790"
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
        XCTAssertFalse(request.url?.absoluteString.contains(command.emailCode) ?? true)
        XCTAssertEqual(try JSONDecoder().decode(RegistrationRequest.self, from: requestBody(request)), command)
    }

    func testLoginUsesIdentifierForUsernamePhoneAndEmailWithUnifiedFailureShape() async throws {
        let identifiers = ["owner", "+8613800138000", "owner@example.com"]
        RegistrationURLProtocol.handler = { request in
            let input = try JSONDecoder().decode(LoginInput.self, from: Self.requestBody(request))
            let data = try JSONSerialization.data(withJSONObject: [
                "user": ["id": "id-\(input.loginIdentifier)", "username": "owner"],
            ])
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
        let api = makeAPI()

        for identifier in identifiers {
            _ = try await api.login(identifier: identifier, password: "SafePassword", useLegacyUsernameField: false)
        }

        let requests = capturedRequests()
        XCTAssertEqual(requests.count, 3)
        for (request, identifier) in zip(requests, identifiers) {
            XCTAssertEqual(request.url?.path, "/api/auth/login")
            XCTAssertNil(request.url?.query)
            let body = try JSONDecoder().decode(LoginInput.self, from: requestBody(request))
            XCTAssertEqual(body.identifier, identifier)
            XCTAssertNil(body.username)
        }
        XCTAssertEqual(AuthenticationErrorMessage.localized(
            APIError.server(status: 401, code: "INVALID_CREDENTIALS", message: "账号或密码错误")
        ), "账号或密码错误")
    }

    func testLegacyLoginFallbackSendsUsernameAliasOnly() async throws {
        RegistrationURLProtocol.handler = { request in
            let input = try JSONDecoder().decode(LoginInput.self, from: Self.requestBody(request))
            let data = try JSONSerialization.data(withJSONObject: [
                "user": ["id": "legacy-id", "username": input.loginIdentifier],
            ])
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }

        _ = try await makeAPI().login(
            identifier: "legacy-owner",
            password: "SafePassword",
            useLegacyUsernameField: true
        )

        let input = try JSONDecoder().decode(LoginInput.self, from: requestBody(try XCTUnwrap(capturedRequests().first)))
        XCTAssertNil(input.identifier)
        XCTAssertEqual(input.username, "legacy-owner")
    }

    func testUsernameAvailabilityIsJSONBodyOnlyAndDecodesAllFrozenReasons() async throws {
        let fixtures = try JSONDecoder().decode(
            [UsernameAvailabilityFixture].self,
            from: fixture(named: "username-availability-v0.15.0")
        )
        XCTAssertEqual(Set(fixtures.compactMap(\.reason)), Set(["length", "format", "numeric_only", "reserved", "unavailable"]))
        let api = makeAPI()

        for item in fixtures {
            RegistrationURLProtocol.resetRequests()
            RegistrationURLProtocol.handler = { request in
                let data = try JSONEncoder().encode(UsernameAvailabilityResponse(
                    available: item.available,
                    reason: item.reason,
                    message: item.message
                ))
                return (HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!, data)
            }
            let response = try await api.usernameAvailability(UsernameAvailabilityRequest(username: item.username))
            XCTAssertEqual(response.available, item.available)
            XCTAssertEqual(response.reason, item.reason)
            let request = try XCTUnwrap(capturedRequests().first)
            XCTAssertEqual(request.url?.path, "/api/auth/username-availability")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(
                try JSONDecoder().decode(UsernameAvailabilityRequest.self, from: requestBody(request)).username,
                item.username
            )
        }
    }

    func testPasswordResetRequestAndConfirmKeepSecretsInJSONBodyAndDecodeFrozenResponses() async throws {
        let requestResponseData = try fixture(named: "password-reset-request-v0.15.0")
        let confirmResponseData = try fixture(named: "password-reset-confirm-v0.15.0")
        RegistrationURLProtocol.handler = { request in
            let data = request.url?.path.hasSuffix("/confirm") == true ? confirmResponseData : requestResponseData
            let status = request.url?.path.hasSuffix("/request") == true ? 202 : 200
            return (HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
        let api = makeAPI()

        let challenge = try await api.requestPasswordReset(PasswordResetRequest(email: "owner@example.com"))
        let command = PasswordResetConfirmRequest(
            email: "owner@example.com",
            challengeId: challenge.challengeId,
            code: "246810",
            newPassword: "UnrelatedSecurePassword"
        )
        let confirmation = try await api.confirmPasswordReset(command)

        XCTAssertTrue(challenge.ok)
        XCTAssertTrue(confirmation.ok)
        let requests = capturedRequests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/auth/password-reset/request",
            "/api/auth/password-reset/confirm",
        ])
        for request in requests { XCTAssertNil(request.url?.query) }
        XCTAssertFalse(requests[1].url?.absoluteString.contains(command.code) ?? true)
        XCTAssertFalse(requests[1].url?.absoluteString.contains(command.newPassword) ?? true)
        XCTAssertEqual(try JSONDecoder().decode(PasswordResetConfirmRequest.self, from: requestBody(requests[1])), command)
    }

    func testPasswordResetErrorsHaveStableChineseMessages() throws {
        let fixtures = try JSONDecoder().decode(
            [RegistrationErrorFixture].self,
            from: fixture(named: "password-reset-errors-v0.15.0")
        )
        XCTAssertEqual(fixtures.count, 6)
        for item in fixtures {
            let localized = AuthenticationErrorMessage.localized(
                APIError.server(status: item.status, code: item.code, message: item.error)
            )
            XCTAssertFalse(localized.isEmpty)
            if item.code == "EMAIL_RESET_UNAVAILABLE" { XCTAssertEqual(localized, "邮件找回暂未开通") }
        }
    }

    func testHistoricalV015RegistrationErrorsRemainDecodableAndLocalized() async throws {
        let fixtures = try JSONDecoder().decode([RegistrationErrorFixture].self, from: fixture(named: "registration-errors-v0.15.0"))
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

    func testV016RegistrationErrorsIncludeEmailChallengeFailuresWithoutLeakingIdentity() throws {
        let fixtures = try JSONDecoder().decode(
            [RegistrationErrorFixture].self,
            from: fixture(named: "registration-errors-v0.16.0")
        )

        XCTAssertEqual(fixtures.count, 12)
        XCTAssertEqual(
            Set(fixtures.map(\.code)),
            Set([
                "INVALID_PHONE", "INVALID_EMAIL", "INVALID_REGISTRATION_INPUT", "WEAK_PASSWORD",
                "INVALID_REGISTRATION_CODE", "INVALID_REGISTRATION_EMAIL_CODE",
                "REGISTRATION_CODE_RATE_LIMITED", "REGISTRATION_EMAIL_CODE_RATE_LIMITED",
                "REGISTRATION_IDENTITY_CONFLICT", "SMS_PROVIDER_UNAVAILABLE", "SMS_DELIVERY_FAILED",
                "EMAIL_VERIFICATION_UNAVAILABLE",
            ])
        )
        for item in fixtures {
            XCTAssertFalse(RegistrationErrorMessage.localized(
                APIError.server(status: item.status, code: item.code, message: item.error)
            ).isEmpty)
        }
    }

    func testAuthenticationRequestsAreSerializedSoSlowACompletesBeforeB() async throws {
        RegistrationURLProtocol.handler = { request in
            let body = try Self.requestBody(request)
            let input = try JSONDecoder().decode(LoginInput.self, from: body)
            if input.loginIdentifier == "user-a" { Thread.sleep(forTimeInterval: 0.08) }
            let data = try JSONSerialization.data(withJSONObject: [
                "user": ["id": "id-\(input.loginIdentifier)", "username": input.loginIdentifier],
            ])
            return (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
        let api = makeAPI()

        async let first = api.login(identifier: "user-a", password: "PasswordA1", useLegacyUsernameField: false)
        try await Task.sleep(for: .milliseconds(5))
        async let second = api.login(identifier: "user-b", password: "PasswordB1", useLegacyUsernameField: false)
        let users = try await [first, second]

        XCTAssertEqual(users.map(\.username), ["user-a", "user-b"])
        XCTAssertEqual(capturedRequests().count, 2)
        XCTAssertEqual(try decodedLoginIdentifiers(), ["user-a", "user-b"])
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

    private func decodedLoginIdentifiers() throws -> [String] {
        try capturedRequests().map { try JSONDecoder().decode(LoginInput.self, from: Self.requestBody($0)).loginIdentifier }
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

private struct LoginInput: Decodable {
    let identifier: String?
    let username: String?
    let password: String
    var loginIdentifier: String { identifier ?? username ?? "" }
}

private struct UsernameAvailabilityFixture: Decodable {
    let username: String
    let available: Bool
    let reason: String?
    let message: String
}

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
