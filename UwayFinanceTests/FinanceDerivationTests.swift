import XCTest
@testable import UwayFinance

final class FinanceDerivationTests: XCTestCase {
    func testLedgerGroupsByMonthAndDay() {
        let records = [fixture(id: "2", date: "2026-06-30"), fixture(id: "1", date: "2026-07-13")]
        let groups = records.ledgerGroups
        XCTAssertEqual(groups.map(\.month), ["2026-07", "2026-06"])
        XCTAssertEqual(groups[0].days[0].date, "2026-07-13")
    }

    func testPendingItemsFollowRecordState() {
        var record = fixture(id: "1", date: "2026-07-13")
        record.settlementStatus = .unsettled
        record.invoiceStatus = .pending
        record.financeStatus = .draft
        XCTAssertEqual([record].pendingItems.count, 3)
    }

    private func fixture(id: String, date: String) -> BusinessRecord {
        BusinessRecord(
            id: id, date: date, direction: .expense, amount: 100,
            category: "测试", counterparty: "测试公司", project: "Uway", account: "银行",
            settlementStatus: .settled, invoiceStatus: .received, financeStatus: .booked,
            contractStatus: .notRequired, description: "测试事项"
        )
    }
}

