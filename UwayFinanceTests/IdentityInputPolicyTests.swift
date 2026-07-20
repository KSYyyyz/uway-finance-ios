import XCTest
@testable import UwayFinance

final class IdentityInputPolicyTests: XCTestCase {
    func testUsernameNormalizationUsesNFKCAndLowercase() {
        XCTAssertEqual(IdentityInputPolicy.normalizedUsername(" Ｕway_用户 "), "uway_用户")
    }

    func testUsernameAcceptsFrozenChineseLatinDigitAndSeparatorGrammar() {
        for value in ["张三_01", "owner-2026", "A用户9"] {
            XCTAssertNil(IdentityInputPolicy.usernameIssue(value), value)
        }
    }

    func testUsernameRejectsEveryFrozenLocalReason() {
        XCTAssertEqual(IdentityInputPolicy.usernameIssue("ab")?.reason, "length")
        XCTAssertEqual(IdentityInputPolicy.usernameIssue("_owner")?.reason, "format")
        XCTAssertEqual(IdentityInputPolicy.usernameIssue("owner__name")?.reason, "format")
        XCTAssertEqual(IdentityInputPolicy.usernameIssue("123456")?.reason, "numeric_only")
        XCTAssertEqual(IdentityInputPolicy.usernameIssue("ADMIN")?.reason, "reserved")
    }

    func testAllReservedUsernamesFailAfterNormalization() {
        for value in IdentityInputPolicy.reservedUsernames {
            XCTAssertEqual(IdentityInputPolicy.usernameIssue(value.uppercased())?.reason, "reserved")
        }
    }

    func testEmailNormalizationAndValidation() {
        XCTAssertEqual(IdentityInputPolicy.normalizedEmail(" Owner@Example.COM "), "owner@example.com")
        XCTAssertTrue(IdentityInputPolicy.isValidEmail("owner@example.com"))
        XCTAssertFalse(IdentityInputPolicy.isValidEmail("owner@example"))
        XCTAssertFalse(IdentityInputPolicy.isValidEmail(".owner@example.com"))
    }

    func testPasswordAllowsAnyCompositionAtEightCharacters() {
        XCTAssertNil(IdentityInputPolicy.passwordIssue(
            "八个汉字密码安全值",
            username: "owner",
            phone: "+8613800138000",
            email: "owner@example.com"
        ))
    }

    func testPasswordRejectsLengthAndIdentityFragments() {
        XCTAssertEqual(IdentityInputPolicy.passwordIssue(
            "short",
            username: "owner",
            phone: "+8613800138000",
            email: "owner@example.com"
        ), "密码长度必须为 8–256 个字符")
        XCTAssertNotNil(IdentityInputPolicy.passwordIssue(
            "prefixOWNERsuffix",
            username: "owner",
            phone: "+8613800138000",
            email: "mailbox@example.com"
        ))
        XCTAssertNotNil(IdentityInputPolicy.passwordIssue(
            "safe00138000value",
            username: "owner",
            phone: "+8613800138000",
            email: "mailbox@example.com"
        ))
        XCTAssertNotNil(IdentityInputPolicy.passwordIssue(
            "safeMAILBOXvalue",
            username: "owner",
            phone: "+8613800138000",
            email: "mailbox@example.com"
        ))
    }
}
