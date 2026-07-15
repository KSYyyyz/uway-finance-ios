import XCTest
@testable import UwayFinance

@MainActor
final class BusinessRecordEvidenceStoreTests: XCTestCase {
    private let png = Data([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    ])

    func testRestoreResolvesAccountBookThenScopesListAndCoverage() async throws {
        let list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list)],
            coverages: [.success(coverage)]
        )
        let store = BusinessRecordEvidenceStore(api: api)

        await store.restore(recordExternalId: "R-EVIDENCE")

        XCTAssertEqual(store.accountBook?.id, "11")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.coverage.activeEvidenceCount, 1)
        let queries = await api.listQueries()
        XCTAssertEqual(queries, [BusinessRecordEvidenceListQuery(
            accountBookId: "11", recordExternalId: "R-EVIDENCE", includeRevoked: true
        )])
        let coverageBooks = await api.coverageAccountBooks()
        XCTAssertEqual(coverageBooks, ["11"])
    }

    func testUploadOfflineRetryRetainsFormFileAndSameLogicalCommand() async throws {
        let initial = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let uploaded = try decode(BusinessRecordEvidenceUploadResponse.self, "business-record-evidence-upload-v0.13.0")
        let after = BusinessRecordEvidenceListResponse(items: [uploaded.evidence] + initial.items)
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(initial), .success(after)],
            coverages: [.success(coverage), .success(coverage)],
            uploads: [.failure(.transport("offline")), .success(uploaded)]
        )
        let store = BusinessRecordEvidenceStore(api: api)
        await store.restore(recordExternalId: "R-EVIDENCE")
        store.selectFile(data: png, fileName: "新发票.png")
        store.updateUploadType(.invoice)
        store.updateUploadNote("本月发票")

        let firstUpload = await store.upload()
        XCTAssertFalse(firstUpload)
        XCTAssertEqual(store.selectedFile?.data, png)
        XCTAssertEqual(store.uploadNote, "本月发票")
        XCTAssertTrue(store.message?.contains("同一幂等请求") == true)
        let secondUpload = await store.upload()
        XCTAssertTrue(secondUpload)

        let commands = await api.uploadCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], commands[1])
        XCTAssertNil(store.selectedFile)
        XCTAssertEqual(store.uploadNote, "")
    }

    func testChangedUploadFormCreatesNewLogicalRequestAndOversizeStaysLocal() async throws {
        let list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list)],
            coverages: [.success(coverage)],
            uploads: [.failure(.transport("offline")), .failure(.transport("offline"))]
        )
        let store = BusinessRecordEvidenceStore(api: api)
        await store.restore(recordExternalId: "R-EVIDENCE")
        store.selectFile(data: png, fileName: "新发票.png")
        store.updateUploadNote("第一次说明")
        _ = await store.upload()
        store.updateUploadNote("修改后的说明")
        _ = await store.upload()
        let commands = await api.uploadCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertNotEqual(commands[0].idempotencyKey, commands[1].idempotencyKey)
        XCTAssertNotEqual(commands[0].request.note, commands[1].request.note)

        store.selectFile(data: Data(count: 10_000_001), fileName: "过大附件.pdf")
        XCTAssertEqual(store.selectedFile?.fileName, "新发票.png")
        XCTAssertTrue(store.message?.contains("不能超过 10 MB") == true)
    }

    func testRevoke409PreservesReasonFilterAndAccountScopeWhileRefreshing() async throws {
        let list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list), .success(list)],
            coverages: [.success(coverage), .success(coverage)],
            revokes: [.failure(.server(
                status: 409,
                code: "EVIDENCE_VERSION_CONFLICT",
                message: "版本变化"
            ))]
        )
        let store = BusinessRecordEvidenceStore(api: api)
        await store.restore(recordExternalId: "R-EVIDENCE")
        let evidence = try XCTUnwrap(store.items.first)
        store.setRevokeReason("原件对应的账期错误", evidenceId: evidence.id)

        let revoked = await store.revoke(evidence)
        XCTAssertFalse(revoked)

        XCTAssertTrue(store.includeRevoked)
        XCTAssertEqual(store.accountBook?.id, "11")
        XCTAssertEqual(store.recordExternalId, "R-EVIDENCE")
        XCTAssertEqual(store.revokeDrafts[evidence.id], "原件对应的账期错误")
        XCTAssertTrue(store.message?.contains("当前筛选已保留") == true)
        let refreshedQueries = await api.listQueries()
        XCTAssertEqual(refreshedQueries.map(\.accountBookId), ["11", "11"])
    }

    func testNetworkRevokeRetryReusesSameKeyAndBody() async throws {
        let list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let revoked = try decode(BusinessRecordEvidenceRevokeResponse.self, "business-record-evidence-revoke-v0.13.0")
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list), .success(list)],
            coverages: [.success(coverage), .success(coverage)],
            revokes: [.failure(.transport("offline")), .success(revoked)]
        )
        let store = BusinessRecordEvidenceStore(api: api)
        await store.restore(recordExternalId: "R-EVIDENCE")
        let evidence = try XCTUnwrap(store.items.first)
        store.setRevokeReason("原件对应的账期错误", evidenceId: evidence.id)

        let firstRevoke = await store.revoke(evidence)
        let secondRevoke = await store.revoke(evidence)
        XCTAssertFalse(firstRevoke)
        XCTAssertTrue(secondRevoke)
        let commands = await api.revokeCommands()
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], commands[1])
    }

    func testSwitchingAccountBookOrRecordClearsFilesDraftsAndOldCache() async throws {
        let first = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        let coverage = try decode(BusinessRecordEvidenceCoverageResponse.self, "business-record-evidence-coverage-v0.13.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11")), .success(context(bookID: "22"))],
            lists: [.success(first), .success(BusinessRecordEvidenceListResponse(items: []))],
            coverages: [.success(coverage), .success(BusinessRecordEvidenceCoverageResponse(records: [:]))]
        )
        let store = BusinessRecordEvidenceStore(api: api)
        await store.restore(recordExternalId: "R-EVIDENCE")
        store.selectFile(data: png, fileName: "不能跨账套.png")
        store.updateUploadNote("不能跨账套保留")
        let evidence = try XCTUnwrap(store.items.first)
        store.setRevokeReason("不能跨账套保留", evidenceId: evidence.id)

        await store.restore(recordExternalId: "R-OTHER", requestedAccountBookId: "22")

        XCTAssertEqual(store.accountBook?.id, "22")
        XCTAssertEqual(store.recordExternalId, "R-OTHER")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.selectedFile)
        XCTAssertEqual(store.uploadNote, "")
        XCTAssertTrue(store.revokeDrafts.isEmpty)
        let scopedQueries = await api.listQueries()
        XCTAssertEqual(scopedQueries.map(\.accountBookId), ["11", "22"])
    }

    func testMismatchedRecordResponseFailsClosedWithoutDisplayingEvidence() async throws {
        var list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.13.0")
        list = BusinessRecordEvidenceListResponse(items: list.items.map {
            BusinessRecordEvidence(
                id: $0.id, recordExternalId: "R-OTHER", evidenceType: $0.evidenceType,
                fileName: $0.fileName, mediaType: $0.mediaType, byteSize: $0.byteSize,
                sha256: $0.sha256, note: $0.note, status: $0.status, version: $0.version,
                createdAt: $0.createdAt, revokedAt: $0.revokedAt, revokeReason: $0.revokeReason,
                uploadedByUserId: $0.uploadedByUserId, revokedByUserId: $0.revokedByUserId,
                contentUrl: $0.contentUrl
            )
        })
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list)],
            coverages: [.success(BusinessRecordEvidenceCoverageResponse(records: [:]))]
        )
        let store = BusinessRecordEvidenceStore(api: api)

        await store.restore(recordExternalId: "R-EVIDENCE")

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.message?.contains("其他事项") == true)
    }

    func testCoverageFailureKeepsHistoryButNeverReportsZeroAsAvailable() async throws {
        let list = try decode(BusinessRecordEvidenceListResponse.self, "business-record-evidence-list-v0.14.0")
        let api = BusinessRecordEvidenceAPISpy(
            contexts: [.success(context(bookID: "11"))],
            lists: [.success(list)],
            coverages: [.failure(.transport("offline"))]
        )
        let store = BusinessRecordEvidenceStore(api: api)

        await store.restore(recordExternalId: "R-EVIDENCE")

        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.coverageLoadState, .failed)
        XCTAssertNil(store.coverage.requirementState)
        XCTAssertTrue(store.message?.contains("不能判断材料是否齐全") == true)
    }

    private func context(bookID: String) -> FinanceContextResponse {
        let book = FinanceAccountBookAccess(
            id: bookID,
            name: "账套 \(bookID)",
            baseCurrency: "CNY",
            organization: FinanceResourceOrganization(id: bookID, name: "组织 \(bookID)"),
            role: "finance",
            permissions: FinanceResourcePermissions(readBusinessRecords: true, writeBusinessRecords: true)
        )
        return FinanceContextResponse(selectedAccountBook: book, accountBooks: [book])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

private actor BusinessRecordEvidenceAPISpy: BusinessRecordEvidenceAPI {
    private var contexts: [Result<FinanceContextResponse, APIError>]
    private var lists: [Result<BusinessRecordEvidenceListResponse, APIError>]
    private var coverages: [Result<BusinessRecordEvidenceCoverageResponse, APIError>]
    private var uploads: [Result<BusinessRecordEvidenceUploadResponse, APIError>]
    private var revokes: [Result<BusinessRecordEvidenceRevokeResponse, APIError>]
    private var capturedListQueries: [BusinessRecordEvidenceListQuery] = []
    private var capturedCoverageAccountBooks: [String] = []
    private var capturedUploadCommands: [BusinessRecordEvidenceUploadCommand] = []
    private var capturedRevokeCommands: [BusinessRecordEvidenceRevokeCommand] = []

    init(
        contexts: [Result<FinanceContextResponse, APIError>],
        lists: [Result<BusinessRecordEvidenceListResponse, APIError>],
        coverages: [Result<BusinessRecordEvidenceCoverageResponse, APIError>],
        uploads: [Result<BusinessRecordEvidenceUploadResponse, APIError>] = [],
        revokes: [Result<BusinessRecordEvidenceRevokeResponse, APIError>] = []
    ) {
        self.contexts = contexts
        self.lists = lists
        self.coverages = coverages
        self.uploads = uploads
        self.revokes = revokes
    }

    func listQueries() -> [BusinessRecordEvidenceListQuery] { capturedListQueries }
    func coverageAccountBooks() -> [String] { capturedCoverageAccountBooks }
    func uploadCommands() -> [BusinessRecordEvidenceUploadCommand] { capturedUploadCommands }
    func revokeCommands() -> [BusinessRecordEvidenceRevokeCommand] { capturedRevokeCommands }

    func context(accountBookId: String?) async throws -> FinanceContextResponse {
        guard !contexts.isEmpty else { throw APIError.invalidResponse }
        return try contexts.removeFirst().get()
    }

    func list(_ query: BusinessRecordEvidenceListQuery) async throws -> BusinessRecordEvidenceListResponse {
        capturedListQueries.append(query)
        guard !lists.isEmpty else { throw APIError.invalidResponse }
        return try lists.removeFirst().get()
    }

    func coverage(accountBookId: String) async throws -> BusinessRecordEvidenceCoverageResponse {
        capturedCoverageAccountBooks.append(accountBookId)
        guard !coverages.isEmpty else { throw APIError.invalidResponse }
        return try coverages.removeFirst().get()
    }

    func upload(_ command: BusinessRecordEvidenceUploadCommand) async throws -> BusinessRecordEvidenceUploadResponse {
        capturedUploadCommands.append(command)
        guard !uploads.isEmpty else { throw APIError.invalidResponse }
        return try uploads.removeFirst().get()
    }

    func content(_ evidence: BusinessRecordEvidence) async throws -> BusinessRecordEvidenceContent {
        throw APIError.invalidResponse
    }

    func revoke(_ command: BusinessRecordEvidenceRevokeCommand) async throws -> BusinessRecordEvidenceRevokeResponse {
        capturedRevokeCommands.append(command)
        guard !revokes.isEmpty else { throw APIError.invalidResponse }
        return try revokes.removeFirst().get()
    }
}
