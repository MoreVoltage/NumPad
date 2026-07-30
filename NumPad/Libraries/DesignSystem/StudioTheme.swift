//
//  StudioTheme.swift
//  NumPad
//
//  Studio design system — colour tokens.
//
//  This is the ONLY file in the design system that is allowed to contain raw
//  colour literals. Every component reads semantic tokens from a `StudioPalette`
//  so an area of the app (e.g. Advanced) can be re-tinted without duplicating
//  component code.
//
//  Pure presentation: UIKit + Foundation only. No app business logic.
//

import UIKit

// MARK: - Literal helpers (private to this file)

private func studioColor(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(
        red: CGFloat((hex & 0xFF0000) >> 16) / 255,
        green: CGFloat((hex & 0x00FF00) >> 8) / 255,
        blue: CGFloat(hex & 0x0000FF) / 255,
        alpha: alpha
    )
}

/// Builds a trait-resolving colour. Light/dark are both authored; the high
/// contrast variants back "Increase Contrast" (`accessibilityContrast == .high`,
/// i.e. `UIAccessibility.isDarkerSystemColorsEnabled`) and fall back to the
/// standard value when not supplied.
private func studioDynamic(
    dark: UInt32,
    light: UInt32,
    darkHighContrast: UInt32? = nil,
    lightHighContrast: UInt32? = nil,
    alpha: CGFloat = 1
) -> UIColor {
    UIColor { traits in
        let isDark = traits.userInterfaceStyle == .dark
        let wantsContrast = traits.accessibilityContrast == .high
        let resolved: UInt32
        if isDark {
            resolved = wantsContrast ? (darkHighContrast ?? dark) : dark
        } else {
            resolved = wantsContrast ? (lightHighContrast ?? light) : light
        }
        return studioColor(resolved, alpha: alpha)
    }
}

// MARK: - Palette

/// A complete set of semantic colour tokens.
///
/// Use `.standard` (the dark green NumPad identity) everywhere except the
/// Advanced area (`.advanced`, purple-tinted) and first-run onboarding
/// (`.onboarding`, light-first).
struct StudioPalette {

    /// Background / foreground pair for a pill tag.
    struct TagColors {
        let background: UIColor
        let foreground: UIColor

        init(background: UIColor, foreground: UIColor) {
            self.background = background
            self.foreground = foreground
        }
    }

    /// Colours for one state of the readiness hero.
    struct StatusColors {
        let background: UIColor
        let border: UIColor
        let foreground: UIColor
        let symbolTint: UIColor

        init(background: UIColor, border: UIColor, foreground: UIColor, symbolTint: UIColor) {
            self.background = background
            self.border = border
            self.foreground = foreground
            self.symbolTint = symbolTint
        }
    }

    // Surfaces
    let pageBackground: UIColor
    let surface: UIColor
    let surfaceElevated: UIColor
    let surfaceElevatedSecondary: UIColor
    let divider: UIColor

    // Content
    let textPrimary: UIColor
    let textSecondary: UIColor

    // Action
    let accent: UIColor
    let accentFilled: UIColor
    let accentFilledForeground: UIColor
    /// Low-energy accent wash used for secondary buttons and selected chrome.
    let accentSubtle: UIColor

    // Chrome
    let shadow: UIColor
    let scrim: UIColor
    let destructive: UIColor

    // Tags
    let tagNeutral: TagColors
    let tagGood: TagColors
    let tagWarn: TagColors
    let tagPro: TagColors

    // Status hero
    let statusOK: StatusColors
    let statusWarn: StatusColors
    let statusUnavailable: StatusColors

