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

/// The Custom Keyboard editor's drag-reorder UI (`CustomKeyboardSectionReorderView`) has two
/// independent kill switches: the local `FeatureFlags.customKeyboardDragReorderEnabled` escape
/// hatch (TestFlight/DEBUG-toggleable, default ON) and a Remote Config value (default true,
/// production-revertible without an app release). `FeatureFlags.dragReorderActive` ANDs them so
/// either one turning off reverts the editor to the legacy static tap-to-edit rows.
final class CustomKeyboardDragReorderGateTests: XCTestCase {
    func testActiveOnlyWhenBothRemoteConfigAndLocalFlagAreEnabled() {
        XCTAssertTrue(FeatureFlags.dragReorderActive(remoteConfigEnabled: true, localFlagEnabled: true))
    }

    func testRemoteConfigKillSwitchOverridesLocalFlagEnabled() {
        XCTAssertFalse(FeatureFlags.dragReorderActive(remoteConfigEnabled: false, localFlagEnabled: true))
    }

    func testLocalFlagOffStaysOffEvenWhenRemoteConfigEnabled() {
        XCTAssertFalse(FeatureFlags.dragReorderActive(remoteConfigEnabled: true, localFlagEnabled: false))
    }

    func testBothDisabledStaysOff() {
        XCTAssertFalse(FeatureFlags.dragReorderActive(remoteConfigEnabled: false, localFlagEnabled: false))
    }
}
