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

    func testQwertyTestReset() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/qwertytestreset")),
                       .qwertyTestReset)
    }

    func testQwertyLayoutRouteParsesTypedMode() {
        XCTAssertEqual(
            DebugDeepLinkRoute.parse(
                url("numpad://debug/qwertylayout?mode=compactRight")
            ),
            .qwertyLayout(.compactRight)
        )
        XCTAssertNil(
            DebugDeepLinkRoute.parse(
                url("numpad://debug/qwertylayout?mode=diagonal")
            )
        )
    }

    func testNumpadPlacementRouteParsesTypedPlacement() {
        XCTAssertEqual(
            DebugDeepLinkRoute.parse(
                url("numpad://debug/numpadplacement?mode=fullWidth")
            ),
            .numpadPlacement(.fullWidth)
        )
        XCTAssertNil(
            DebugDeepLinkRoute.parse(
                url("numpad://debug/numpadplacement?mode=diagonal")
            )
        )
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
        let args = ["-debugRoute", "qwertytestreset", "-debugRoute", "entitle?pro=1",
                    "-debugRoute", "preset?value=kiosk", "-debugRoute", "typing"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.qwertyTestReset, .entitlePro(true),
                                .heightPreset(.kiosk), .typingSurface])
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

    // MARK: qwertytestreset application

    func testQwertyTestResetClearsSeededPersonalizationAndPinsTypingSettings() {
        let oldDictionary = UserPrefs.qwertyPersonalDictionaryData
        let oldOffsets = UserPrefs.qwertyTouchOffsetsData
        let oldGeneration = UserPrefs.qwertyPersonalResetGeneration
        let oldEpoch = UserPrefs.qwertyPersonalizationEpoch
        let oldAutocorrect = UserPrefs.qwertyAutocorrect
        let oldSuggestions = UserPrefs.qwertySuggestions
        let oldDoubleSpace = UserPrefs.qwertyDoubleSpacePeriod
        let unrelatedKey = "DebugDeepLinkRouteTests.unrelated"
        defer {
            UserPrefs.qwertyPersonalDictionaryData = oldDictionary
            UserPrefs.qwertyTouchOffsetsData = oldOffsets
            UserPrefs.qwertyPersonalResetGeneration = oldGeneration
            UserPrefs.qwertyPersonalizationEpoch = oldEpoch
            UserPrefs.qwertyAutocorrect = oldAutocorrect
            UserPrefs.qwertySuggestions = oldSuggestions
            UserPrefs.qwertyDoubleSpacePeriod = oldDoubleSpace
            UserDefaults.group.removeObject(forKey: unrelatedKey)
        }

        var protectedDictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            protectedDictionary.recordAcceptance(of: "teh")
        }
        XCTAssertTrue(protectedDictionary.isKnown("teh"), "precondition: seed is protected")

        UserPrefs.qwertyPersonalDictionaryData = protectedDictionary.encoded()
        UserPrefs.qwertyTouchOffsetsData = Data([0x01, 0x02])
        UserPrefs.qwertyPersonalResetGeneration = 41
        UserPrefs.qwertyPersonalizationEpoch = 0
        UserPrefs.qwertyAutocorrect = false
        UserPrefs.qwertySuggestions = false
        UserPrefs.qwertyDoubleSpacePeriod = true
        UserDefaults.group.set("keep", forKey: unrelatedKey)
        var postCount = 0

        DeepLinkRouter.applyQwertyTestReset {
            postCount += 1
        }

        XCTAssertEqual(UserPrefs.qwertyPersonalDictionaryData, Data())
        XCTAssertEqual(UserPrefs.qwertyTouchOffsetsData, Data())
        XCTAssertEqual(UserPrefs.qwertyPersonalResetGeneration, 42)
        XCTAssertEqual(UserPrefs.qwertyPersonalizationEpoch, 2)
        XCTAssertTrue(UserPrefs.qwertyAutocorrect)
        XCTAssertTrue(UserPrefs.qwertySuggestions)
        XCTAssertFalse(UserPrefs.qwertyDoubleSpacePeriod)
        XCTAssertEqual(postCount, 1, "the deterministic state is broadcast exactly once")
        XCTAssertEqual(UserDefaults.group.string(forKey: unrelatedKey), "keep",
                       "the narrow route must not reset unrelated user data")
    }

    func testLayoutRouteApplicationMutatesOnlyRequestedPreferenceAndPostsOnce() {
        let oldQwerty = UserPrefs.qwertyLayoutMode
        let oldNumpad = UserPrefs.numpadPlacement
        defer {
            UserPrefs.qwertyLayoutMode = oldQwerty
            UserPrefs.numpadPlacement = oldNumpad
        }
        UserPrefs.qwertyLayoutMode = .automatic
        UserPrefs.numpadPlacement = .automatic
        var posts = 0

        DeepLinkRouter.applyLayoutTestPreference(qwerty: .split) { posts += 1 }
        XCTAssertEqual(UserPrefs.qwertyLayoutMode, .split)
        XCTAssertEqual(UserPrefs.numpadPlacement, .automatic)
        XCTAssertEqual(posts, 1)

        DeepLinkRouter.applyLayoutTestPreference(numpad: .right) { posts += 1 }
        XCTAssertEqual(UserPrefs.qwertyLayoutMode, .split)
        XCTAssertEqual(UserPrefs.numpadPlacement, .right)
        XCTAssertEqual(posts, 2)
    }
}
#endif
