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

    // MARK: NumPad Type enablement detection (the wizard's "On"/"Off" state)

    func testTypeKeyboardEnablementDetection() {
        XCTAssertTrue(Keyboard.isTypeKeyboardEnabled(in: ["com.morevoltage.NumPad.KeyboardType"]))
        XCTAssertTrue(Keyboard.isTypeKeyboardEnabled(in: ["en_US@sw=QWERTY",
                                                          "com.morevoltage.NumPad.KeyboardType"]))
        XCTAssertFalse(Keyboard.isTypeKeyboardEnabled(in: ["com.morevoltage.NumPad.Keyboard"]),
                       "the numpad keyboard alone must not read as NumPad Type")
        XCTAssertFalse(Keyboard.isTypeKeyboardEnabled(in: []))
        XCTAssertFalse(Keyboard.isTypeKeyboardEnabled(in: nil))
    }

    // MARK: the numpad must always offer a way over to NumPad Type

    func testNumpadDedicatedSwitchKeyRule() {
        // Home-button devices draw no system globe — unchanged pre-existing behavior.
        XCTAssertTrue(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: true, repurposeNextKey: true, typeKeyboardEnabled: false))
        // Face ID devices used to drop the globe entirely while the pack-switch key cycles
        // packs, leaving no in-keyboard button to reach NumPad Type. Sibling enabled must
        // bring the dedicated globe back on every device.
        XCTAssertTrue(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: false, repurposeNextKey: true, typeKeyboardEnabled: true))
        // No sibling on a modern device: layout stays untouched for existing users (the
        // system accessory globe below the keyboard covers switching).
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: false, repurposeNextKey: true, typeKeyboardEnabled: false))
        // Repurpose off: the pack-switch key itself already IS the system globe — never
        // render two of them.
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: true, repurposeNextKey: false, typeKeyboardEnabled: true))
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: false, repurposeNextKey: false, typeKeyboardEnabled: true))
    }

    // MARK: nil-writes through @UserDefault must remove the key, never crash

    func testOptionalUserDefaultAcceptsNil() {
        // Writing nil used to pass `<null>` into UserDefaults — a non-property-list object
        // that crashes the extension (hit live by the pack-switch cycling back to the number
        // row). The wrapper must remove the key instead.
        let previous = UserPrefs.qwertyTopStripPackRaw
        defer { UserPrefs.qwertyTopStripPackRaw = previous }

        UserPrefs.qwertyTopStripPackRaw = KeyboardType.grammar.rawValue
        XCTAssertEqual(UserPrefs.qwertyTopStripPack, .grammar)
        UserPrefs.qwertyTopStripPack = nil
        XCTAssertNil(UserPrefs.qwertyTopStripPackRaw)
        XCTAssertNil(UserPrefs.qwertyTopStripPack, "nil round-trips as 'the number row'")
    }
}
