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
}
