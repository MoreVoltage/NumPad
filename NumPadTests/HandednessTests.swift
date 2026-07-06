import XCTest
@testable import NumPad

final class HandednessTests: XCTestCase {
    func testToastMessageForLeftHandMode() {
        XCTAssertEqual(Handedness.left.toastMessage, "Keyboard is now set to left-hand mode.")
    }

    func testToastMessageForRightHandMode() {
        XCTAssertEqual(Handedness.right.toastMessage, "Keyboard is now set to right-hand mode.")
    }

    func testToastMessagesAreDistinctPerMode() {
        XCTAssertNotEqual(Handedness.left.toastMessage, Handedness.right.toastMessage)
    }
}
