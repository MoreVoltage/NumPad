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

    // MARK: whatsnew (MOR-400 UI-test seeding hook)

    func testWhatsNewUnseen() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/whatsnew?seen=0")), .whatsNewSeen(false))
    }

    func testWhatsNewSeen() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/whatsnew?seen=1")), .whatsNewSeen(true))
    }

    func testWhatsNewMissingOrInvalidQueryReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/whatsnew")))
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/whatsnew?seen=yes")))
    }

    func testParseAllReadsTheWhatsNewSeedBeforeTyping() {
        let args = ["-debugRoute", "entitle?pro=0", "-debugRoute", "whatsnew?seen=0", "-debugRoute", "typing"]
        XCTAssertEqual(DebugDeepLinkRoute.parseAll(fromLaunchArguments: args),
                       [.entitlePro(false), .whatsNewSeen(false), .typingSurface])
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
        XCTAssertEqual(routes, [.entitlePro(true), .heightPreset(.kiosk), .typingSurface])
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

final class DebugWhatsNewSeedTests: XCTestCase {
    private let key = Constants.whatsNewLastSeenVersion.rawValue
    private var saved: Any?

    override func setUp() {
        super.setUp()
        saved = UserDefaults.group.object(forKey: key)
    }

    override func tearDown() {
        if let saved {
            UserDefaults.group.set(saved, forKey: key)
        } else {
            UserDefaults.group.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testDebugClearSeenMakesTheRecapUnseenAgain() {
        WhatsNew.markSeen()
        XCTAssertEqual(WhatsNew.lastSeenVersion, WhatsNew.cutVersion)
        WhatsNew.debugClearSeen()
        XCTAssertNil(WhatsNew.lastSeenVersion)
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: WhatsNew.lastSeenVersion, current: WhatsNew.cutVersion))
    }
}

final class DebugTypingFieldIdentifierTests: XCTestCase {
    func testIdentifierEncodesKeyboardEnablement() {
        XCTAssertEqual(DebugTypingViewController.fieldIdentifier(keyboardEnabled: true), "debugTyping.field.numpadEnabled=1")
        XCTAssertEqual(DebugTypingViewController.fieldIdentifier(keyboardEnabled: false), "debugTyping.field.numpadEnabled=0")
    }
}
#endif
