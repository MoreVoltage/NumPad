import XCTest
import DynamicColor
@testable import NumPad

final class QwertyThemePaletteTests: XCTestCase {

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    // MARK: white/black are the system-parity palettes (§0.1 baseline)

    func testWhiteThemeIsSystemLightParity() {
        let palette = QwertyThemePalette.palette(for: .white)
        XCTAssertEqual(palette.plainFill, QwertyThemePalette.systemLight.plainFill)
        XCTAssertEqual(palette.text, QwertyThemePalette.systemLight.text)
    }

    func testBlackThemeIsSystemDarkParity() {
        let palette = QwertyThemePalette.palette(for: .black)
        XCTAssertEqual(palette.plainFill, QwertyThemePalette.systemDark.plainFill)
        XCTAssertEqual(palette.text, QwertyThemePalette.systemDark.text)
    }

    // MARK: colored themes tint the keys, special keys darker, text by contrast

    func testColoredThemePlainFillIsTheThemeColor() {
        let palette = QwertyThemePalette.palette(for: .red)
        XCTAssertEqual(palette.plainFill, KeyboardTheme.red.color)
    }

    func testSpecialFillIsDarkerThanPlainFill() {
        for theme in [KeyboardTheme.red, .teal, .yellow, .indigo] {
            let palette = QwertyThemePalette.palette(for: theme)
            let plain = components(palette.plainFill)
            let special = components(palette.specialFill)
            XCTAssertLessThan(special.r + special.g + special.b,
                              plain.r + plain.g + plain.b,
                              "\(theme) special keys must read darker than plain keys")
        }
    }

    func testTextContrastFollowsLuminance() {
        XCTAssertEqual(QwertyThemePalette.palette(for: .indigo).text, .white,
                       "dark key color needs light text")
        XCTAssertEqual(QwertyThemePalette.palette(for: .yellow).text, .black,
                       "light key color needs dark text")
    }

    // MARK: glass keeps its translucency (the pre-iOS-26 fallback path)

    func testGlassThemesPreserveAlpha() {
        for theme in [KeyboardTheme.glass, .glassDark] {
            let palette = QwertyThemePalette.palette(for: theme)
            XCTAssertLessThan(components(palette.plainFill).a, 1.0,
                              "\(theme) keys render translucent")
        }
    }

    // MARK: background matches the numpad's own grid/border tone (owner note 3 — one canvas)

    func testWhiteThemeBackgroundMatchesNumpadBorderFormula() {
        let palette = QwertyThemePalette.palette(for: .white)
        XCTAssertEqual(palette.background, UIColor.white.darkened(amount: 0.1))
    }

    func testBlackThemeBackgroundMatchesNumpadBorderFormula() {
        let palette = QwertyThemePalette.palette(for: .black)
        XCTAssertEqual(palette.background, UIColor.black.lighter(amount: 0.2))
    }

    func testColoredThemeBackgroundMatchesNumpadBorderFormula() {
        let palette = QwertyThemePalette.palette(for: .red)
        XCTAssertEqual(palette.background, KeyboardTheme.red.color.lighter(amount: 0.1))
    }

    func testGlassThemeBackgroundPreservesAlpha() {
        for theme in [KeyboardTheme.glass, .glassDark] {
            let palette = QwertyThemePalette.palette(for: theme)
            XCTAssertLessThan(components(palette.background).a, 1.0,
                              "\(theme) background must stay translucent like its key fills")
        }
    }

    // MARK: luminance helper

    func testIsLightColor() {
        XCTAssertTrue(QwertyThemePalette.isLight(.white))
        XCTAssertTrue(QwertyThemePalette.isLight(.yellow))
        XCTAssertFalse(QwertyThemePalette.isLight(.black))
        XCTAssertFalse(QwertyThemePalette.isLight(UIColor(red: 0.2, green: 0.1, blue: 0.5, alpha: 1)))
    }
}
