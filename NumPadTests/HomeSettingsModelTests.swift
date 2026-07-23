//
//  HomeSettingsModelTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class HomeSettingsModelTests: XCTestCase {
    func test_storeIsNotTypingBehaviorDestination() {
        let sections = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: false)
        let typing = sections.first { $0.id == .typingBehavior }
        XCTAssertTrue(typing?.rows.contains(.typingBehavior) == true)
        XCTAssertFalse(typing?.rows.contains(.pro) == true)
    }

    func test_qwertyRowObeysRolloutVisibility() {
        let hidden = HomeSettingsModel.sections(fullKeyboardVisible: false, isPad: false)
        XCTAssertFalse(hidden.flatMap(\.rows).contains(.qwerty))
        let visible = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: false)
        XCTAssertTrue(visible.flatMap(\.rows).contains(.qwerty))
    }

    func test_sectionsAreDeterministicAndExcludeCommerceFromTyping() {
        let a = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: true)
        let b = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: true)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.map(\.id), [.dashboard, .keyboard, .typingBehavior, .content, .account, .help])
    }
}
