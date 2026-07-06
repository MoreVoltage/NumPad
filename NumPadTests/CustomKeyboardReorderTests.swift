import XCTest
@testable import NumPad

final class CustomKeyboardReorderTests: XCTestCase {
    func testMovesElementForward() {
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "b", "c"], from: 0, to: 2), ["b", "c", "a"])
    }

    func testMovesElementBackward() {
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "b", "c"], from: 2, to: 0), ["c", "a", "b"])
    }

    func testMovesElementByOneStep() {
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "b", "c"], from: 0, to: 1), ["b", "a", "c"])
    }

    func testDestinationEqualToCountAppendsAtEnd() {
        // UIKit reports `destination == count` when a drop resolves past the last cell.
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "b", "c"], from: 0, to: 3), ["b", "c", "a"])
    }

    func testNoopWhenSourceEqualsDestination() {
        let items = ["a", "b", "c"]
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: 1, to: 1), items)
    }

    func testNoopOnEmptyArray() {
        let items: [String] = []
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: 0, to: 0), items)
    }

    func testNoopOnSingleItemArray() {
        let items = ["only"]
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: 0, to: 0), items)
    }

    func testNoopWhenSourceNegative() {
        let items = ["a", "b", "c"]
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: -1, to: 1), items)
    }

    func testNoopWhenSourceOutOfBounds() {
        let items = ["a", "b", "c"]
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: 5, to: 1), items)
    }

    func testNoopWhenDestinationNegative() {
        let items = ["a", "b", "c"]
        XCTAssertEqual(CustomKeyboardReorder.moved(items, from: 0, to: -1), items)
    }

    func testHandlesEmptyStringPlaceholders() {
        // Sections are padded to capacity with "" before reordering — a drag involving an empty
        // "+" placeholder must reorder like any other slot.
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "", ""], from: 0, to: 2), ["", "", "a"])
    }

    func testWildlyOutOfRangeDestinationClampsToEndInsteadOfCrashing() {
        XCTAssertEqual(CustomKeyboardReorder.moved(["a", "b", "c"], from: 0, to: 999), ["b", "c", "a"])
    }
}
