import XCTest
@testable import NumPad

/// Liquid Glass premium theme catalog tests: the new "Glass"/"Glass Dark" cases exist, are
/// premium-gated, and their base colors carry the translucent alpha the theme recipe's fallback
/// rendering (both the keyboard extension's <iOS 26 path and the app-side preview) depends on.
final class KeyboardThemeTests: XCTestCase {

    func testGlassThemesArePresentInAllCases() {
        XCTAssertTrue(KeyboardTheme.allCases.contains(.glass))
        XCTAssertTrue(KeyboardTheme.allCases.contains(.glassDark))
    }

    func testGlassThemesRoundTripByRawValue() {
        XCTAssertEqual(KeyboardTheme(rawValue: "glass"), .glass)
        XCTAssertEqual(KeyboardTheme(rawValue: "glassDark"), .glassDark)
    }

    func testGlassThemesArePremiumGated() {
        XCTAssertTrue(KeyboardTheme.glass.isPremium)
        XCTAssertTrue(KeyboardTheme.glassDark.isPremium)
        XCTAssertTrue(KeyboardTheme.premiumThemes.contains(.glass))
        XCTAssertTrue(KeyboardTheme.premiumThemes.contains(.glassDark))
    }

    func testIsGlassIdentifiesOnlyTheGlassPair() {
        XCTAssertTrue(KeyboardTheme.glass.isGlass)
        XCTAssertTrue(KeyboardTheme.glassDark.isGlass)
        for theme in KeyboardTheme.allCases where theme != .glass && theme != .glassDark {
            XCTAssertFalse(theme.isGlass, "\(theme.rawValue) must not identify as a glass theme")
        }
    }

    /// Every case must resolve to *some* color with no crash — a lightweight guard against a case
    /// added to the enum without a matching `color` mapping. Also doubles as a live total-count
    /// check for the Store hero swatch strip and the theme picker grid, both of which iterate
    /// `allCases`/`premiumThemes` at runtime.
    func testAllCasesHaveAColorMapping() {
        let colors = KeyboardTheme.allCases.map { $0.color }
        XCTAssertEqual(colors.count, KeyboardTheme.allCases.count)
    }

    func testThemeCatalogTotalsAfterGlassAddition() {
        // 17 original cases + the Glass/Glass Dark pair.
        XCTAssertEqual(KeyboardTheme.allCases.count, 19)
        // 5 original premium themes + the Glass/Glass Dark pair.
        XCTAssertEqual(KeyboardTheme.premiumThemes.count, 7)
    }

    /// The theme recipe's twist: `Color.glass`/`Color.glassDark` are translucent (unlike every
    /// other flat swatch), which is what lets the *same* color double as the <iOS 26 fallback and
    /// the base tint for the real iOS 26 glass material (see `KeyboardViewController
    /// .applyGlassBackdrop`). Locks in that design choice so a future edit can't silently make
    /// these opaque and break the fallback.
    func testGlassColorsAreTranslucent() {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(KeyboardTheme.glass.color.getWhite(&white, alpha: &alpha))
        XCTAssertLessThan(alpha, 1, "Color.glass must stay translucent for the blur/fallback to read through")

        XCTAssertTrue(KeyboardTheme.glassDark.color.getWhite(&white, alpha: &alpha))
        XCTAssertLessThan(alpha, 1, "Color.glassDark must stay translucent for the blur/fallback to read through")
    }

    /// Glass is the *light* half of the pair and Glass Dark the *dark* half — this drives which
    /// foreground text color `UIColor.itemScheme` picks (via alpha-blind `isLight()`), so a
    /// regression here would make the wrong theme render illegible key labels.
    func testGlassIsLightAndGlassDarkIsDark() {
        var glassWhite: CGFloat = 0, glassAlpha: CGFloat = 0
        var darkWhite: CGFloat = 0, darkAlpha: CGFloat = 0
        XCTAssertTrue(KeyboardTheme.glass.color.getWhite(&glassWhite, alpha: &glassAlpha))
        XCTAssertTrue(KeyboardTheme.glassDark.color.getWhite(&darkWhite, alpha: &darkAlpha))
        XCTAssertGreaterThanOrEqual(glassWhite, 0.5, "Glass must be light enough for black foreground text")
        XCTAssertLessThan(darkWhite, 0.5, "Glass Dark must be dark enough for white foreground text")
    }

    func testGlassThemeNamesAreExplicitlyMappedNotCapitalizedRawValue() {
        // `.glassDark.rawValue.capitalized` would wrongly produce "Glassdark" (capitalized() only
        // uppercases the first letter of the whole string, not each camelCase word) — these assert
        // the explicit `name` cases are actually hit, mirroring `.deepPurple` / `.lightBlue` etc.
        XCTAssertEqual(KeyboardTheme.glass.name, "Glass")
        XCTAssertEqual(KeyboardTheme.glassDark.name, "Glass Dark")
    }
}

/// The key-press micro-interaction has the same two-switch shape as `dragReorderActive` /
/// `LiveMathPreview.isActive`: a local escape hatch (default ON) ANDed with a Remote Config kill
/// switch mirrored into the app group, since the Keyboard extension has no Firebase Remote Config
/// of its own.
final class KeyPressAnimationGateTests: XCTestCase {
    func testActiveOnlyWhenBothRemoteConfigAndLocalFlagAreEnabled() {
        XCTAssertTrue(FeatureFlags.keyPressAnimationActive(remoteEnabled: true, localEnabled: true))
    }

    func testRemoteConfigKillSwitchOverridesLocalFlagEnabled() {
        XCTAssertFalse(FeatureFlags.keyPressAnimationActive(remoteEnabled: false, localEnabled: true), "RC kill switch off must disable the animation even if the local flag is on")
    }

    func testLocalFlagOffStaysOffEvenWhenRemoteConfigEnabled() {
        XCTAssertFalse(FeatureFlags.keyPressAnimationActive(remoteEnabled: true, localEnabled: false), "local flag off must disable the animation even if RC is on")
    }

    func testBothDisabledStaysOff() {
        XCTAssertFalse(FeatureFlags.keyPressAnimationActive(remoteEnabled: false, localEnabled: false))
    }
}
