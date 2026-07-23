import XCTest
@testable import NumPad

final class QwertyAlternatesTests: XCTestCase {
    func test_pinnedAlternates() {
        XCTAssertFalse(QwertyAlternates.values(for: "a").isEmpty)
        XCTAssertFalse(QwertyAlternates.values(for: "e").isEmpty)
        XCTAssertTrue(QwertyAlternates.values(for: "$").contains("€"))
        XCTAssertTrue(QwertyAlternates.values(for: "z").isEmpty)
    }
}

