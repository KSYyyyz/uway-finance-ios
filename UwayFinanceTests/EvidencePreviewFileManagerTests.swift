import XCTest
@testable import UwayFinance

final class EvidencePreviewFileManagerTests: XCTestCase {
    override func tearDown() {
        EvidencePreviewFileManager.clearAll()
        super.tearDown()
    }

    func testSessionCleanupRemovesOnlyUwayEvidenceTemporaryFiles() throws {
        EvidencePreviewFileManager.clearAll()
        let content = BusinessRecordEvidenceContent(
            evidenceId: "evidence-1",
            fileName: "invoice.pdf",
            mediaType: "application/pdf",
            data: Data("private evidence".utf8),
            eTag: nil,
            digest: String(repeating: "a", count: 64)
        )
        let managedURL = try EvidencePreviewFileManager.write(content)
        let unrelatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unrelated-\(UUID().uuidString).tmp")
        try Data("keep".utf8).write(to: unrelatedURL)
        defer { try? FileManager.default.removeItem(at: unrelatedURL) }

        EvidencePreviewFileManager.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
    }
}
