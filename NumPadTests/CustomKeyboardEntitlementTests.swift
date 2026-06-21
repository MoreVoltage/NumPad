import XCTest
@testable import NumPad

final class CustomKeyboardEntitlementTests: XCTestCase {
    func testProEntitledUnlocks() {
        XCTAssertTrue(Monetization.customKeyboardEntitled(proEntitled: true, standalonePurchased: false))
    }
    func testStandalonePurchaseUnlocks() {
        XCTAssertTrue(Monetization.customKeyboardEntitled(proEntitled: false, standalonePurchased: true))
    }
    func testBothUnlocks() {
        XCTAssertTrue(Monetization.customKeyboardEntitled(proEntitled: true, standalonePurchased: true))
    }
    func testNeitherStaysLocked() {
        XCTAssertFalse(Monetization.customKeyboardEntitled(proEntitled: false, standalonePurchased: false))
    }
}
