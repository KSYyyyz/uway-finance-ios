import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidResponse
    case unauthorized
    case server(status: Int, code: String?, message: String)
    case versionConflict(expectedVersion: Int, currentVersion: Int?)
    case transport(String)
    case decoding(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "服务器响应无效"
        case .unauthorized: return "登录已失效，请重新登录"
        case .server(_, _, let message): return message
        case .versionConflict(_, let currentVersion):
            if let currentVersion { return "经营事项已在其他设备更新（当前版本 \(currentVersion)），请刷新后重试" }
            return "经营事项已在其他设备更新，请刷新后重试"
        case .transport: return "暂时无法连接服务器，请检查网络后重试"
        case .decoding: return "服务器数据格式与客户端不一致"
        case .unavailable(let message): return message
        }
    }
}

private struct ErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    let code: String?
    let details: ErrorDetails?
}

private struct ErrorDetails: Decodable {
    let expectedVersion: Int?
    let currentVersion: Int?
}

actor HTTPTransport {
    let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieAcceptPolicy = .always
            configuration.httpShouldSetCookies = true
            configuration.httpCookieStorage = .shared
            configuration.timeoutIntervalForRequest = 30
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func send<Response: Decodable>(
        _ endpoint: APIEndpoint,
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await send(endpoint, encodedBody: nil, headers: headers)
    }

    func send<Response: Decodable, Body: Encodable>(
        _ endpoint: APIEndpoint,
        body: Body,
        headers: [String: String] = [:]
    ) async throws -> Response {
        let data: Data
        do { data = try encoder.encode(body) }
        catch { throw APIError.transport("请求编码失败") }
        return try await send(endpoint, encodedBody: data, headers: headers)
    }

    private func send<Response: Decodable>(
        _ endpoint: APIEndpoint,
        encodedBody: Data?,
        headers: [String: String]
    ) async throws -> Response {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = encodedBody
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if encodedBody != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(ErrorEnvelope.self, from: data)
            if http.statusCode == 409,
               envelope?.code == "VERSION_CONFLICT",
               let expectedVersion = envelope?.details?.expectedVersion {
                throw APIError.versionConflict(
                    expectedVersion: expectedVersion,
                    currentVersion: envelope?.details?.currentVersion
                )
            }
            throw APIError.server(
                status: http.statusCode,
                code: envelope?.code,
                message: envelope?.error ?? envelope?.message ?? "服务器暂时无法处理请求"
            )
        }

        do { return try decoder.decode(Response.self, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }
}
