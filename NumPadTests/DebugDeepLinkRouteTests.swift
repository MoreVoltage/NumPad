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
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/typing")), .typingSurface(scene: "plain"))
    }

    func testTypingSurfaceWithScene() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/typing?scene=hero")), .typingSurface(scene: "hero"))
    }

    func testPackProgrammer() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/pack?value=programmer")), .pack(.programmer))
    }

    func testPackMissingValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/pack")))
    }

    func testThemeBlack() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/theme?value=black")), .theme(.black))
    }

    func testClipboardSeed() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/clipboard-seed")), .seedClipboard)
    }

    func testClearCustomKeyboard() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/custom-clear")), .clearCustomKeyboard)
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

    // MARK: parseAll(fromLaunchArguments:)

    func testParseAllReadsASingleDebugRoutePair() {
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-debugRoute", "height"])
        XCTAssertEqual(routes, [.heightScreen])
    }

    func testParseAllCombinesMultiplePairsInOrder() {
        let args = ["-debugRoute", "entitle?pro=1", "-debugRoute", "preset?value=kiosk", "-debugRoute", "typing"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.entitlePro(true), .heightPreset(.kiosk), .typingSurface(scene: "plain")])
    }

    func testParseAllIgnoresUnrelatedLaunchArguments() {
        let args = ["-someOtherFlag", "1", "-debugRoute", "guide", "-skipOnboarding"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.featuresGuide])
    }

    func testParseAllSkipsAMalformedPairButKeepsParsingAfterIt() {
        let args = ["-debugRoute", "preset?value=huge", "-debugRoute", "editor"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.customKeyboardEditor])
    }

    func testParseAllReturnsEmptyWhenDebugRouteHasNoTrailingValue() {
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-debugRoute"])
        XCTAssertEqual(routes, [])
    }

    func testParseAllReturnsEmptyForArgumentsWithNoDebugRoute() {
        XCTAssertEqual(DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-skipOnboarding"]), [])
    }

    // MARK: shouldSkipOnboarding

    func testShouldSkipOnboardingReadsProcessArguments() {
        // `shouldSkipOnboarding` reads the live process's arguments (there's no seam to inject a
        // fake ProcessInfo here), so this just pins the behavior against the current test-runner
        // invocation rather than asserting a specific value.
        XCTAssertEqual(DebugDeepLinkRoute.shouldSkipOnboarding, ProcessInfo.processInfo.arguments.contains("-skipOnboarding"))
    }
}
#endif