    init(
        pageBackground: UIColor,
        surface: UIColor,
        surfaceElevated: UIColor,
        surfaceElevatedSecondary: UIColor,
        divider: UIColor,
        textPrimary: UIColor,
        textSecondary: UIColor,
        accent: UIColor,
        accentFilled: UIColor,
        accentFilledForeground: UIColor = StudioPaletteDefaults.accentFilledForeground,
        accentSubtle: UIColor,
        shadow: UIColor = StudioPaletteDefaults.shadow,
        scrim: UIColor = StudioPaletteDefaults.scrim,
        destructive: UIColor = StudioPaletteDefaults.destructive,
        tagNeutral: TagColors = StudioPaletteDefaults.tagNeutral,
        tagGood: TagColors = StudioPaletteDefaults.tagGood,
        tagWarn: TagColors = StudioPaletteDefaults.tagWarn,
        tagPro: TagColors = StudioPaletteDefaults.tagPro,
        statusOK: StatusColors = StudioPaletteDefaults.statusOK,
        statusWarn: StatusColors = StudioPaletteDefaults.statusWarn,
        statusUnavailable: StatusColors = StudioPaletteDefaults.statusUnavailable
    ) {
        self.pageBackground = pageBackground
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.surfaceElevatedSecondary = surfaceElevatedSecondary
        self.divider = divider
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.accentFilled = accentFilled
        self.accentFilledForeground = accentFilledForeground
        self.accentSubtle = accentSubtle
        self.shadow = shadow
        self.scrim = scrim
        self.destructive = destructive
        self.tagNeutral = tagNeutral
        self.tagGood = tagGood
        self.tagWarn = tagWarn
        self.tagPro = tagPro
        self.statusOK = statusOK
        self.statusWarn = statusWarn
        self.statusUnavailable = statusUnavailable
    }
}

// MARK: - Shared defaults

/// Tag / status / chrome colours shared by every palette variant.
enum StudioPaletteDefaults {

    static let accentFilledForeground = studioDynamic(
        dark: 0xF0F7F4, light: 0xFFFFFF,
        darkHighContrast: 0xFFFFFF, lightHighContrast: 0xFFFFFF
    )

    /// Tinted toward the surface green rather than pure black.
    static let shadow = studioDynamic(dark: 0x02120D, light: 0x1C332B)

    static let scrim = studioDynamic(dark: 0x09110F, light: 0x15211E, alpha: 0.62)

    static let destructive = studioDynamic(
        dark: 0xF08A7E, light: 0xB03426,
        darkHighContrast: 0xFFB0A6, lightHighContrast: 0x8C2418
    )

    static let tagNeutral = StudioPalette.TagColors(
        background: studioDynamic(dark: 0x223730, light: 0xDCE7E2, lightHighContrast: 0xCBDAD3),
        foreground: studioDynamic(dark: 0xAED4C6, light: 0x2C4A40, darkHighContrast: 0xD3EBE1, lightHighContrast: 0x1B332C)
    )

    static let tagGood = StudioPalette.TagColors(
        background: studioDynamic(dark: 0x1B4A3C, light: 0xCFEDE0, lightHighContrast: 0xB7E2D0),
        foreground: studioDynamic(dark: 0xA9EBD4, light: 0x14563F, darkHighContrast: 0xD2F7E7, lightHighContrast: 0x0B3C2B)
    )

    static let tagWarn = StudioPalette.TagColors(
        background: studioDynamic(dark: 0x4A3D1D, light: 0xF4E7C0, lightHighContrast: 0xEDDCA5),
        foreground: studioDynamic(dark: 0xEFD989, light: 0x5C4712, darkHighContrast: 0xFAEDB6, lightHighContrast: 0x40310A)
    )

    static let tagPro = StudioPalette.TagColors(
        background: studioDynamic(dark: 0x40375E, light: 0xE4DEF9, lightHighContrast: 0xD5CCF3),
        foreground: studioDynamic(dark: 0xD7CDF8, light: 0x453A70, darkHighContrast: 0xEBE4FF, lightHighContrast: 0x2E2551)
    )

