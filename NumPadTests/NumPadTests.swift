import XCTest
@testable import NumPad

final class NumPadTests: XCTestCase {
    func testTestBundleLoads() {
        XCTAssertNotNil(Bundle(for: Self.self).bundleIdentifier)
    }
}

// MARK: - Calculator

final class CalculatorTests: XCTestCase {
    func testBasicArithmetic() {
        XCTAssertEqual(Calculator.evaluate("2+3"), 5)
        XCTAssertEqual(Calculator.evaluate("10-4"), 6)
        XCTAssertEqual(Calculator.evaluate("6*7"), 42)
        XCTAssertEqual(Calculator.evaluate("20/4"), 5)
    }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(Calculator.evaluate("2+3*4"), 14)
        XCTAssertEqual(Calculator.evaluate("(2+3)*4"), 20)
        XCTAssertEqual(Calculator.evaluate("2*(3+4)-1"), 13)
    }

    func testUnaryMinus() {
        XCTAssertEqual(Calculator.evaluate("-5+3"), -2)
        XCTAssertEqual(Calculator.evaluate("3*-2"), -6)
        XCTAssertEqual(Calculator.evaluate("-(2+3)"), -5)
    }

    func testDecimalsAndAltOperators() {
        XCTAssertEqual(Calculator.evaluate("1.5+2.5"), 4)
        XCTAssertEqual(Calculator.evaluate("3×4"), 12)
        XCTAssertEqual(Calculator.evaluate("8÷2"), 4)
    }

    func testLocaleDecimalSeparator() {
        XCTAssertEqual(Calculator.evaluate("1,5+2,5", decimalSeparator: ","), 4)
    }

    func testDivisionByZeroReturnsNil() {
        XCTAssertNil(Calculator.evaluate("5/0"))
        XCTAssertNil(Calculator.evaluate("5%0"))
    }

    func testMalformedReturnsNil() {
        XCTAssertNil(Calculator.evaluate(""))
        XCTAssertNil(Calculator.evaluate("2+"))
        XCTAssertNil(Calculator.evaluate("(2+3"))
        XCTAssertNil(Calculator.evaluate("2+3)"))
        XCTAssertNil(Calculator.evaluate("abc"))
        XCTAssertNil(Calculator.evaluate("2 3"))
    }

    func testFormatStripsTrailingZero() {
        XCTAssertEqual(Calculator.format(5), "5")
        XCTAssertEqual(Calculator.format(2.5), "2.5")
        XCTAssertEqual(Calculator.format(2.5, decimalSeparator: ","), "2,5")
    }

    // MARK: - Percent-natural math (Live Math Preview)

    /// "+"/"-" treat a %-suffixed right-hand side as a percentage *of the left-hand operand* — the
    /// receipt-math convention ("250 - 20%" reads as "250, minus 20% of 250").
    func testPercentWithPlusAndMinusIsPercentOfLeftOperand() {
        XCTAssertEqual(Calculator.evaluate("250 - 20%"), 200)
        XCTAssertEqual(Calculator.evaluate("84 + 18%"), 99.12)
        XCTAssertEqual(Calculator.evaluate("100+50%"), 150)
    }

    /// "*"/"/" treat a %-suffixed right-hand side as a plain fraction (÷100) — how a physical
    /// calculator's % key behaves for multiplication/division.
    func testPercentWithMultiplyAndDivideIsPlainFraction() {
        XCTAssertEqual(Calculator.evaluate("50 * 20%"), 10)
        XCTAssertEqual(Calculator.evaluate("50 / 20%"), 250)
    }

    /// A lone percent value with no enclosing binary op is also a plain fraction.
    func testStandalonePercentIsPlainFraction() {
        XCTAssertEqual(Calculator.evaluate("20%"), 0.2)
        XCTAssertEqual(Calculator.evaluate("-20%"), -0.2)
    }

    /// Chained percentages compound against the *running* left-hand value, not the original
    /// operand — matches sequential discount/markup stacking (e.g. two 10% discounts in a row).
    func testChainedPercentCompoundsAgainstRunningTotal() {
        XCTAssertEqual(Calculator.evaluate("100 - 10% - 10%"), 81) // 100 → 90 → 81
        XCTAssertEqual(Calculator.evaluate("100 + 10% + 10%"), 121) // 100 → 110 → 121
    }

    /// Percent only ever suffixes the number immediately before it; anything else is malformed.
    func testPercentRequiresPrecedingNumber() {
        XCTAssertNil(Calculator.evaluate("%5"))
        XCTAssertNil(Calculator.evaluate("5+%3"))
        XCTAssertNil(Calculator.evaluate("(2+3)%"))
    }

    /// Existing behavior that must stay stable through the percent-natural rewrite.
    func testExistingBehaviorStableAfterPercentRewrite() {
        XCTAssertEqual(Calculator.evaluate("2+3"), 5)
        XCTAssertEqual(Calculator.evaluate("2+3*4"), 14)
        XCTAssertEqual(Calculator.evaluate("3*-2"), -6)
        XCTAssertNil(Calculator.evaluate("5/0"))
        // "5%0" is malformed under percent-natural syntax (a percent literal directly followed by
        // another number with no operator) — nil for a different reason than the old "mod by
        // zero" semantics, but still correctly nil either way.
        XCTAssertNil(Calculator.evaluate("5%0"))
    }
}

// MARK: - Unit converter

final class UnitConverterTests: XCTestCase {
    func testLength() {
        XCTAssertEqual(UnitConverter.convert(100, from: "cm", to: "m")!, 1, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(1, from: "in", to: "cm")!, 2.54, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(1, from: "mi", to: "km")!, 1.609344, accuracy: 1e-9)
    }

    func testMass() {
        XCTAssertEqual(UnitConverter.convert(1, from: "kg", to: "g")!, 1000, accuracy: 1e-6)
        XCTAssertEqual(UnitConverter.convert(1, from: "lb", to: "kg")!, 0.45359237, accuracy: 1e-9)
    }

    func testTemperature() {
        XCTAssertEqual(UnitConverter.convert(0, from: "°C", to: "°F")!, 32, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(100, from: "°C", to: "°F")!, 212, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(32, from: "°F", to: "°C")!, 0, accuracy: 1e-9)
    }

    func testSameUnitAndUnknown() {
        XCTAssertEqual(UnitConverter.convert(5, from: "m", to: "m"), 5)
        XCTAssertNil(UnitConverter.convert(5, from: "m", to: "kg"))
        XCTAssertNil(UnitConverter.convert(5, from: "bogus", to: "m"))
    }

    // MARK: - Volume (Cooking & Baking pack)

    func testVolumeCupToMl() {
        XCTAssertEqual(UnitConverter.convert(1, from: "cup", to: "ml")!, 236.5882365, accuracy: 1e-6)
        XCTAssertEqual(UnitConverter.convert(236.5882365, from: "ml", to: "cup")!, 1, accuracy: 1e-9)
    }

    func testVolumeTablespoonsAndTeaspoonsPerCup() {
        // A US cup is exactly 16 tablespoons and 48 teaspoons — the ratios recipes assume.
        XCTAssertEqual(UnitConverter.convert(1, from: "cup", to: "tbsp")!, 16, accuracy: 1e-6)
        XCTAssertEqual(UnitConverter.convert(1, from: "cup", to: "tsp")!, 48, accuracy: 1e-6)
        XCTAssertEqual(UnitConverter.convert(3, from: "tsp", to: "tbsp")!, 1, accuracy: 1e-9)
    }

    func testVolumeRejectsCrossCategoryConversion() {
        XCTAssertNil(UnitConverter.convert(1, from: "cup", to: "kg"))
        XCTAssertNil(UnitConverter.convert(1, from: "ml", to: "cm"))
    }
}

// MARK: - Tax/Tip math

final class TaxTipMathTests: XCTestCase {
    func testTotalAppliesTaxAndTipOnPreTaxAmount() {
        XCTAssertEqual(TaxTipMath.total(amount: 100, taxRate: 0.10, tipRate: 0.20), 130, accuracy: 1e-9)
        XCTAssertEqual(TaxTipMath.total(amount: 50, taxRate: 0, tipRate: 0.15), 57.5, accuracy: 1e-9)
    }

    func testZeroRatesReturnAmount() {
        XCTAssertEqual(TaxTipMath.total(amount: 42, taxRate: 0, tipRate: 0), 42, accuracy: 1e-9)
    }

    func testTipOnlyIgnoresTax() {
        XCTAssertEqual(TaxTipMath.tipOnly(amount: 100, tipRate: 0.18), 18, accuracy: 1e-9)
        XCTAssertEqual(TaxTipMath.tipOnly(amount: 100, tipRate: 0), 0, accuracy: 1e-9)
    }

