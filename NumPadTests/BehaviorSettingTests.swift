//
//  BehaviorSettingTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class BehaviorSettingTests: XCTestCase {
    func test_behaviorCatalogHasNoDuplicateIDs() {
        XCTAssertEqual(
            Set(BehaviorSetting.allCases.map(\.rawValue)).count,
            BehaviorSetting.allCases.count
        )
    }
}