    static let statusOK = StudioPalette.StatusColors(
        background: studioDynamic(dark: 0x174B3D, light: 0xD9F0E5, lightHighContrast: 0xC2E7D6),
        border: studioDynamic(dark: 0x2B725F, light: 0x69B79C, lightHighContrast: 0x3F8E73),
        foreground: studioDynamic(dark: 0xEAFAF3, light: 0x11402F, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x082A1E),
        symbolTint: studioDynamic(dark: 0x8FE7C6, light: 0x14664C, darkHighContrast: 0xB4F3DA, lightHighContrast: 0x0A4A36)
    )

    static let statusWarn = StudioPalette.StatusColors(
        background: studioDynamic(dark: 0x3A311A, light: 0xF7EDCE, lightHighContrast: 0xF0E2B2),
        border: studioDynamic(dark: 0x685628, light: 0xC0A860, lightHighContrast: 0x9C8232),
        foreground: studioDynamic(dark: 0xFBF3DC, light: 0x453515, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x2E2209),
        symbolTint: studioDynamic(dark: 0xEFD989, light: 0x7A5F14, darkHighContrast: 0xFBEDB4, lightHighContrast: 0x5A450B)
    )

    static let statusUnavailable = StudioPalette.StatusColors(
        background: studioDynamic(dark: 0x3D2422, light: 0xF6DFDB, lightHighContrast: 0xEFCCC6),
        border: studioDynamic(dark: 0x7A4741, light: 0xC98F86, lightHighContrast: 0xA6675C),
        foreground: studioDynamic(dark: 0xFBE7E3, light: 0x4A211B, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x33130E),
        symbolTint: studioDynamic(dark: 0xF3A79B, light: 0x8E3427, darkHighContrast: 0xFFC4BA, lightHighContrast: 0x6D2519)
    )
}

// MARK: - Variants

extension StudioPalette {

    /// The default NumPad identity: deep green page, mint accent.
    static let standard = StudioPalette(
        pageBackground: studioDynamic(dark: 0x09110F, light: 0xEEF2EF, darkHighContrast: 0x040A08, lightHighContrast: 0xE6ECE9),
        surface: studioDynamic(dark: 0x101B18, light: 0xFFFFFF, darkHighContrast: 0x0A1310),
        surfaceElevated: studioDynamic(dark: 0x172521, light: 0xF5F8F6, darkHighContrast: 0x122019),
        surfaceElevatedSecondary: studioDynamic(dark: 0x1D2E29, light: 0xE8EEEB, darkHighContrast: 0x182823, lightHighContrast: 0xDDE6E2),
        divider: studioDynamic(dark: 0x2A403A, light: 0xD4DFDB, darkHighContrast: 0x496B60, lightHighContrast: 0x9DB2AA),
        textPrimary: studioDynamic(dark: 0xF0F7F4, light: 0x15211E, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x05100D),
        textSecondary: studioDynamic(dark: 0x86A097, light: 0x5F6B67, darkHighContrast: 0xB2C9C0, lightHighContrast: 0x3B4744),
        accent: studioDynamic(dark: 0x62D4B1, light: 0x16745C, darkHighContrast: 0x8FEBCC, lightHighContrast: 0x0D5643),
        accentFilled: studioDynamic(dark: 0x246B58, light: 0x206754, darkHighContrast: 0x2E8B70, lightHighContrast: 0x14503F),
        accentSubtle: studioDynamic(dark: 0x62D4B1, light: 0x16745C, alpha: 0.16)
    )