    func testPreTaxAmountBacksOutTaxFromAnInclusiveTotal() {
        // $108 total with 8% tax already included → $100 pre-tax subtotal.
        XCTAssertEqual(TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: 108, taxRate: 0.08), 100, accuracy: 1e-9)
    }

    func testPreTaxAmountWithZeroTaxRateReturnsTheTotalUnchanged() {
        XCTAssertEqual(TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: 54, taxRate: 0), 54, accuracy: 1e-9)
    }

    func testPreTaxAmountGuardsAgainstNonsensicalTaxRates() {
        // taxRate <= -1 would divide by zero or flip the sign — fall back to the total unchanged.
        XCTAssertEqual(TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: 54, taxRate: -1), 54, accuracy: 1e-9)
        XCTAssertEqual(TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: 54, taxRate: -2), 54, accuracy: 1e-9)
    }

    func testPreTaxAmountRoundTripsWithTotal() {
        // Feeding preTaxAmount's output back into total() should reproduce the original bill plus tip.
        let taxInclusiveBill = 108.0
        let taxRate = 0.08
        let tipRate = 0.20
        let subtotal = TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: taxInclusiveBill, taxRate: taxRate)
        let total = TaxTipMath.total(amount: subtotal, taxRate: taxRate, tipRate: tipRate)
        XCTAssertEqual(total, taxInclusiveBill + TaxTipMath.tipOnly(amount: subtotal, tipRate: tipRate), accuracy: 1e-9)
    }
}

// MARK: - App Intents (Siri / Shortcuts / Spotlight) parameter-mapping & formatting helpers

final class AppIntentFormattingTests: XCTestCase {
    func testNumberMatchesCalculatorFormat() {
        XCTAssertEqual(AppIntentFormatting.number(5), Calculator.format(5))
        XCTAssertEqual(AppIntentFormatting.number(2.5), Calculator.format(2.5))
        XCTAssertEqual(AppIntentFormatting.number(5), "5")
    }

    func testConversionDialogFormatsAllFourComponents() {
        let dialog = AppIntentFormatting.conversionDialog(value: 3, fromLabel: "cups", result: 709.7647095, toLabel: "ml")
        XCTAssertTrue(dialog.contains("3"))
        XCTAssertTrue(dialog.contains("cups"))
        XCTAssertTrue(dialog.contains("ml"))
        XCTAssertTrue(dialog.contains(Calculator.format(709.7647095)))
    }

    func testCalculateDialogIncludesExpressionAndResult() {
        let dialog = AppIntentFormatting.calculateDialog(expression: "2+2", result: 4)
        XCTAssertTrue(dialog.contains("2+2"))
        XCTAssertTrue(dialog.contains("4"))
    }

    func testTipDialogIncludesTipAndTotal() {
        let dialog = AppIntentFormatting.tipDialog(tip: 9, total: 59)
        XCTAssertTrue(dialog.contains("9"))
        XCTAssertTrue(dialog.contains("59"))
    }
}

// MARK: - App Intents kill switch

final class AppIntentsKillSwitchTests: XCTestCase {
    /// Same two-switch shape as `dragReorderActive` / `keyPressAnimationActive`: both the Remote
    /// Config value and the local flag must be on.
    func testBothEnabledMeansActive() {
        XCTAssertTrue(FeatureFlags.appIntentsActive(remoteEnabled: true, localEnabled: true))
    }

    func testRemoteKillSwitchOffDisablesEvenIfLocalIsOn() {
        XCTAssertFalse(FeatureFlags.appIntentsActive(remoteEnabled: false, localEnabled: true))
    }

    func testLocalFlagOffDisablesEvenIfRemoteIsOn() {
        XCTAssertFalse(FeatureFlags.appIntentsActive(remoteEnabled: true, localEnabled: false))
    }

    func testBothOffIsDisabled() {
        XCTAssertFalse(FeatureFlags.appIntentsActive(remoteEnabled: false, localEnabled: false))
    }
}

// MARK: - Snippet dynamic tokens

final class SnippetTokenTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_750_000_000) // fixed instant
    private let posix = Locale(identifier: "en_US_POSIX")

    func testPlainTextPassesThrough() {
        XCTAssertEqual(Snippet.expand("no tokens here", now: noon, locale: posix), "no tokens here")
    }

    func testDateTokenExpandsToLocalizedDate() {
        let expected = DateFormatter()
        expected.locale = posix
        expected.dateStyle = .medium
        expected.timeStyle = .none
        XCTAssertEqual(Snippet.expand("Invoice {date}", now: noon, locale: posix),
                       "Invoice " + expected.string(from: noon))
    }

    func testTimeTokenExpandsToLocalizedTime() {
        let expected = DateFormatter()
        expected.locale = posix
        expected.dateStyle = .none
        expected.timeStyle = .short
        XCTAssertEqual(Snippet.expand("at {time}", now: noon, locale: posix),
                       "at " + expected.string(from: noon))
    }

    func testBothTokensAndRepeats() {
        let out = Snippet.expand("{date} {date} {time}", now: noon, locale: posix)
        XCTAssertFalse(out.contains("{date}"))
        XCTAssertFalse(out.contains("{time}"))
    }

    func test_expand_allTokens() {
        let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed
        let loc = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(Snippet.expand("{unix}", now: now, locale: loc, clipboard: { nil }), "1700000000")
        XCTAssertEqual(Snippet.expand("Y{year}", now: now, locale: loc, clipboard: { nil }), "Y2023")
        XCTAssertEqual(Snippet.expand("{clipboard}", now: now, locale: loc, clipboard: { "ABC" }), "ABC")
        XCTAssertEqual(Snippet.expand("none", now: now, locale: loc, clipboard: { nil }), "none")
    }

    func test_catalogMatchesEngineTokens() {
        XCTAssertEqual(Set(SnippetTokens.all.map { $0.token }), Set(Snippet.tokenMap.map { $0.token }),
                       "SnippetTokens catalog and Snippet.tokenMap must cover the same tokens")
    }

    func test_everyCatalogTokenExpandsAndHasLabel() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let loc = Locale(identifier: "en_US_POSIX")
        for entry in SnippetTokens.all {
            let out = Snippet.expand(entry.token, now: now, locale: loc, clipboard: { "CLIP" })
            XCTAssertNotEqual(out, entry.token, "\(entry.token) was not expanded")
            XCTAssertFalse(out.isEmpty, "\(entry.token) expanded to empty")
            XCTAssertFalse(entry.label.isEmpty, "\(entry.token) has an empty label")
        }
        XCTAssertEqual(Set(SnippetTokens.all.map { $0.label }).count, SnippetTokens.all.count, "labels must be distinct")
    }

    func test_datetimeTokenExpandsWithoutBraceMangling() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let out = Snippet.expand("{datetime}", now: now, locale: Locale(identifier: "en_US_POSIX"), clipboard: { nil })
        XCTAssertFalse(out.contains("{"), "{datetime} left a stray brace (token-ordering regression)")
        XCTAssertNotEqual(out, "{datetime}")
    }

    func test_catalogOrderMatchesEngine() {
        XCTAssertEqual(SnippetTokens.all.map { $0.token }, Snippet.tokenMap.map { $0.token },
                       "chip order must match engine order")
    }
}

// MARK: - Clipboard pinning

final class ClipboardVisibilityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private var cutoff: Date { now.addingTimeInterval(-3600) }

    func testUnpinnedExpire() {
        let old = ClipboardEntry(text: "old", date: now.addingTimeInterval(-7200))
        let fresh = ClipboardEntry(text: "fresh", date: now)
        let visible = ClipboardHistoryManager.visible([fresh, old], cutoff: cutoff)
        XCTAssertEqual(visible.map { $0.text }, ["fresh"])
    }

    func testPinnedSurviveExpiryAndSortFirst() {
        let oldPinned = ClipboardEntry(text: "keep", date: now.addingTimeInterval(-7200), pinned: true)
        let fresh = ClipboardEntry(text: "fresh", date: now)
        let visible = ClipboardHistoryManager.visible([fresh, oldPinned], cutoff: cutoff)
        XCTAssertEqual(visible.map { $0.text }, ["keep", "fresh"])
    }

    func testGroupsPreserveRelativeOrder() {
        let p1 = ClipboardEntry(text: "p1", date: now, pinned: true)
        let p2 = ClipboardEntry(text: "p2", date: now.addingTimeInterval(-10), pinned: true)
        let u1 = ClipboardEntry(text: "u1", date: now)
        let u2 = ClipboardEntry(text: "u2", date: now.addingTimeInterval(-10))
        let visible = ClipboardHistoryManager.visible([p1, u1, p2, u2], cutoff: cutoff)
        XCTAssertEqual(visible.map { $0.text }, ["p1", "p2", "u1", "u2"])
    }

    func testLegacyEntriesDecodeAsUnpinned() throws {
        let legacy = #"[{"text":"a","date":1000}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([ClipboardEntry].self, from: legacy)
        XCTAssertEqual(decoded.first?.pinned, false)
    }
}

// MARK: - Keyboard height presets

final class HeightPresetTests: XCTestCase {
    func testBaseHeightsPhone() {
        XCTAssertEqual(KeyboardHeightPreset.small.baseHeight(idiom: .phone), 260)
        XCTAssertEqual(KeyboardHeightPreset.regular.baseHeight(idiom: .phone), 300)
        XCTAssertEqual(KeyboardHeightPreset.tall.baseHeight(idiom: .phone), 340)
        // Kiosk isn't offered on iPhone; it mirrors Tall there in case it's ever read.
        XCTAssertEqual(KeyboardHeightPreset.kiosk.baseHeight(idiom: .phone), 340)
    }

