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
    func testBaseHeights() {
        XCTAssertEqual(KeyboardHeightPreset.small.baseHeight, 260)
        XCTAssertEqual(KeyboardHeightPreset.regular.baseHeight, 300)
        XCTAssertEqual(KeyboardHeightPreset.tall.baseHeight, 340)
    }

    func testUnknownRawValueFallsBackToRegular() {
        XCTAssertNil(KeyboardHeightPreset(rawValue: "huge"))
        // `selected` getter falls back to .regular for unknown stored values; the raw-value
        // round-trip below is what protects renames.
        for preset in KeyboardHeightPreset.allCases {
            XCTAssertEqual(KeyboardHeightPreset(rawValue: preset.rawValue), preset)
        }
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
    private let legacyDecodeOnlyPacks: [KeyboardType] = [.units, .scientific, .business, .programmerPlus, .international]

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

    func testAllFourAlaCartePacksHaveUniqueProducts() {
        let ids = ProductCatalog.allPackProductIDs
        XCTAssertEqual(ids.count, 4, "finance, symbols, programmer, datetime")
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
}
