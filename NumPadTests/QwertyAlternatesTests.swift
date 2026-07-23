import XCTest
@testable import NumPad

final class QwertyAlternatesTests: XCTestCase {
    func test_pinnedAlternates() {
        XCTAssertFalse(QwertyAlternates.values(for: "a").isEmpty)
        XCTAssertFalse(QwertyAlternates.values(for: "e").isEmpty)
        XCTAssertTrue(QwertyAlternates.values(for: "$").contains("€"))
        XCTAssertTrue(QwertyAlternates.values(for: "z").isEmpty)
    }

    func testUppercaseKeyProducesUppercaseAlternates() {
        let values = QwertyAlternates.values(for: "E", uppercase: true)

        XCTAssertTrue(values.contains("É"))
        XCTAssertFalse(values.contains("é"))
    }

    func testFingerTrackingHighlightsAndReleaseReturnsSelection() {
        var selection = QwertyAlternateSelection(values: ["à", "á", "â"], itemWidth: 40)

        XCTAssertEqual(selection.update(horizontalLocation: 5), "à")
        XCTAssertEqual(selection.update(horizontalLocation: 55), "á")
        XCTAssertEqual(selection.release(), "á")
        XCTAssertNil(selection.highlightedValue)
    }

    func testFingerTrackingClampsToEdgeAlternates() {
        var selection = QwertyAlternateSelection(values: ["à", "á", "â"], itemWidth: 40)

        XCTAssertEqual(selection.update(horizontalLocation: -100), "à")
        XCTAssertEqual(selection.update(horizontalLocation: 500), "â")
    }
}