    func testBaseHeightsPad() {
        XCTAssertEqual(KeyboardHeightPreset.small.baseHeight(idiom: .pad), 300)
        XCTAssertEqual(KeyboardHeightPreset.regular.baseHeight(idiom: .pad), 350)
        XCTAssertEqual(KeyboardHeightPreset.tall.baseHeight(idiom: .pad), 420)
        XCTAssertEqual(KeyboardHeightPreset.kiosk.baseHeight(idiom: .pad), 500)
    }

    func testUnknownRawValueFallsBackToRegular() {
        XCTAssertNil(KeyboardHeightPreset(rawValue: "huge"))
        // `selected` getter falls back to .regular for unknown stored values; the raw-value
        // round-trip below is what protects renames.
        for preset in KeyboardHeightPreset.allCases {
            XCTAssertEqual(KeyboardHeightPreset(rawValue: preset.rawValue), preset)
        }
    }

    func testKioskFallsBackToTallWhenNotEntitled() {
        XCTAssertEqual(KeyboardHeightPreset.effective(stored: .kiosk, kioskEntitled: false), .tall)
        XCTAssertEqual(KeyboardHeightPreset.effective(stored: .kiosk, kioskEntitled: true), .kiosk)
    }

    func testEffectivePassesThroughNonKioskPresetsRegardlessOfEntitlement() {
        for preset in [KeyboardHeightPreset.small, .regular, .tall] {
            XCTAssertEqual(KeyboardHeightPreset.effective(stored: preset, kioskEntitled: false), preset)
            XCTAssertEqual(KeyboardHeightPreset.effective(stored: preset, kioskEntitled: true), preset)
        }
    }

    func testClampedHeightWithinBounds() {
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: 300, minHeight: 220, maxHeightCap: 500), 300)
    }

    func testClampedHeightFloorsAtMinHeight() {
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: 150, minHeight: 220, maxHeightCap: 500), 220)
    }

    func testClampedHeightCapsAtHalfContainer() {
        // Kiosk's 500pt base exceeds a 700pt container's 50% cap (350pt).
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: 500, minHeight: 220, maxHeightCap: 350), 350)
    }

    func testClampedHeightCapNeverBelowMinHeight() {
        // A pathologically small container (cap < floor) must never pin below the floor itself.
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: 300, minHeight: 220, maxHeightCap: 100), 220)
    }

    func testIsFloatingKeyboardNeverTrueOnPhone() {
        // Even a tiny width/height container on iPhone must never suppress the custom height.
        XCTAssertFalse(KeyboardHeightPreset.isFloatingKeyboard(isPad: false, width: 300, containerHeight: 200))
    }

    func testIsFloatingKeyboardRequiresBothNarrowAndShort() {
        // The real pinch-to-float mini keyboard: narrow AND short.
        XCTAssertTrue(KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 320, containerHeight: 225))
    }

    func testIsFloatingKeyboardNotTriggeredByNarrowSlideOverWithFullDeviceHeight() {
        // iPad Slide Over: narrow like the floating keyboard, but the host pane keeps the device's
        // full height — must not be misclassified as the floating keyboard (regression coverage).
        XCTAssertFalse(KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 320, containerHeight: 1024))
    }

    func testIsFloatingKeyboardNotTriggeredByShortButWideContainer() {
        XCTAssertFalse(KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 700, containerHeight: 225))
    }

    // MARK: - Notification quick-reply height-reset regression

    /// Demonstrates the bug mechanism in isolation: if the clamp ceiling were sourced from the
    /// system's placeholder input-view container (~228pt — the ballpark height `viewWillAppear`
    /// observed on the notification quick-reply host before the window attaches) instead of the
    /// real screen/window height, a 340pt Tall preset collapses straight to the 220pt floor,
    /// regardless of what the user actually picked. `maxHeightCap` from a 228pt container is
    /// `floor(228 * 0.5) == 114`, which is below `minHeight`, so `clampedHeight` floors the result.
    func testClampedHeightCollapsesTallPresetWhenContainerHeightIsPlaceholderSized() {
        let placeholderContainerHeight: CGFloat = 228
        let maxHeightCap = floor(placeholderContainerHeight * 0.5)
        XCTAssertEqual(maxHeightCap, 114)
        XCTAssertEqual(
            KeyboardHeightPreset.clampedHeight(base: 340, minHeight: 220, maxHeightCap: maxHeightCap),
            220,
            "A placeholder-sized container silently floors the Tall preset — this is the mechanism behind the height-resets-to-minimum regression."
        )
    }

    /// The fix: once the clamp ceiling is sourced from `clampCeilingContainerHeight` (real window
    /// height, or the physical screen as fallback — never the placeholder superview), the same
    /// 340pt Tall preset survives a `window == nil` appearance intact.
    func testClampCeilingContainerHeightPrefersWindowHeightWhenAttached() {
        XCTAssertEqual(
            KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: 844, screenHeight: 375),
            844
        )
    }

    /// Mid page-switch (numpad ⇄ QWERTY) the keyboard's own ~keyboard-sized window is attached;
    /// trusting it starved the 50% cap below the floor and pinned every preset to 220pt
    /// (owner-reported: switching to the numpad page always reverted to the small height).
    func testClampCeilingRejectsKeyboardSizedWindowMidPageSwitch() {
        XCTAssertEqual(
            KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: 344, screenHeight: 852),
            852
        )
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: 344, screenHeight: 852)
        let base = KeyboardHeightPreset.tall.baseHeight(idiom: .phone)
        XCTAssertEqual(
            KeyboardHeightPreset.clampedHeight(base: base, minHeight: 220, maxHeightCap: floor(containerHeight * 0.5)),
            340,
            "The Tall preset must survive a page switch in full, not collapse to the 220pt floor."
        )
    }

    func testClampCeilingContainerHeightFallsBackToScreenHeightWhenWindowIsNil() {
        XCTAssertEqual(
            KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: nil, screenHeight: 844),
            844
        )
    }

    /// End-to-end regression check for the reported symptom: a fresh appearance where the window
    /// isn't attached yet (so the clamp ceiling falls back to the physical screen height, e.g. an
    /// iPhone's ~844pt) must still apply the persisted Tall preset in full, not the 220pt floor.
    func testFreshAppearanceWithNoWindowStillAppliesTallPresetInFull() {
        let screenHeight: CGFloat = 844
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: nil, screenHeight: screenHeight)
        let base = KeyboardHeightPreset.tall.baseHeight(idiom: .phone)
        let result = KeyboardHeightPreset.clampedHeight(base: base, minHeight: 220, maxHeightCap: floor(containerHeight * 0.5))
        XCTAssertEqual(result, 340, "The Tall preset must survive a window == nil appearance, not collapse to the 220pt floor.")
    }

    /// Repeated appearance cycles (keyboard switched away and back, as happens on every
    /// notification-reply round trip) must converge on the same clamped height rather than
    /// ratcheting up or down — regression coverage for the iPad height-drift fix interacting with
    /// the new container-height source.
    func testRepeatedAppearanceCyclesConvergeToSameHeight() {
        let screenHeight: CGFloat = 844
        let base = KeyboardHeightPreset.regular.baseHeight(idiom: .phone)
        var results: [CGFloat] = []
        for windowHeight: CGFloat? in [nil, 844, nil, 844, 844] {
            let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: windowHeight, screenHeight: screenHeight)
            results.append(KeyboardHeightPreset.clampedHeight(base: base, minHeight: 220, maxHeightCap: floor(containerHeight * 0.5)))
        }
        XCTAssertEqual(Set(results), [300], "Every appearance in the cycle must resolve to the same 300pt Default height — no drift, no ratchet.")
    }

    /// Landscape clamp still applies once the window is attached (the practical rotation path,
    /// `viewWillTransition`, always runs on an already-visible — and therefore window-attached —
    /// keyboard): a short landscape window height correctly lowers the cap below the Tall preset's
    /// base. `UIScreen.main.bounds` rotates too, so in real landscape the screen height reads the
    /// same short dimension as the window — which is exactly why the window stays trusted here
    /// while a keyboard-sized window against a PORTRAIT screen (mid page-switch) is rejected.
    func testLandscapeClampStillAppliesWithAttachedWindow() {
        let landscapeWindowHeight: CGFloat = 375
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: landscapeWindowHeight, screenHeight: 375)
        let base = KeyboardHeightPreset.tall.baseHeight(idiom: .phone)
        let result = KeyboardHeightPreset.clampedHeight(base: base, minHeight: 160, maxHeightCap: floor(containerHeight * 0.5))
        XCTAssertEqual(result, floor(landscapeWindowHeight * 0.5))
    }

    /// iPad Kiosk (Pro-gated, entitled) and Tall presets must still fully apply once the container
    /// height correctly reflects a real iPad-sized window, not a placeholder.
    func testIPadKioskAndTallPresetsStillApplyWithRealContainerHeight() {
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: 1366, screenHeight: 1366)
        let kioskBase = KeyboardHeightPreset.kiosk.baseHeight(idiom: .pad)
        let tallBase = KeyboardHeightPreset.tall.baseHeight(idiom: .pad)
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: kioskBase, minHeight: 220, maxHeightCap: floor(containerHeight * 0.5)), 500)
        XCTAssertEqual(KeyboardHeightPreset.clampedHeight(base: tallBase, minHeight: 220, maxHeightCap: floor(containerHeight * 0.5)), 420)
    }

    /// The floating-mini-keyboard suppression is untouched by the container-height source change —
    /// it still keys off `isFloatingKeyboard`, not `clampCeilingContainerHeight`.
    func testFloatingKeyboardSuppressionUnaffectedByContainerHeightSourceChange() {
        XCTAssertTrue(KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 320, containerHeight: 225))
    }

    /// Regression coverage for `KeyboardViewController.isFloatingKeyboard`: it must source
    /// `containerHeight` from `clampCeilingContainerHeight`, not from the placeholder-prone
    /// `inputView?.superview?.bounds.height` fallback `defaultKeyboardHeight()` was already fixed
    /// against. Composes the same two pure functions the view controller now composes, so it
    /// catches a regression to the old fallback chain without needing a live view hierarchy.
    func testIsFloatingKeyboardNotMisclassifiedWhenWindowIsNilAtAppearance() {
        // Sanity check on the bug mechanism: a placeholder-sized container height alone would
        // satisfy the floating check for a perfectly normal narrow-but-tall host.
        let placeholderContainerHeight: CGFloat = 228
        XCTAssertTrue(
            KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 320, containerHeight: placeholderContainerHeight),
            "Sanity check: the placeholder height alone would satisfy the floating check — this is the bug mechanism."
        )

        // The fix: a window == nil appearance resolves containerHeight to the real screen height,
        // not the placeholder, so the same narrow width no longer misclassifies the host as the
        // floating mini keyboard.
        let fixedContainerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: nil, screenHeight: 844)
        XCTAssertFalse(
            KeyboardHeightPreset.isFloatingKeyboard(isPad: true, width: 320, containerHeight: fixedContainerHeight),
            "A window == nil appearance must fall back to the real screen height, not the placeholder, so a legitimate narrow-but-tall host (e.g. notification quick-reply) is never misclassified as the floating mini keyboard."
        )
    }
}

