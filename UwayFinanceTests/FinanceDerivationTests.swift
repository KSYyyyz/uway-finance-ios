import XCTest
@testable import UwayFinance

final class FinanceDerivationTests: XCTestCase {
    func testLedgerGroupsByMonthAndDay() {
        let records = [fixture(id: "2", date: "2026-06-30"), fixture(id: "1", date: "2026-07-13")]
        let groups = records.ledgerGroups
        XCTAssertEqual(groups.map(\.month), ["2026-07", "2026-06"])
        XCTAssertEqual(groups[0].days[0].date, "2026-07-13")
    }

    func testBusinessDateDescendingPreservesSourceOrderWithinSameDay() {
        let records = [
            fixture(id: "same-day-second", date: "2026-07-20"),
            fixture(id: "older", date: "2026-07-19"),
            fixture(id: "newest", date: "2026-07-21"),
            fixture(id: "same-day-first-by-id", date: "2026-07-20"),
        ]

        XCTAssertEqual(
            records.businessDateDescendingStable.map(\.id),
            ["newest", "same-day-second", "same-day-first-by-id", "older"]
        )
    }

    func testLedgerGroupsUseTheSameStableBusinessDateOrder() {
        let records = [
            fixture(id: "z", date: "2026-07-20"),
            fixture(id: "older", date: "2026-06-30"),
            fixture(id: "a", date: "2026-07-20"),
            fixture(id: "newest", date: "2026-07-21"),
        ]

        let groups = records.ledgerGroups

        XCTAssertEqual(groups.map(\.month), ["2026-07", "2026-06"])
        XCTAssertEqual(groups[0].days.map(\.date), ["2026-07-21", "2026-07-20"])
        XCTAssertEqual(groups[0].days[1].records.map(\.id), ["z", "a"])
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
