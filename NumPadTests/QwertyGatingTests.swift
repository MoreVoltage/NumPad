import XCTest
@testable import NumPad

final class QwertyGatingTests: XCTestCase {

    // MARK: NumPad Type is Pro-gated, no new SKU (plan §5)

    func testFullKeyboardEntitlement() {
        XCTAssertTrue(Monetization.fullKeyboardEntitled(paywallEnabled: false, proEntitled: false),
                      "paywall off unlocks everything, matching every other gate")
        XCTAssertTrue(Monetization.fullKeyboardEntitled(paywallEnabled: true, proEntitled: true))
        XCTAssertFalse(Monetization.fullKeyboardEntitled(paywallEnabled: true, proEntitled: false))
    }

    // MARK: kill-switch pair (plan §4 — mirrors the drag-reorder/key-press pattern)

    func testFullKeyboardActiveRequiresBothSwitches() {
        XCTAssertTrue(FeatureFlags.fullKeyboardActive(remoteEnabled: true, localEnabled: true))
        XCTAssertFalse(FeatureFlags.fullKeyboardActive(remoteEnabled: false, localEnabled: true),
                       "the Remote Config kill switch must win server-side")
        XCTAssertFalse(FeatureFlags.fullKeyboardActive(remoteEnabled: true, localEnabled: false))
        XCTAssertFalse(FeatureFlags.fullKeyboardActive(remoteEnabled: false, localEnabled: false))
    }
}