    /// Advanced area: same structure, purple identity.
    static let advanced = StudioPalette(
        pageBackground: studioDynamic(dark: 0x12101B, light: 0xF0EEF6, darkHighContrast: 0x080610, lightHighContrast: 0xE8E5F2),
        surface: studioDynamic(dark: 0x1B1729, light: 0xFFFFFF, darkHighContrast: 0x141021),
        surfaceElevated: studioDynamic(dark: 0x242036, light: 0xF7F5FC, darkHighContrast: 0x1E1930),
        surfaceElevatedSecondary: studioDynamic(dark: 0x2E2942, light: 0xEBE7F5, darkHighContrast: 0x27213B, lightHighContrast: 0xE0DBF0),
        divider: studioDynamic(dark: 0x352F4A, light: 0xDAD4EA, darkHighContrast: 0x584E77, lightHighContrast: 0xADA3C9),
        textPrimary: studioDynamic(dark: 0xF2EFF9, light: 0x191527, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x0B0817),
        textSecondary: studioDynamic(dark: 0xA79FC4, light: 0x625B7A, darkHighContrast: 0xCCC5E4, lightHighContrast: 0x413A57),
        accent: studioDynamic(dark: 0xB9AAEF, light: 0x5A4A96, darkHighContrast: 0xD3C8FA, lightHighContrast: 0x433478),
        accentFilled: studioDynamic(dark: 0x6656A3, light: 0x6656A3, darkHighContrast: 0x7D6BC4, lightHighContrast: 0x4E4083),
        accentSubtle: studioDynamic(dark: 0xB9AAEF, light: 0x5A4A96, alpha: 0.18),
        shadow: studioDynamic(dark: 0x0A0616, light: 0x2A2340)
    )

    /// First-run onboarding: light-first, warm paper feel.
    static let onboarding = StudioPalette(
        pageBackground: studioDynamic(dark: 0x09110F, light: 0xEEF2EF, darkHighContrast: 0x040A08, lightHighContrast: 0xE6ECE9),
        surface: studioDynamic(dark: 0x101B18, light: 0xFFFFFF, darkHighContrast: 0x0A1310),
        surfaceElevated: studioDynamic(dark: 0x172521, light: 0xFFFFFF, darkHighContrast: 0x122019),
        surfaceElevatedSecondary: studioDynamic(dark: 0x1D2E29, light: 0xF3F6F4, darkHighContrast: 0x182823, lightHighContrast: 0xE6ECE9),
        divider: studioDynamic(dark: 0x2A403A, light: 0xDFE6E2, darkHighContrast: 0x496B60, lightHighContrast: 0xA8BAB3),
        textPrimary: studioDynamic(dark: 0xF0F7F4, light: 0x15211E, darkHighContrast: 0xFFFFFF, lightHighContrast: 0x05100D),
        textSecondary: studioDynamic(dark: 0x86A097, light: 0x5F6B67, darkHighContrast: 0xB2C9C0, lightHighContrast: 0x3B4744),
        accent: studioDynamic(dark: 0x62D4B1, light: 0x206754, darkHighContrast: 0x8FEBCC, lightHighContrast: 0x0D4A39),
        accentFilled: studioDynamic(dark: 0x246B58, light: 0x206754, darkHighContrast: 0x2E8B70, lightHighContrast: 0x14503F),
        accentSubtle: studioDynamic(dark: 0x62D4B1, light: 0x206754, alpha: 0.14)
    )
}

// MARK: - StudioTheme

/// Namespace exposing the standard palette's semantic tokens directly, for the
/// (common) case where a call site does not need a variant.
enum StudioTheme {

    /// The palette components fall back to when none is injected.
    static let standard = StudioPalette.standard
    static let advanced = StudioPalette.advanced
    static let onboarding = StudioPalette.onboarding

    static var pageBackground: UIColor { standard.pageBackground }
    static var surface: UIColor { standard.surface }
    static var surfaceElevated: UIColor { standard.surfaceElevated }
    static var surfaceElevatedSecondary: UIColor { standard.surfaceElevatedSecondary }
    static var divider: UIColor { standard.divider }
    static var textPrimary: UIColor { standard.textPrimary }
    static var textSecondary: UIColor { standard.textSecondary }
    static var accent: UIColor { standard.accent }
    static var accentFilled: UIColor { standard.accentFilled }
    static var accentFilledForeground: UIColor { standard.accentFilledForeground }
    static var accentSubtle: UIColor { standard.accentSubtle }
    static var shadow: UIColor { standard.shadow }
    static var scrim: UIColor { standard.scrim }
    static var destructive: UIColor { standard.destructive }
}
