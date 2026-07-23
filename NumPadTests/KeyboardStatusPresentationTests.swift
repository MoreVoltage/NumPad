//
//  KeyboardStatusPresentationTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardStatusPresentationTests: XCTestCase {
    func test_disabledHasNoOnDetail() {
        XCTAssertNil(KeyboardStatusPresentation.detail(isEnabled: false))
    }

    func test_enabledHasOnDetail() {
        XCTAssertNotNil(KeyboardStatusPresentation.detail(isEnabled: true))
    }

    func test_demoClearanceIncludesFieldAndBothMargins() {
        XCTAssertEqual(HomeDemoLayout.contentInset(fieldHeight: 44, verticalMargin: 16), 76)
    }
}
