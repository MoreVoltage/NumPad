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

    func testCalloutLayoutFitsEightAlternatesInsideNarrowKeyboard() {
        let layout = QwertyAlternateCalloutLayout.resolve(
            valueCount: 8,
            availableWidth: 320
        )

        XCTAssertLessThanOrEqual(layout.totalWidth, 316)
        XCTAssertEqual(layout.itemWidth * 8, layout.totalWidth, accuracy: 0.001)
        XCTAssertGreaterThan(layout.itemWidth, 0)
    }
}
