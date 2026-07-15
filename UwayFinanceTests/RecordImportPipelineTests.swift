import XCTest
@testable import UwayFinance

final class RecordImportPipelineTests: XCTestCase {
    func testCSVRowsPreserveQuotedCommaAndEscapedQuote() {
        XCTAssertEqual(
            RecordCSVParser.parseRows("a,b\r\n\"c,d\",\"x\"\"y\""),
            [["a", "b"], ["c,d", "x\"y"]]
        )
    }

    func testParserSeparatesCompanyPersonalAndUnknownRows() throws {
        let csv = """
        日期,收支方向,金额,交易对方,事项说明,是否公司账目
        2026-07-14,支出,2480,示例云服务商,云服务器费用,是
        2026-07-14,支出,88,便利店,家庭采购,个人
        2026-07-14,收入,12000,示例客户,项目回款,
        """

        let preview = try RecordCSVParser.parse(data: Data(csv.utf8), fileName: "records.csv", existing: [])

        XCTAssertEqual(preview.totalRows, 3)
        XCTAssertEqual(preview.eligible.count, 1)
        XCTAssertEqual(preview.pendingOwnership.count, 1)
        XCTAssertEqual(preview.excludedCount, 1)
        XCTAssertEqual(preview.eligible.first?.record.counterparty, "示例云服务商")
    }

    func testParserSkipsExistingRecordSignature() throws {
        let existing = makeImportedRecord()
        let csv = """
        日期,收支方向,金额,交易对方,事项说明,是否公司账目
        2026-07-14,支出,2480,示例云服务商,云服务器费用,是
        """

        let preview = try RecordCSVParser.parse(data: Data(csv.utf8), fileName: "records.csv", existing: [existing])

        XCTAssertTrue(preview.eligible.isEmpty)
        XCTAssertEqual(preview.duplicateCount, 1)
    }

    func testRequestFactoryBuildsServerOwnedAnalysisBoundary() throws {
        let preview = try RecordCSVParser.parse(
            data: Data("日期,收支方向,金额,交易对方,事项说明,是否公司账目\n2026-07-14,支出,2480,示例云服务商,云服务器费用,是".utf8),
            fileName: "records.csv",
            existing: []
        )
        let candidate = try XCTUnwrap(preview.eligible.first)
        let request = ImportAnalysisRequestFactory.make(
            candidate: candidate,
            accountBookId: "11",
            batchId: "batch-test",
            fileName: "records.csv",
            fileFingerprint: ImportAnalysisRequestFactory.fileFingerprint(Data("file".utf8)),
            existingFingerprints: ["sha256:existing"]
        )

        XCTAssertEqual(request.batchId, "batch-test")
        XCTAssertEqual(request.accountBookId, "11")
        XCTAssertEqual(request.rowId, "row-2")
        XCTAssertEqual(request.source.rowPath, "row[2]")
        XCTAssertEqual(request.record.amount, 2480)
        XCTAssertTrue(request.companyOwnership.verified)
        XCTAssertTrue(request.sourceFingerprint.hasPrefix("sha256:"))
        XCTAssertTrue(request.companyOwnership.fingerprint.hasPrefix("sha256:"))
        XCTAssertEqual(request.existingFingerprints, ["sha256:existing"])
    }

    func testParserEnforcesBackendRateLimitBatchSize() {
        let rows = (1...31).map { "2026-07-14,支出,\($0),供应商\($0),费用,是" }.joined(separator: "\n")
        let csv = "日期,收支方向,金额,交易对方,事项说明,是否公司账目\n\(rows)"

        XCTAssertThrowsError(try RecordCSVParser.parse(data: Data(csv.utf8), fileName: "large.csv", existing: [])) { error in
            XCTAssertEqual(error as? RecordImportPipelineError, .tooManyRows(31))
        }
    }
}

private func makeImportedRecord() -> BusinessRecord {
    BusinessRecord(
        id: "existing-001",
        date: "2026-07-14",
        direction: .expense,
        amount: 2480,
        category: "",
        counterparty: "示例云服务商",
        project: "",
        account: "",
        settlementStatus: .unsettled,
        invoiceStatus: .pending,
        financeStatus: .draft,
        contractStatus: .missing,
        description: "云服务器费用"
    )
}
