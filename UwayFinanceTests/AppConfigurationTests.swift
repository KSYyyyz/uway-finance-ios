import XCTest
@testable import UwayFinance

final class AppConfigurationTests: XCTestCase {
    func testExplicitHTTPSConfiguration() {
        let configuration = AppConfiguration(scheme: "https", host: "115.29.239.217")
        XCTAssertEqual(configuration.apiBaseURL.scheme, "https")
        XCTAssertEqual(configuration.apiBaseURL.host, "115.29.239.217")
    }

    func testBuiltAppBundleContainsExpandedHTTPSConfiguration() throws {
        let scheme = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UWAY_API_SCHEME") as? String)
        let host = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UWAY_API_HOST") as? String)
        let configuration = AppConfiguration(scheme: scheme, host: host)
        XCTAssertEqual(configuration.apiBaseURL.scheme, "https")
        XCTAssertNotNil(configuration.apiBaseURL.host)
    }
}