// MARK: - Backspace chunk deletion

final class TextDeletionTests: XCTestCase {
    func testNumberRun() {
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "pay 1,234.56"), 8)
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "42"), 2)
    }

    func testLetterRunAndWhitespace() {
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "hello world"), 5)
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "hello   "), 3)
    }

    func testSymbolsDeleteSingly() {
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "5+"), 1)
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: "()"), 1)
    }

    func testEmptyAndCap() {
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: ""), 0)
        XCTAssertEqual(TextDeletion.trailingChunkLength(of: String(repeating: "1", count: 99)), TextDeletion.maxChunk)
    }
}

// MARK: - Version comparison (grandfathering)

final class VersionComparisonTests: XCTestCase {
    func testOlderVersionsAreLess() {
        XCTAssertTrue(StoreManager.isVersion("1.0", lessThan: "1.7.0"))
        XCTAssertTrue(StoreManager.isVersion("1.6.9", lessThan: "1.7.0"))
        XCTAssertTrue(StoreManager.isVersion("1.5.4", lessThan: "1.7.0"))
    }

    func testEqualOrNewerAreNotLess() {
        XCTAssertFalse(StoreManager.isVersion("1.7.0", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("1.7.1", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("2.0", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("1.10", lessThan: "1.7.0"))
    }

    func testUnparseableFailsClosed() {
        // An unparseable version must NOT be treated as older (no free grandfathering on bad input).
        XCTAssertFalse(StoreManager.isVersion("", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("abc", lessThan: "1.7.0"))
    }

    func testGrandfatherMigrationClearsStaleValueWhenAppTransactionUnavailable() {
        let result = StoreManager.grandfatherMigrationResult(
            appTransactionAvailable: false,
            isProduction: false,
            originalAppVersion: nil
        )

        XCTAssertFalse(result.isGrandfathered)
        XCTAssertFalse(result.markChecked)
    }

    func testGrandfatherMigrationNeverGrantsSandboxGrandfathering() {
        let result = StoreManager.grandfatherMigrationResult(
            appTransactionAvailable: true,
            isProduction: false,
            originalAppVersion: "1.0"
        )

        XCTAssertFalse(result.isGrandfathered)
        XCTAssertTrue(result.markChecked)
    }

    func testGrandfatherMigrationGrantsOldProductionInstalls() {
        let result = StoreManager.grandfatherMigrationResult(
            appTransactionAvailable: true,
            isProduction: true,
            originalAppVersion: "1.6.9"
        )

        XCTAssertTrue(result.isGrandfathered)
        XCTAssertTrue(result.markChecked)
    }
}

// MARK: - Feature flags

final class FeatureFlagTests: XCTestCase {
    func testExperimentalFlagIsDisabledWhenUIIsHiddenEvenIfStoredTrue() {
        XCTAssertFalse(FeatureFlags.isExperimentalFlagEnabled(stored: true, uiVisible: false))
    }

    func testExperimentalFlagRequiresRuntimeCapability() {
        XCTAssertFalse(FeatureFlags.isExperimentalFlagEnabled(stored: true, uiVisible: true, capabilityAvailable: false))
    }

    func testExperimentalFlagIsEnabledOnlyWhenStoredVisibleAndCapable() {
        XCTAssertTrue(FeatureFlags.isExperimentalFlagEnabled(stored: true, uiVisible: true, capabilityAvailable: true))
        XCTAssertFalse(FeatureFlags.isExperimentalFlagEnabled(stored: false, uiVisible: true, capabilityAvailable: true))
    }
}

// MARK: - Pack key catalog (Phase 2 — 2.0 symbol packs)

final class PackKeysTests: XCTestCase {
    // These packs are retained for back-compat decode but are no longer user-selectable.
    // `.units` was revived as a real à la carte pack — see `UnitsPackTests` below.
    private let legacyDecodeOnlyPacks: [KeyboardType] = [.scientific, .business, .programmerPlus, .international]

    func testEachNewPackHasTenKeys() {
        for pack in legacyDecodeOnlyPacks {
            XCTAssertEqual(PackKeys.symbols(for: pack).count, 10, "\(pack.rawValue) should have 10 keys")
        }
    }

    func testNewPackKeysAreNonEmptyAndUnique() {
        for pack in legacyDecodeOnlyPacks {
            let keys = PackKeys.symbols(for: pack)
            XCTAssertFalse(keys.contains(where: { $0.isEmpty }), "\(pack.rawValue) has an empty key")
            XCTAssertEqual(Set(keys).count, keys.count, "\(pack.rawValue) has duplicate keys")
        }
    }

    func testLegacyPacksAreNotSelectable() {
        for pack in legacyDecodeOnlyPacks {
            XCTAssertFalse(KeyboardType.packs.contains(pack), "\(pack.rawValue) should be dropped from the picker")
        }
    }

    func testNewPacksHaveDistinctNonEmptyNames() {
        let names = legacyDecodeOnlyPacks.map { $0.name }
        XCTAssertFalse(names.contains(where: { $0.isEmpty }))
        XCTAssertEqual(Set(names).count, names.count, "pack names should be distinct")
    }

    func testRawValueRoundTrips() {
        for pack in legacyDecodeOnlyPacks {
            XCTAssertEqual(KeyboardType(rawValue: pack.rawValue), pack)
        }
    }

    func testNonSymbolPacksReturnNoKeys() {
        XCTAssertTrue(PackKeys.symbols(for: .default).isEmpty)
        XCTAssertTrue(PackKeys.symbols(for: .math).isEmpty)
    }
}

// MARK: - Date/Time pack tokens (Phase 2)

final class DateTimeTokensTests: XCTestCase {
    private let instant = Date(timeIntervalSince1970: 1_750_000_000) // fixed
    private let posix = Locale(identifier: "en_US_POSIX")

    func testUnknownTokenReturnsNil() {
        XCTAssertNil(DateTimeTokens.value(for: "bogus", now: instant, locale: posix))
    }

    func testUnixIsIntegerSeconds() {
        XCTAssertEqual(DateTimeTokens.value(for: "unix", now: instant, locale: posix), "1750000000")
    }

    func testDateMatchesMediumStyle() {
        let f = DateFormatter(); f.locale = posix; f.dateStyle = .medium; f.timeStyle = .none
        XCTAssertEqual(DateTimeTokens.value(for: "date", now: instant, locale: posix), f.string(from: instant))
    }

    func testIsoDateIsFixedFormat() {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(DateTimeTokens.value(for: "iso", now: instant, locale: posix), f.string(from: instant))
    }

    func testKeyTokenRoundTrips() {
        for (token, _) in DateTimeTokens.ordered {
            XCTAssertEqual(DateTimeTokens.token(fromKey: DateTimeTokens.keyToken(for: token)), token)
        }
        XCTAssertNil(DateTimeTokens.token(fromKey: "{left}"))
        XCTAssertNil(DateTimeTokens.token(fromKey: "plain"))
    }

    func testOrderedTokensAreTenUniqueAndResolvable() {
        XCTAssertEqual(DateTimeTokens.ordered.count, 10)
        let tokens = DateTimeTokens.ordered.map { $0.token }
        XCTAssertEqual(Set(tokens).count, tokens.count)
        for t in tokens {
            XCTAssertNotNil(DateTimeTokens.value(for: t, now: instant, locale: posix), "token \(t) unresolved")
        }
    }

    func testDatetimePackIsSelectable() {
        XCTAssertTrue(KeyboardType.packs.contains(.datetime))
    }
}

// MARK: - Units & Conversion pack (revived + real conversion, pack-lineup pass)

final class UnitsPackTests: XCTestCase {
    func testUnitsPackIsSelectable() {
        XCTAssertTrue(KeyboardType.packs.contains(.units))
    }

    func testUnitsPackHasTenUniqueNonEmptyKeys() {
        let keys = PackKeys.symbols(for: .units)
        XCTAssertEqual(keys.count, 10)
        XCTAssertFalse(keys.contains(where: { $0.isEmpty }))
        XCTAssertEqual(Set(keys).count, keys.count, "units pack has duplicate keys")
    }

    func testUnitsPackHasADistinctProductID() {
        XCTAssertEqual(ProductCatalog.packProductID(for: .units), "numpad.pack.units")
    }

    func testUnitsPackLockedUntilOwnedOrPro() {
        let id = ProductCatalog.packProductID(for: .units)!
        XCTAssertTrue(Monetization.isPackLocked(.units, proEntitled: false, ownedPackProductIDs: []))
        XCTAssertFalse(Monetization.isPackLocked(.units, proEntitled: false, ownedPackProductIDs: [id]))
        XCTAssertFalse(Monetization.isPackLocked(.units, proEntitled: true, ownedPackProductIDs: []))
    }

    func testConversionOverlayReachableWhenEntitledOrExperimentalFlagOn() {
        // Entitled via Units (pack owned or Pro) reaches it even with the experimental flag off,
        // regardless of Cooking ownership.
        XCTAssertTrue(Monetization.isConversionOverlayReachable(experimentalFlagOn: false, unitsPackLocked: false, cookingPackLocked: true))
        // Un-entitled DEBUG/TestFlight testers still reach it via the experimental flag.
        XCTAssertTrue(Monetization.isConversionOverlayReachable(experimentalFlagOn: true, unitsPackLocked: true, cookingPackLocked: true))
        // Un-entitled to either pack with the flag off: unreachable.
        XCTAssertFalse(Monetization.isConversionOverlayReachable(experimentalFlagOn: false, unitsPackLocked: true, cookingPackLocked: true))
    }
}

// MARK: - Cooking & Baking pack (pack-lineup pass, stream 2)

final class CookingPackTests: XCTestCase {
    func testCookingPackIsSelectable() {
        XCTAssertTrue(KeyboardType.packs.contains(.cooking))
    }

    func testCookingPackHasTenUniqueNonEmptyKeys() {
        let keys = PackKeys.symbols(for: .cooking)
        XCTAssertEqual(keys.count, 10)
        XCTAssertFalse(keys.contains(where: { $0.isEmpty }))
        XCTAssertEqual(Set(keys).count, keys.count, "cooking pack has duplicate keys")
    }

    func testCookingPackHasADistinctProductID() {
        XCTAssertEqual(ProductCatalog.packProductID(for: .cooking), "numpad.pack.cooking")
    }

    func testCookingPackLockedUntilOwnedOrPro() {
        let id = ProductCatalog.packProductID(for: .cooking)!
        XCTAssertTrue(Monetization.isPackLocked(.cooking, proEntitled: false, ownedPackProductIDs: []))
        XCTAssertFalse(Monetization.isPackLocked(.cooking, proEntitled: false, ownedPackProductIDs: [id]))
        XCTAssertFalse(Monetization.isPackLocked(.cooking, proEntitled: true, ownedPackProductIDs: []))
    }

    func testConversionOverlayReachableWhenCookingEntitledEvenIfUnitsIsNot() {
        // Owning Cooking alone (Units still locked) must reach the overlay — it's the pack's own
        // cups↔ml conversion experience, not borrowed from Units.
        XCTAssertTrue(Monetization.isConversionOverlayReachable(experimentalFlagOn: false, unitsPackLocked: true, cookingPackLocked: false))
    }
}

// MARK: - Conversion overlay category scoping (fixes cross-pack category leakage)
//
// The overlay used to be reachable-or-not as a whole (see the tests above), but once reachable it
// showed *every* `UnitConverter.Category` regardless of which pack unlocked it — so a Units-only
// buyer got Cooking's volume converter for free, and vice versa. These tests cover
// `Monetization.entitledConversionCategories`, the pure helper that scopes the category picker to
// what was actually bought.
final class ConversionCategoryEntitlementTests: XCTestCase {
    // Explicitly module-qualified: Foundation bridges `NSUnitConverter` to Swift as `UnitConverter`
    // too, so a bare `UnitConverter.Category` type annotation is ambiguous once both `XCTest`
    // (→ Foundation) and `@testable import NumPad` are in scope, even though it resolves fine as
    // an expression (e.g. `UnitConverter.Category.allCases` below) since only one candidate
    // type-checks there.
    private let nonVolumeCategories: Set<NumPad.UnitConverter.Category> = [.length, .mass, .temperature]

    func testUnitsOnlyEntitlesNonVolumeCategoriesOnly() {
        let result = Monetization.entitledConversionCategories(experimentalFlagOn: false, unitsPackLocked: false, cookingPackLocked: true)
        XCTAssertEqual(result, nonVolumeCategories)
        XCTAssertFalse(result.contains(.volume))
    }

    func testCookingOnlyEntitlesVolumeOnly() {
        let result = Monetization.entitledConversionCategories(experimentalFlagOn: false, unitsPackLocked: true, cookingPackLocked: false)
        XCTAssertEqual(result, [.volume])
    }

    func testOwningBothPacksUnionsAllCategories() {
        // `Monetization.isLocked(pack:)` also returns false for both packs when the caller is
        // Pro-entitled or grandfathered, so this same (false, false) input covers those two states
        // too — indistinguishable at this pure boundary from actually owning both packs, exactly
        // like `isConversionOverlayReachable` above.
        let result = Monetization.entitledConversionCategories(experimentalFlagOn: false, unitsPackLocked: false, cookingPackLocked: false)
        XCTAssertEqual(result, Set(UnitConverter.Category.allCases))
    }

    func testExperimentalFlagUnlocksAllCategoriesEvenWhenBothPacksLocked() {
        // Un-entitled DEBUG/TestFlight testers can still exercise every category via the flag.
        let result = Monetization.entitledConversionCategories(experimentalFlagOn: true, unitsPackLocked: true, cookingPackLocked: true)
        XCTAssertEqual(result, Set(UnitConverter.Category.allCases))
    }

    func testNeitherPackNorFlagEntitlesNoCategories() {
        let result = Monetization.entitledConversionCategories(experimentalFlagOn: false, unitsPackLocked: true, cookingPackLocked: true)
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Promoted GA keyboard behaviors (Phase 3)

final class PromotedBehaviorPrefsTests: XCTestCase {
    /// The four GA prefs must use fresh keys, not the legacy ff* keys — reusing a legacy key would
    /// inherit its `false` default and ship the feature OFF (the bug we're fixing by promoting).
    func testGAPrefKeysAreDistinctFromLegacyFlags() {
        let gaKeys = [Constants.inlineCalculatorEnabled, Constants.cursorControlsEnabled,
                      Constants.smartPackDefaultingEnabled, Constants.lastResultTapeEnabled].map { $0.rawValue }
        let legacyKeys = [Constants.ffInlineCalculator, Constants.ffCursorControls,
                          Constants.ffSmartPackDefaulting, Constants.ffLastResultTape].map { $0.rawValue }
        XCTAssertEqual(Set(gaKeys).count, 4, "GA pref keys must be distinct")
        XCTAssertTrue(Set(gaKeys).isDisjoint(with: Set(legacyKeys)), "GA prefs must not reuse legacy ff* keys")
    }
}

// MARK: - iCloud sync gating (Phase 3)

final class CloudSyncTests: XCTestCase {
    func testEnabledRequiresUserOptInProAndCapability() {
        XCTAssertTrue(CloudSync.isEnabled(userEnabled: true, proEntitled: true, capabilityAvailable: true))
        XCTAssertFalse(CloudSync.isEnabled(userEnabled: false, proEntitled: true, capabilityAvailable: true))
        XCTAssertFalse(CloudSync.isEnabled(userEnabled: true, proEntitled: false, capabilityAvailable: true))
        XCTAssertFalse(CloudSync.isEnabled(userEnabled: true, proEntitled: true, capabilityAvailable: false))
    }

    func testSyncedKeysAreUniqueAndExcludeClipboard() {
        XCTAssertEqual(Set(CloudSync.syncedKeys).count, CloudSync.syncedKeys.count, "synced keys must be unique")
        // Clipboard is keychain-stored (sensitive); it must NOT be mirrored into plaintext KVS.
        XCTAssertFalse(CloudSync.syncedKeys.contains(Constants.clipboardHistory.rawValue))
        XCTAssertTrue(CloudSync.syncedKeys.contains(Constants.snippets.rawValue))
    }
}

// MARK: - 2.0 product catalog + à la carte gating (Phase 5)

final class ProductCatalogTests: XCTestCase {
    func testBasePacksHaveNoProductAndAreNeverLocked() {
        for pack in [KeyboardType.default, .math, .math2] {
            XCTAssertNil(ProductCatalog.packProductID(for: pack))
            XCTAssertTrue(ProductCatalog.isBasePack(pack))
            XCTAssertFalse(Monetization.isPackLocked(pack, proEntitled: false, ownedPackProductIDs: []))
        }
    }

    func testAllSixAlaCartePacksHaveUniqueProducts() {
        let ids = ProductCatalog.allPackProductIDs
        XCTAssertEqual(ids.count, 6, "finance, symbols, programmer, datetime, units, cooking")
        XCTAssertEqual(Set(ids).count, ids.count, "pack product IDs must be unique")
    }

    func testAlaCartePackLockedUntilOwnedOrPro() {
        let id = ProductCatalog.packProductID(for: .symbols)!
        XCTAssertTrue(Monetization.isPackLocked(.symbols, proEntitled: false, ownedPackProductIDs: []))
        XCTAssertFalse(Monetization.isPackLocked(.symbols, proEntitled: false, ownedPackProductIDs: [id]))
        XCTAssertFalse(Monetization.isPackLocked(.symbols, proEntitled: true, ownedPackProductIDs: []))
    }

    func testCustomPackIsProOnly() {
        XCTAssertTrue(ProductCatalog.isProOnlyPack(.custom))
        XCTAssertNil(ProductCatalog.packProductID(for: .custom))
        XCTAssertTrue(Monetization.isPackLocked(.custom, proEntitled: false, ownedPackProductIDs: ["numpad.pack.finance"]))
        XCTAssertFalse(Monetization.isPackLocked(.custom, proEntitled: true, ownedPackProductIDs: []))
    }

    func testAllProductIDsIncludeProAndEarlyBird() {
        XCTAssertTrue(ProductCatalog.allProductIDs.contains(ProductCatalog.pro))
        XCTAssertTrue(ProductCatalog.allProductIDs.contains(ProductCatalog.proEarlyBird))
        XCTAssertEqual(Set(ProductCatalog.allProductIDs).count, ProductCatalog.allProductIDs.count)
    }
}

// MARK: - Early-bird Pro promo (Phase 5)

final class EarlyBirdTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    func testExistingUserDetectedByAnyMarker() {
        XCTAssertTrue(EarlyBird.isExistingPreV2User(rcApplied: true, grandfatherChecked: false, firstRunUpsellShown: false, ownsAnyProduct: false))
        XCTAssertTrue(EarlyBird.isExistingPreV2User(rcApplied: false, grandfatherChecked: false, firstRunUpsellShown: false, ownsAnyProduct: true))
        XCTAssertFalse(EarlyBird.isExistingPreV2User(rcApplied: false, grandfatherChecked: false, firstRunUpsellShown: false, ownsAnyProduct: false))
    }

    func testWindowBoundaries() {
        XCTAssertTrue(EarlyBird.isWithinWindow(now: start, start: start))                                  // at start
        XCTAssertTrue(EarlyBird.isWithinWindow(now: start.addingTimeInterval(71 * 3600), start: start))
        XCTAssertFalse(EarlyBird.isWithinWindow(now: start.addingTimeInterval(72 * 3600), start: start))   // at end → closed
        XCTAssertFalse(EarlyBird.isWithinWindow(now: start.addingTimeInterval(-1), start: start))          // before start
    }

    func testOfferRequiresEligibleNonProWithinWindow() {
        let inWindow = start.addingTimeInterval(3600)
        let ts = start.timeIntervalSince1970
        XCTAssertTrue(EarlyBird.isOfferActive(now: inWindow, startTimestamp: ts, eligibleUser: true, isProEntitled: false))
        XCTAssertFalse(EarlyBird.isOfferActive(now: inWindow, startTimestamp: ts, eligibleUser: false, isProEntitled: false))
        XCTAssertFalse(EarlyBird.isOfferActive(now: inWindow, startTimestamp: ts, eligibleUser: true, isProEntitled: true))
        XCTAssertFalse(EarlyBird.isOfferActive(now: start.addingTimeInterval(73 * 3600), startTimestamp: ts, eligibleUser: true, isProEntitled: false))
        XCTAssertFalse(EarlyBird.isOfferActive(now: inWindow, startTimestamp: 0, eligibleUser: true, isProEntitled: false)) // unset start
    }

    func testNotificationOffsetsBracketTheWindow() {
        XCTAssertEqual(EarlyBird.firstNotifyAfter, 3600)
        XCTAssertEqual(EarlyBird.secondNotifyAfter, 66 * 3600)
        XCTAssertLessThan(EarlyBird.firstNotifyAfter, EarlyBird.secondNotifyAfter)
        XCTAssertLessThan(EarlyBird.secondNotifyAfter, EarlyBird.windowDuration)
    }

    func test_offerPrompt_onlyWhenEligibleActiveUnaskedUndetermined() {
        // eligible, offer active, not asked, auth not yet determined → offer
        XCTAssertTrue(EarlyBird.shouldOfferUpdatesPrompt(eligibleUser: true, offerActive: true,
            alreadyAsked: false, authDetermined: false))
        // already asked → never
        XCTAssertFalse(EarlyBird.shouldOfferUpdatesPrompt(eligibleUser: true, offerActive: true,
            alreadyAsked: true, authDetermined: false))
        // auth already determined (user decided in Settings) → don't pre-prompt
        XCTAssertFalse(EarlyBird.shouldOfferUpdatesPrompt(eligibleUser: true, offerActive: true,
            alreadyAsked: false, authDetermined: true))
        // not eligible / offer expired → never
        XCTAssertFalse(EarlyBird.shouldOfferUpdatesPrompt(eligibleUser: false, offerActive: true,
            alreadyAsked: false, authDetermined: false))
        XCTAssertFalse(EarlyBird.shouldOfferUpdatesPrompt(eligibleUser: true, offerActive: false,
            alreadyAsked: false, authDetermined: false))
    }

    /// The runtime path threads a Remote-Config-derived window through explicitly; confirm the
    /// override actually changes the outcome (and that omitting it keeps the 72h hardcoded default).
    func testOfferActiveHonorsExplicitWindowDurationOverride() {
        let ts = start.timeIntervalSince1970
        let justPastOneHour = start.addingTimeInterval(3601)
        // Default (72h) window: still active just past 1 hour in.
        XCTAssertTrue(EarlyBird.isOfferActive(now: justPastOneHour, startTimestamp: ts, eligibleUser: true, isProEntitled: false))
        // A Remote-Config-shortened 1h window: the same instant is now past the close.
        XCTAssertFalse(EarlyBird.isOfferActive(now: justPastOneHour, startTimestamp: ts, eligibleUser: true, isProEntitled: false, windowDuration: 3600))
        // A Remote-Config-lengthened window keeps the offer alive well past the hardcoded 72h.
        XCTAssertTrue(EarlyBird.isOfferActive(now: start.addingTimeInterval(100 * 3600), startTimestamp: ts, eligibleUser: true, isProEntitled: false, windowDuration: 200 * 3600))
    }
}

// MARK: - Keyboard-enablement funnel tracking + new-buyer first-run upsell (funnel-analytics phase)

final class KeyboardEnablementTrackerTests: XCTestCase {

    func testFirstEverObservationNeverLogsOrTriggersButDefersWhenAlreadyEnabled() {
        let notYetEnabled = KeyboardEnablementTracker.resolve(baselineEstablished: false, previouslyEnabled: false, nowEnabled: false, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(notYetEnabled.shouldLogKeyboardEnabled)
        XCTAssertFalse(notYetEnabled.newBuyerTriggerAvailable)
        XCTAssertFalse(notYetEnabled.nextDeferredTrigger)

        // First-ever check already finds it enabled (e.g. pre-existing install) — don't ambush the
        // very first cold launch; defer the new-buyer trigger to the next observation instead.
        let alreadyEnabled = KeyboardEnablementTracker.resolve(baselineEstablished: false, previouslyEnabled: false, nowEnabled: true, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(alreadyEnabled.shouldLogKeyboardEnabled)
        XCTAssertFalse(alreadyEnabled.newBuyerTriggerAvailable)
        XCTAssertTrue(alreadyEnabled.nextDeferredTrigger)
    }

    func testDeferredTriggerIsConsumedOnTheNextObservation() {
        let resolution = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: true, nowEnabled: true, deferredTrigger: true, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(resolution.shouldLogKeyboardEnabled) // not a live transition, so no duplicate event
        XCTAssertTrue(resolution.newBuyerTriggerAvailable)
        XCTAssertFalse(resolution.nextDeferredTrigger) // consumed, not carried forward again

        // If the keyboard somehow got disabled again before the deferred check ran, don't trigger.
        let disabledAgain = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: true, nowEnabled: false, deferredTrigger: true, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(disabledAgain.newBuyerTriggerAvailable)
    }

    func testLiveTransitionLogsOnceAndTriggersTheNewBuyerFunnel() {
        let resolution = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: false, nowEnabled: true, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertTrue(resolution.shouldLogKeyboardEnabled)
        XCTAssertTrue(resolution.newBuyerTriggerAvailable)

        // The analytics event is exactly-once-ever: a later transition never re-logs it.
        let alreadyLogged = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: false, nowEnabled: true, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: true)
        XCTAssertFalse(alreadyLogged.shouldLogKeyboardEnabled)
        XCTAssertTrue(alreadyLogged.newBuyerTriggerAvailable) // the funnel trigger is independent of the log-once flag
    }

    func testNoTransitionNeitherLogsNorTriggers() {
        let stillEnabled = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: true, nowEnabled: true, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(stillEnabled.shouldLogKeyboardEnabled)
        XCTAssertFalse(stillEnabled.newBuyerTriggerAvailable)

        let stillDisabled = KeyboardEnablementTracker.resolve(baselineEstablished: true, previouslyEnabled: false, nowEnabled: false, deferredTrigger: false, keyboardEnabledEventAlreadyLogged: false)
        XCTAssertFalse(stillDisabled.shouldLogKeyboardEnabled)
        XCTAssertFalse(stillDisabled.newBuyerTriggerAvailable)
    }
}

final class NewBuyerUpsellTests: XCTestCase {

    func testAllGatesMustPassToPresent() {
        XCTAssertTrue(NewBuyerUpsell.shouldPresent(featureEnabled: true, isProEntitled: false, earlyBirdEligible: false, alreadyShown: false, triggerAvailable: true))
    }

    func testAnySingleFailingGateBlocksPresentation() {
        XCTAssertFalse(NewBuyerUpsell.shouldPresent(featureEnabled: false, isProEntitled: false, earlyBirdEligible: false, alreadyShown: false, triggerAvailable: true)) // RC flag off
        XCTAssertFalse(NewBuyerUpsell.shouldPresent(featureEnabled: true, isProEntitled: true, earlyBirdEligible: false, alreadyShown: false, triggerAvailable: true))  // already Pro
        XCTAssertFalse(NewBuyerUpsell.shouldPresent(featureEnabled: true, isProEntitled: false, earlyBirdEligible: true, alreadyShown: false, triggerAvailable: true))  // early-bird funnel owns this user
        XCTAssertFalse(NewBuyerUpsell.shouldPresent(featureEnabled: true, isProEntitled: false, earlyBirdEligible: false, alreadyShown: true, triggerAvailable: true))  // one-shot already consumed
        XCTAssertFalse(NewBuyerUpsell.shouldPresent(featureEnabled: true, isProEntitled: false, earlyBirdEligible: false, alreadyShown: false, triggerAvailable: false)) // no trigger point yet
    }
}

final class SessionMilestoneTests: XCTestCase {

    func testPresentsOnlyAtOrAboveThreshold() {
        XCTAssertFalse(SessionMilestone.shouldPresent(sessionCount: 7, threshold: 8, isProEntitled: false, keyboardEnabled: true, alreadyShown: false))
        XCTAssertTrue(SessionMilestone.shouldPresent(sessionCount: 8, threshold: 8, isProEntitled: false, keyboardEnabled: true, alreadyShown: false))
        XCTAssertTrue(SessionMilestone.shouldPresent(sessionCount: 20, threshold: 8, isProEntitled: false, keyboardEnabled: true, alreadyShown: false))
    }

    func testOtherGatesStillApplyAtThreshold() {
        XCTAssertFalse(SessionMilestone.shouldPresent(sessionCount: 8, threshold: 8, isProEntitled: true, keyboardEnabled: true, alreadyShown: false))
        XCTAssertFalse(SessionMilestone.shouldPresent(sessionCount: 8, threshold: 8, isProEntitled: false, keyboardEnabled: false, alreadyShown: false))
        XCTAssertFalse(SessionMilestone.shouldPresent(sessionCount: 8, threshold: 8, isProEntitled: false, keyboardEnabled: true, alreadyShown: true))
    }
}

final class LockFunnelCountersSnapshotTests: XCTestCase {

    func testHasActivityIsFalseOnlyWhenAllCountersAreZero() {
        XCTAssertFalse(LockFunnelCounters.Snapshot(lockImpressions: 0, lockedKeyTaps: 0, storeDeeplinkOpens: 0).hasActivity)
        XCTAssertTrue(LockFunnelCounters.Snapshot(lockImpressions: 1, lockedKeyTaps: 0, storeDeeplinkOpens: 0).hasActivity)
        XCTAssertTrue(LockFunnelCounters.Snapshot(lockImpressions: 0, lockedKeyTaps: 3, storeDeeplinkOpens: 0).hasActivity)
        XCTAssertTrue(LockFunnelCounters.Snapshot(lockImpressions: 0, lockedKeyTaps: 0, storeDeeplinkOpens: 2).hasActivity)
    }

    func testAnalyticsAttributesAggregatesAllThreeCounts() {
        let snapshot = LockFunnelCounters.Snapshot(lockImpressions: 5, lockedKeyTaps: 2, storeDeeplinkOpens: 1)
        let attributes = snapshot.analyticsAttributes
        XCTAssertEqual(attributes["lock_impressions"] as? Int, 5)
        XCTAssertEqual(attributes["locked_key_taps"] as? Int, 2)
        XCTAssertEqual(attributes["store_deeplink_opens"] as? Int, 1)
    }
}

// MARK: - Store paywall redesign: price anchoring + upsell delta math

final class PriceAnchoringTests: XCTestCase {

    func testSumAddsAllFourAlaCartePackPrices() {
        let sum = PriceAnchoring.sum(of: [1.99, 1.99, 1.99, 1.99])
        XCTAssertEqual(sum, 7.96)
    }

    /// The pack-lineup pass's whole point: six $1.99 packs (finance, symbols, programmer,
    /// datetime, units, cooking) sum to within a dime of Pro's $11.99 — close enough that the
    /// anchoring line has to sell what Pro adds beyond the packs, not "you'll save money."
    func testSumOfAllSixAlaCartePackPricesIsNearProPrice() {
        let sum = PriceAnchoring.sum(of: [1.99, 1.99, 1.99, 1.99, 1.99, 1.99])
        XCTAssertEqual(sum, 11.94)
        let proPrice = Decimal(11.99)
        let gapBelowPro = proPrice - sum!
        XCTAssertGreaterThan(gapBelowPro, 0, "six packs should still be listed as strictly cheaper than Pro")
        XCTAssertLessThan(gapBelowPro, Decimal(0.10), "six-pack sum should land within a dime of Pro's $11.99")
    }

    func testSumIsNilWhenAnyPriceIsMissing() {
        XCTAssertNil(PriceAnchoring.sum(of: [1.99, nil, 1.99, 1.99]), "products not yet loaded from the App Store must not produce a partial total")
    }

    func testSumOfEmptyListIsZero() {
        XCTAssertEqual(PriceAnchoring.sum(of: []), 0)
    }

    func testUpgradeDeltaIsProMinusOwnedPack() {
        XCTAssertEqual(PriceAnchoring.upgradeDelta(proPrice: 11.99, ownedPackPrice: 1.99), 10.00)
    }

    func testUpgradeDeltaIsNilWhenEitherPriceIsMissing() {
        XCTAssertNil(PriceAnchoring.upgradeDelta(proPrice: nil, ownedPackPrice: 1.99))
        XCTAssertNil(PriceAnchoring.upgradeDelta(proPrice: 11.99, ownedPackPrice: nil))
    }

    func testUpgradeDeltaIsNilWhenNotAGenuineDiscount() {
        XCTAssertNil(PriceAnchoring.upgradeDelta(proPrice: 1.99, ownedPackPrice: 1.99), "equal prices must never render as a $0 upgrade")
        XCTAssertNil(PriceAnchoring.upgradeDelta(proPrice: 1.99, ownedPackPrice: 11.99), "an owned pack priced above Pro must never render as a negative upgrade")
    }
}

// MARK: - Live Math Preview

final class LiveMathPreviewTests: XCTestCase {
    func testIsActiveRequiresBothRemoteAndLocalEnabled() {
        XCTAssertTrue(LiveMathPreview.isActive(remoteEnabled: true, localEnabled: true))
        XCTAssertFalse(LiveMathPreview.isActive(remoteEnabled: false, localEnabled: true), "RC kill switch off must disable the feature even if the user has it on")
        XCTAssertFalse(LiveMathPreview.isActive(remoteEnabled: true, localEnabled: false), "user toggle off must disable the feature even if RC is on")
        XCTAssertFalse(LiveMathPreview.isActive(remoteEnabled: false, localEnabled: false))
    }
}

final class MathPreviewChipTests: XCTestCase {

    // MARK: lastCharacterCouldEndExpression (the cheap pre-guard)

    func testLastCharacterGuardAcceptsDigitsOperatorsParensAndPercent() {
        for text in ["42", "250 - 20", "250 - 20%", "(2+3", "2+3)", "2+"] {
            XCTAssertTrue(MathPreviewChip.lastCharacterCouldEndExpression(text), "'\(text)' should pass the cheap guard")
        }
    }

    func testLastCharacterGuardRejectsLettersSpacesAndEmpty() {
        // Note: this is a *cheap* pre-guard on the last character only — "pay 5" ends in a digit
        // and correctly passes it (the real parse/validation happens in `decide`, not here).
        for text in ["hello", "42 ", "pay"] {
            XCTAssertFalse(MathPreviewChip.lastCharacterCouldEndExpression(text), "'\(text)' should fail the cheap guard")
        }
        XCTAssertFalse(MathPreviewChip.lastCharacterCouldEndExpression(""))
    }

    // MARK: decide — show/hide + result

    func testDecideReturnsResultForAValidTrailingExpression() {
        let decision = MathPreviewChip.decide(textBeforeCursor: "250 - 20%")
        XCTAssertEqual(decision?.insertText, "200")
        XCTAssertEqual(decision?.displayText, "200")
        XCTAssertEqual(decision?.expression, "250 - 20%")
    }

    /// `expression` is the exact raw run of characters to delete on insert — including any leading
    /// whitespace before the expression started — matching `evaluateInlineExpression`'s own `raw`
    /// semantics, so a chip tap deletes precisely what the "=" key would have deleted.
    func testDecideCapturesOnlyTheTrailingExpressionWhenPrecededByProse() {
        let decision = MathPreviewChip.decide(textBeforeCursor: "pay 250 - 20%")
        XCTAssertEqual(decision?.insertText, "200")
        XCTAssertEqual(decision?.expression, " 250 - 20%", "the boundary space before the expression is part of the captured run")
    }

    func testDecideHidesForABareNumber() {
        // Only one operand, no operator — nothing to compute, so no chip.
        XCTAssertNil(MathPreviewChip.decide(textBeforeCursor: "42"))
        XCTAssertNil(MathPreviewChip.decide(textBeforeCursor: "just typed 115"))
    }

    func testDecideHidesForNonExpressionText() {
        XCTAssertNil(MathPreviewChip.decide(textBeforeCursor: "hello world"))
        XCTAssertNil(MathPreviewChip.decide(textBeforeCursor: ""))
    }

    func testDecideHidesForAnIncompleteExpression() {
        // Trailing operator with nothing after it isn't a valid parse yet.
        XCTAssertNil(MathPreviewChip.decide(textBeforeCursor: "5+"))
    }

    func testDecideRespectsLocaleDecimalSeparator() {
        let decision = MathPreviewChip.decide(textBeforeCursor: "1,5+2,5", decimalSeparator: ",")
        XCTAssertEqual(decision?.insertText, "4")
    }

    func testDecideGroupsLargeResultsInDisplayTextButNotInsertText() {
        let decision = MathPreviewChip.decide(textBeforeCursor: "1000000 + 234567")
        XCTAssertEqual(decision?.insertText, "1234567", "what's inserted must exactly match the '=' key's own formatting")
        XCTAssertEqual(decision?.displayText, "1,234,567", "the capsule may group for readability")
    }

    // MARK: formatter behavior (reused, single instance)

    func testDisplayTextStripsTrailingZeroLikeCalculatorFormat() {
        XCTAssertEqual(MathPreviewChip.displayText(for: 5), "5")
        XCTAssertEqual(MathPreviewChip.displayText(for: 2.5), "2.5")
    }

    func testDisplayTextHonorsCustomDecimalSeparator() {
        XCTAssertEqual(MathPreviewChip.displayText(for: 2.5, decimalSeparator: ","), "2,5")
    }

    func testDisplayTextIsStableAcrossRepeatedCalls() {
        // The formatter is a single reused static instance — calling it repeatedly (as the
        // debounced recompute does while typing) must never leak state between calls.
        XCTAssertEqual(MathPreviewChip.displayText(for: 1234.5), MathPreviewChip.displayText(for: 1234.5))
        _ = MathPreviewChip.displayText(for: 2.5, decimalSeparator: ",")
        XCTAssertEqual(MathPreviewChip.displayText(for: 2.5), "2.5", "a locale-separator call must not leak into the next default-separator call")
    }
}

final class MathPreviewCountersSnapshotTests: XCTestCase {
    func testHasActivityIsFalseOnlyWhenBothCountersAreZero() {
        XCTAssertFalse(MathPreviewCounters.Snapshot(shown: 0, inserted: 0).hasActivity)
        XCTAssertTrue(MathPreviewCounters.Snapshot(shown: 1, inserted: 0).hasActivity)
        XCTAssertTrue(MathPreviewCounters.Snapshot(shown: 0, inserted: 1).hasActivity)
    }

    func testAnalyticsAttributesAggregatesBothCounts() {
        let snapshot = MathPreviewCounters.Snapshot(shown: 5, inserted: 2)
        let attributes = snapshot.analyticsAttributes
        XCTAssertEqual(attributes["math_preview_shown"] as? Int, 5)
        XCTAssertEqual(attributes["math_preview_inserted"] as? Int, 2)
    }
}

// MARK: - Interactive first-run onboarding (WOW / ENABLE / TRY IT)

final class OnboardingFlowTests: XCTestCase {
    func testShowsForAGenuinelyFreshInstall() {
        XCTAssertTrue(OnboardingFlow.shouldShow(remoteEnabled: true, onboardingAlreadyShown: false, keyboardAlreadyEnabled: false, isExistingUser: false))
    }

    func testHiddenWhenTheRemoteKillSwitchIsOff() {
        XCTAssertFalse(OnboardingFlow.shouldShow(remoteEnabled: false, onboardingAlreadyShown: false, keyboardAlreadyEnabled: false, isExistingUser: false))
    }

    func testHiddenWhenAlreadyShownOnce() {
        XCTAssertFalse(OnboardingFlow.shouldShow(remoteEnabled: true, onboardingAlreadyShown: true, keyboardAlreadyEnabled: false, isExistingUser: false))
    }

    func testHiddenWhenTheKeyboardIsAlreadyEnabled() {
        XCTAssertFalse(OnboardingFlow.shouldShow(remoteEnabled: true, onboardingAlreadyShown: false, keyboardAlreadyEnabled: true, isExistingUser: false))
    }

    func testHiddenForAnExistingUserUpdatingEvenWithTheKeyboardStillDisabled() {
        // The exact scenario called out by spec: existing users updating must never see onboarding,
        // even if they never got around to enabling the keyboard.
        XCTAssertFalse(OnboardingFlow.shouldShow(remoteEnabled: true, onboardingAlreadyShown: false, keyboardAlreadyEnabled: false, isExistingUser: true))
    }

    func testMarkShownPersistsTheOneShotFlag() {
        UserDefaults.group.removeObject(forKey: Constants.onboardingShown.rawValue)
        XCTAssertFalse(OnboardingFlow.alreadyShown)
        OnboardingFlow.markShown()
        XCTAssertTrue(OnboardingFlow.alreadyShown)
        UserDefaults.group.removeObject(forKey: Constants.onboardingShown.rawValue)
    }
}

final class OnboardingStepTests: XCTestCase {
    func testStepsSequenceInOrderFromWowToTryIt() {
        XCTAssertEqual(OnboardingStep.wow.next, .enable)
        XCTAssertEqual(OnboardingStep.enable.next, .tryIt)
    }

    func testTryItIsTheTerminalStep() {
        XCTAssertNil(OnboardingStep.tryIt.next)
    }

    func testAnalyticsValuesAreStable() {
        XCTAssertEqual(OnboardingStep.wow.analyticsValue, "wow")
        XCTAssertEqual(OnboardingStep.enable.analyticsValue, "enable")
        XCTAssertEqual(OnboardingStep.tryIt.analyticsValue, "try_it")
    }

    func testEnableStepAutoAdvancesOnceTheKeyboardIsDetectedEnabled() {
        XCTAssertTrue(OnboardingEnableStep.shouldAutoAdvance(keyboardEnabled: true, alreadyAdvanced: false))
    }

    func testEnableStepDoesNotAdvanceWhileTheKeyboardIsStillDisabled() {
        XCTAssertFalse(OnboardingEnableStep.shouldAutoAdvance(keyboardEnabled: false, alreadyAdvanced: false))
    }

    func testEnableStepNeverRetriggersTheCelebrationOnceAlreadyAdvanced() {
        // A repeat foreground after the user has already been auto-advanced must not re-fire.
        XCTAssertFalse(OnboardingEnableStep.shouldAutoAdvance(keyboardEnabled: true, alreadyAdvanced: true))
    }
}
