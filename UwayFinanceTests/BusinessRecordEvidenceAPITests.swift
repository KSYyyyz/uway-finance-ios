import XCTest
@testable import UwayFinance

final class BusinessRecordEvidenceAPITests: XCTestCase {
    private let png = Data([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    ])

    override func tearDown() {
        EvidenceURLProtocol.handler = nil
        EvidenceURLProtocol.capturedRequests = []
        EvidenceURLProtocol.capturedBodies = []
        super.tearDown()
    }

    func testMediaDetectionUsesBytesForAllFrozenFormatsAndRejectsArbitraryContent() {
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: Data([0xff, 0xd8, 0xff, 0xe0])), "image/jpeg")
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: png), "image/png")
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: Data("RIFF0000WEBP".utf8)), "image/webp")
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: Data("%PDF-1.7".utf8)), "application/pdf")
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: Data([0, 0, 0, 0] + Array("ftypheic".utf8))), "image/heic")
        XCTAssertEqual(EvidenceMediaDetection.mediaType(for: Data([0, 0, 0, 0] + Array("ftypmif1".utf8))), "image/heif")
        XCTAssertNil(EvidenceMediaDetection.mediaType(for: Data("MZ executable".utf8)))
    }

    func testListAndCoverageCarryExplicitAccountBookScope() async throws {
        let api = makeAPI()
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-list-v0.13.0")
        let list = try await api.list(BusinessRecordEvidenceListQuery(
            accountBookId: "11", recordExternalId: "R-EVIDENCE", includeRevoked: true
        ))
        XCTAssertEqual(list.items.count, 2)
        XCTAssertEqual(list.items.map(\.status), [.active, .revoked])
        XCTAssertEqual(list.items.first?.evidenceType, .invoice)
        var query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!, resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
        XCTAssertEqual(query.first(where: { $0.name == "recordExternalId" })?.value, "R-EVIDENCE")
        XCTAssertEqual(query.first(where: { $0.name == "includeRevoked" })?.value, "true")

        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-coverage-v0.13.0")
        let coverage = try await api.coverage(accountBookId: "11")
        XCTAssertEqual(coverage.records["R-EVIDENCE"]?.activeEvidenceCount, 1)
        XCTAssertEqual(coverage.records["R-EVIDENCE"]?.invoiceEvidenceCount, 1)
        query = try XCTUnwrap(URLComponents(
            url: capturedRequest().url!, resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "accountBookId" })?.value, "11")
    }

    func testV014CoverageDecodesRequirementStatesAndExcludesRevokedFromActiveCounts() throws {
        let list = try decode(
            BusinessRecordEvidenceListResponse.self,
            "business-record-evidence-list-v0.14.0"
        )
        let response = try decode(
            BusinessRecordEvidenceCoverageResponse.self,
            "business-record-evidence-coverage-v0.14.0"
        )
        let covered = try XCTUnwrap(response.records["R-EVIDENCE"])
        XCTAssertEqual(list.items.count, 3)
        XCTAssertEqual(list.items.filter { $0.status == .active }.count, covered.activeEvidenceCount)
        XCTAssertEqual(covered.activeImageCount, 1)
        XCTAssertEqual(covered.invoiceEvidenceCount, 1)
        XCTAssertEqual(covered.contractEvidenceCount, 1)
        XCTAssertEqual(covered.requirementState, .satisfied)
        XCTAssertTrue(covered.missingRequiredTypes.isEmpty)
        XCTAssertTrue(covered.allowsUpload)

        let missing = try XCTUnwrap(response.records["R-MISSING"])
        XCTAssertTrue(missing.isRequiredMissing)
        XCTAssertEqual(missing.missingRequiredTypes, [.invoice, .supportingDocument])

        let notRequired = try XCTUnwrap(response.records["R-NOT-REQUIRED"])
        XCTAssertEqual(notRequired.requirementState, .notRequired)
        XCTAssertFalse(notRequired.allowsUpload)
        XCTAssertEqual(response.records["R-REVOKED-ONLY"]?.activeEvidenceCount, 0)

        XCTAssertTrue(try XCTUnwrap(list.items.first).supportsAutomaticPreview)
        XCTAssertFalse(try XCTUnwrap(list.items.last).supportsAutomaticPreview)
    }

    func testUploadKeepsMetadataBeforeFileAndReusesIdenticalBodyAndKey() async throws {
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-upload-v0.13.0", statusCode: 201)
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000130"))
        let command = BusinessRecordEvidenceUploadCommand(
            request: BusinessRecordEvidenceUploadRequest(
                accountBookId: "11",
                recordExternalId: "R-EVIDENCE",
                evidenceType: .invoice,
                note: "本月发票",
                file: SelectedEvidenceFile(fileName: "新发票.png", mediaType: "image/png", data: png)
            ),
            operationID: operationID
        )
        let api = makeAPI()

        let first = try await api.upload(command)
        _ = try await api.upload(command)

        XCTAssertTrue(first.fixed)
        XCTAssertTrue(first.contentImmutable)
        XCTAssertEqual(first.evidence.sha256, "02a3e298f1533f62558c58e4c70edcab9af5a50d62d925fd5390942020fb0fb8")
        XCTAssertEqual(EvidenceURLProtocol.capturedBodies.count, 2)
        let bodies = try EvidenceURLProtocol.capturedBodies.map { try XCTUnwrap($0) }
        XCTAssertEqual(bodies[0], bodies[1])
        let requests = EvidenceURLProtocol.capturedRequests
        XCTAssertEqual(Set(requests.compactMap { $0.value(forHTTPHeaderField: "Idempotency-Key") }), [
            "ios-evidence-upload-00000000-0000-0000-0000-000000000130",
        ])
        XCTAssertEqual(Set(requests.compactMap { $0.value(forHTTPHeaderField: "Content-Type") }), [
            "multipart/form-data; boundary=UwayEvidenceBoundary-00000000-0000-0000-0000-000000000130",
        ])
        let text = String(decoding: bodies[0], as: UTF8.self)
        let accountIndex = try XCTUnwrap(text.range(of: "name=\"accountBookId\""))
        let recordIndex = try XCTUnwrap(text.range(of: "name=\"recordExternalId\""))
        let typeIndex = try XCTUnwrap(text.range(of: "name=\"evidenceType\""))
        let noteIndex = try XCTUnwrap(text.range(of: "name=\"note\""))
        let fileIndex = try XCTUnwrap(text.range(of: "name=\"file\""))
        XCTAssertLessThan(accountIndex.lowerBound, recordIndex.lowerBound)
        XCTAssertLessThan(recordIndex.lowerBound, typeIndex.lowerBound)
        XCTAssertLessThan(typeIndex.lowerBound, noteIndex.lowerBound)
        XCTAssertLessThan(noteIndex.lowerBound, fileIndex.lowerBound)
        XCTAssertTrue(bodies[0].range(of: png) != nil)
    }

    func testContentRequiresMatchingBytesSHAAndETag() async throws {
        let evidence = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0").items[0]
        EvidenceURLProtocol.handler = { request in
            (HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: [
                    "Content-Type": "image/png",
                    "ETag": "\"02a3e298f1533f62558c58e4c70edcab9af5a50d62d925fd5390942020fb0fb8\"",
                    "Digest": "sha-256=AqPimPFTP2JVjFjkxw7cq5r1pQ1i2SX9U5CUIgD7D7g=",
                ]
            )!, self.png)
        }
        let content = try await makeAPI().content(evidence)
        XCTAssertEqual(content.data, png)
        XCTAssertEqual(content.mediaType, "image/png")
        XCTAssertEqual(content.evidenceId, "801")

        EvidenceURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!, Data("tampered content".utf8))
        }
        do {
            _ = try await makeAPI().content(evidence)
            XCTFail("tampered evidence must fail closed")
        } catch APIError.server(let status, let code, _) {
            XCTAssertEqual(status, 409)
            XCTAssertEqual(code, "EVIDENCE_INTEGRITY_MISMATCH")
        }
    }

    func testRevokeUsesExpectedVersionReasonAndStableIdempotencyKey() async throws {
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-revoke-v0.13.0")
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000131"))
        let command = BusinessRecordEvidenceRevokeCommand(
            evidenceId: "801",
            request: BusinessRecordEvidenceRevokeRequest(
                accountBookId: "11", expectedVersion: 1, reason: "原件对应的账期错误"
            ),
            operationID: operationID
        )
        let response = try await makeAPI().revoke(command)
        XCTAssertEqual(response.evidence.status, .revoked)
        XCTAssertFalse(response.contentDeleted)
        XCTAssertTrue(response.contentImmutable)
        XCTAssertEqual(capturedRequest().value(forHTTPHeaderField: "Idempotency-Key"), "ios-evidence-revoke-00000000-0000-0000-0000-000000000131")
        let data = try XCTUnwrap(EvidenceURLProtocol.capturedBodies.last ?? nil)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["accountBookId"] as? String, "11")
        XCTAssertEqual(body["expectedVersion"] as? Int, 1)
        XCTAssertEqual(body["reason"] as? String, "原件对应的账期错误")
    }

    func testEvidenceConflictForbiddenAndIntegrityErrorsRemainRecognizable() async throws {
        let api = makeAPI()
        let command = BusinessRecordEvidenceRevokeCommand(
            evidenceId: "801",
            request: BusinessRecordEvidenceRevokeRequest(accountBookId: "11", expectedVersion: 1, reason: "并发状态测试")
        )
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-version-conflict-v0.13.0", statusCode: 409)
        await assertServerError({ try await api.revoke(command) }, status: 409, code: "EVIDENCE_VERSION_CONFLICT")
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-forbidden-v0.13.0", statusCode: 403)
        await assertServerError({ try await api.revoke(command) }, status: 403, code: "EVIDENCE_WRITE_FORBIDDEN")
        EvidenceURLProtocol.handler = fixtureResponse(named: "business-record-evidence-integrity-mismatch-v0.13.0", statusCode: 409)
        let evidence = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0").items[0]
        await assertServerError({ try await api.content(evidence) }, status: 409, code: "EVIDENCE_INTEGRITY_MISMATCH")
    }

    private func assertServerError<T>(
        _ operation: () async throws -> T,
        status: Int,
        code: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("expected server error", file: file, line: line)
        } catch APIError.server(let actualStatus, let actualCode, _) {
            XCTAssertEqual(actualStatus, status, file: file, line: line)
            XCTAssertEqual(actualCode, code, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    private func makeAPI() -> LiveBusinessRecordEvidenceAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EvidenceURLProtocol.self]
        return LiveBusinessRecordEvidenceAPI(transport: HTTPTransport(
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
        guard let request = EvidenceURLProtocol.capturedRequests.last else {
            XCTFail("expected a captured request", file: file, line: line)
            return URLRequest(url: URL(string: "https://invalid.local")!)
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(type, from: fixture(named: name))
    }

    private func fixture(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}

private final class EvidenceURLProtocol: URLProtocol {
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
