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
