import XCTest
@testable import UwayFinance

final class AppConfigurationTests: XCTestCase {
    func testExplicitHTTPSConfiguration() {
        let configuration = AppConfiguration(rawValue: "https://115.29.239.217")
        XCTAssertEqual(configuration.apiBaseURL.scheme, "https")
        XCTAssertEqual(configuration.apiBaseURL.host, "115.29.239.217")
    }

    func testBuiltAppBundleContainsExpandedHTTPSConfiguration() throws {
        let rawValue = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UWAY_API_BASE_URL") as? String)
        let configuration = AppConfiguration(rawValue: rawValue)
        XCTAssertEqual(configuration.apiBaseURL.scheme, "https")
        XCTAssertNotNil(configuration.apiBaseURL.host)
    }
}
