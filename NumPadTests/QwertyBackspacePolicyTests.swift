import XCTest
@testable import NumPad

final class QwertyBackspacePolicyTests: XCTestCase {
    func test_timing() {
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 0.1, wordDeleteEnabled: true), .wait)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 0.4, wordDeleteEnabled: false), .deleteCharacter)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 2.6, wordDeleteEnabled: true), .deleteWord)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 2.6, wordDeleteEnabled: false), .deleteCharacter)
    }
}

