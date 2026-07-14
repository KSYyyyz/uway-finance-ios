import XCTest
@testable import UwayFinance

final class MoneyAmountTests: XCTestCase {
    func testLegacyJSONNumberDecodesToExactCents() throws {
        let amount = try JSONDecoder().decode(MoneyAmount.self, from: Data("1234.56".utf8))

        XCTAssertEqual(amount.cents, 123_456)
        XCTAssertEqual(amount.decimalValue, try XCTUnwrap(Decimal(string: "1234.56")))
    }

    func testDecimalStringIsAcceptedForFutureLosslessContracts() throws {
        let amount = try JSONDecoder().decode(MoneyAmount.self, from: Data("\"0.30\"".utf8))

        XCTAssertEqual(amount.cents, 30)
    }

    func testV2DecimalStringRejectsSubCentPrecision() {
        XCTAssertThrowsError(try MoneyAmount(decimalString: "0.301"))
    }

    func testLegacyStateRoundTripKeepsAmountKeyAndExactCents() throws {
        let original = makeMoneyTestRecord(amount: 0.1 + 0.2)
        let encoded = try JSONEncoder().encode(original)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let decoded = try JSONDecoder().decode(BusinessRecord.self, from: encoded)

        XCTAssertNotNil(object["amount"])
        XCTAssertNil(object["_amount"])
        XCTAssertEqual(decoded.preciseAmount.cents, 30)
    }
}

private func makeMoneyTestRecord(amount: Double) -> BusinessRecord {
    BusinessRecord(
        id: "money-001",
        date: "2026-07-14",
        direction: .expense,
        amount: amount,
        category: "测试",
        counterparty: "测试供应商",
        project: "Uway",
        account: "公司银行",
        settlementStatus: .settled,
        invoiceStatus: .pending,
        financeStatus: .draft,
        contractStatus: .notRequired,
        description: "金额边界测试"
    )
}
