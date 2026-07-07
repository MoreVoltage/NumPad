import UIKit

/// Key-color roles for the QWERTY keyboard under a `KeyboardTheme`. White/black are the
/// system-parity palettes (§0.1 baseline — the values the Phase-3 screenshot-diff measures
/// against); every other theme tints keys with its color, matching how the numpad renders
/// themes. Glass themes keep their built-in translucency (`Color.glass` carries reduced
/// alpha), which is the same pre-iOS-26 fallback the numpad uses.
///
/// Pure mapping (no stored state, no UserDefaults) so it's unit-testable; callers pass the
/// resolved theme (`KeyboardTheme.selectedOrAutomatic`).
struct QwertyThemePalette: Equatable {
    let plainFill: UIColor
    let specialFill: UIColor
    let text: UIColor

    /// System keyboard, light appearance.
    static let systemLight = QwertyThemePalette(
        plainFill: .white,
        specialFill: UIColor(red: 0.68, green: 0.71, blue: 0.75, alpha: 1),
        text: .black)

    /// System keyboard, dark appearance.
    static let systemDark = QwertyThemePalette(
        plainFill: UIColor(white: 0.42, alpha: 1),
        specialFill: UIColor(white: 0.28, alpha: 1),
        text: .white)

    static func palette(for theme: KeyboardTheme) -> QwertyThemePalette {
        switch theme {
        case .white:
            return systemLight
        case .black:
            return systemDark
        default:
            let base = theme.color
            return QwertyThemePalette(plainFill: base,
                                      specialFill: darkened(base),
                                      text: isLight(base) ? .black : .white)
        }
    }

    /// Perceived-luminance check (ITU-R BT.601 weights) for text contrast.
    static func isLight(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (0.299 * red + 0.587 * green + 0.114 * blue) > 0.6
    }

    /// The special-key shade: the theme color dimmed, alpha preserved (glass stays glass).
    private static func darkened(_ color: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * 0.78, green: green * 0.78, blue: blue * 0.78, alpha: alpha)
    }
}
