import XCTest

final class NumPadTests: XCTestCase {
    func testTestBundleLoads() {
        XCTAssertNotNil(Bundle(for: Self.self).bundleIdentifier)
    }
}
