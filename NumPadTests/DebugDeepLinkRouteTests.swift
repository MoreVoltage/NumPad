import XCTest
@testable import NumPad

#if DEBUG
final class DebugDeepLinkRouteTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: entitle

    func testEntitleProOn() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=1")), .entitlePro(true))
    }

    func testEntitleProOff() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=0")), .entitlePro(false))
    }

    func testEntitleMissingQueryReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/entitle")))
    }

    func testEntitleInvalidValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=yes")))
    }

    // MARK: preset

    func testPresetSmall() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=small")), .heightPreset(.small))
    }

    func testPresetRegular() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=regular")), .heightPreset(.regular))
    }

    func testPresetTall() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=tall")), .heightPreset(.tall))
    }

    func testPresetKiosk() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=kiosk")), .heightPreset(.kiosk))
    }

    func testPresetInvalidValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=huge")))
    }

    func testPresetMissingValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/preset")))
    }

    // MARK: screen routes

    func testHeightScreen() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/height")), .heightScreen)
    }

    func testCustomKeyboardEditor() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/editor")), .customKeyboardEditor)
    }

    func testTypingSurface() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/typing")), .typingSurface)
    }

    func testFeaturesGuide() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/guide")), .featuresGuide)
    }

    // MARK: rejection

    func testNonDebugHostReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://store-preview")))
    }

    func testUnknownDebugPathReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/unknown")))
    }
}
#endif
