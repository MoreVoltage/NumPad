import XCTest
@testable import NumPad

final class QwertyCursorAccumulatorTests: XCTestCase {
    func test_deadBandAndSteps() {
        var acc = QwertyCursorAccumulator()
        XCTAssertEqual(acc.consume(translation: 2), 0)
        XCTAssertEqual(acc.consume(translation: 20), 1)
        // After one positive step, reverse motion should produce a negative step once
        // the accumulated carry crosses a full step width.
        let steps = acc.consume(translation: -24)
        XCTAssertEqual(steps, -1)
        XCTAssertEqual(acc.consume(translation: -12), -1)
    }

    func testNormalSpaceTapInsertsSpace() {
        var interaction = QwertySpaceCursorInteraction()

        interaction.begin(at: 10)

        XCTAssertEqual(interaction.state, .pressing)
        XCTAssertEqual(interaction.end(), .insertSpace)
        XCTAssertEqual(interaction.state, .idle)
    }

    func testQuickSwipePreservesSpaceTapBehavior() {
        var interaction = QwertySpaceCursorInteraction()
        interaction.begin(at: 10)

        XCTAssertEqual(interaction.move(translation: 24, at: 10.2), 0)
        XCTAssertEqual(interaction.state, .pressing)
        XCTAssertEqual(interaction.end(), .insertSpace)
    }

    func testHoldThenDragTracksCursor() {
        var interaction = QwertySpaceCursorInteraction()
        interaction.begin(at: 10)

        XCTAssertEqual(interaction.move(translation: 24, at: 10.35), 2)
        XCTAssertEqual(interaction.state, .tracking)
        XCTAssertEqual(interaction.end(), .cursorMoved)
        XCTAssertEqual(interaction.state, .idle)
    }

    func testCancellationRestoresIdleWithoutInsertion() {
        var interaction = QwertySpaceCursorInteraction()
        interaction.begin(at: 10)
        XCTAssertTrue(interaction.activateTracking(at: 10.35))

        interaction.cancel()

        XCTAssertEqual(interaction.state, .idle)
    }
}
