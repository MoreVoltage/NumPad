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

    // MARK: the QWERTY page gate must NOT include the local surfacing flag

    func testQwertyPageGateMatchesTheStandaloneExtension() {
        // Owner-reported regression (2026-07-09): after the single-extension merge the page
        // gate required the local fullKeyboardEnabled flag (default OFF), making the QWERTY
        // page unreachable on devices that could previously use the standalone keyboard. The
        // page gate is the standalone extension's exact rule — remote kill switch + Pro
        // entitlement; the local flag only ever gated app-side surfacing (the Home row).
        XCTAssertTrue(FeatureFlags.qwertyPageAvailable(remoteEnabled: true, entitled: true))
        XCTAssertFalse(FeatureFlags.qwertyPageAvailable(remoteEnabled: false, entitled: true),
                       "the Remote Config kill switch must win server-side")
        XCTAssertFalse(FeatureFlags.qwertyPageAvailable(remoteEnabled: true, entitled: false))
        XCTAssertFalse(FeatureFlags.qwertyPageAvailable(remoteEnabled: false, entitled: false))
    }

    // MARK: the numpad's dedicated globe key (Home-button devices only — the QWERTY page is
    // an in-keyboard page switch, so it never needs the globe; single-keyboard architecture,
    // owner decision 2026-07-09)

    func testNumpadDedicatedSwitchKeyRule() {
        // Home-button devices draw no system globe — the keyboard must offer its own.
        XCTAssertTrue(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: true, repurposeNextKey: true))
        // Face ID devices: the system accessory globe below the keyboard covers switching.
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: false, repurposeNextKey: true))
        // Repurpose off: the pack-switch key itself already IS the system globe — never
        // render two of them.
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: true, repurposeNextKey: false))
        XCTAssertFalse(Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: false, repurposeNextKey: false))
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
