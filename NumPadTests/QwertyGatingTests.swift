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
