//
//  StudioTypography.swift
//  NumPad
//
//  Studio design system — type ramp.
//
//  Every font is Dynamic Type scaled via `UIFontMetrics` and respects the
//  system "Bold Text" accessibility setting. Nothing here caps the scaled
//  point size: components must grow, never clip.
//

import UIKit

enum StudioTypography {

    /// Semantic roles in the ramp. Sizes are the *unscaled* base sizes.
    enum Style: CaseIterable {
        /// Screen-owning statement heading.
        case hero
        /// Large direct page heading.
        case title
        /// Heading inside a page section or card group.
        case sectionHeading
        /// Title of a card or a row.
        case cardTitle
        /// Default running text.
        case body
        /// Supporting text under a title.
        case subtitle
        /// Fine print / helper copy.
        case footnote
        /// Smallest supporting text.
        case caption
        /// Uppercase group label above a section.
        case sectionLabel
        /// Control labels (buttons, segments).
        case button
        /// Pill tag text.
        case tag

        var textStyle: UIFont.TextStyle {
            switch self {
            case .hero: return .largeTitle
            case .title: return .title1
            case .sectionHeading: return .title3
            case .cardTitle: return .headline
            case .body: return .body
            case .subtitle: return .subheadline
            case .footnote: return .footnote
            case .caption: return .caption1
            case .sectionLabel: return .caption1
            case .button: return .headline
            case .tag: return .caption2
            }
        }

        var size: CGFloat {
            switch self {
            case .hero: return 34
            case .title: return 26
            case .sectionHeading: return 20
            case .cardTitle: return 17
            case .body: return 16
            case .subtitle: return 14
            case .footnote: return 13
            case .caption: return 12
            case .sectionLabel: return 12
            case .button: return 16
            case .tag: return 11
            }
        }

        var weight: UIFont.Weight {
            switch self {
            case .hero: return .bold
            case .title: return .semibold
            case .sectionHeading: return .semibold
            case .cardTitle: return .semibold
            case .body: return .regular
            case .subtitle: return .regular
            case .footnote: return .regular
            case .caption: return .regular
            case .sectionLabel: return .semibold
            case .button: return .semibold
            case .tag: return .semibold
            }
        }

        /// Extra letter spacing, in points at the base size.
        var tracking: CGFloat {
            switch self {
            case .sectionLabel: return 0.8
            case .tag: return 0.3
            case .hero: return -0.4
            case .title: return -0.3
            default: return 0
            }
        }
    }

    // MARK: - Fonts

    /// Dynamic-Type-scaled font for `style`, bold-text aware.
    static func font(_ style: Style, compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        let base = UIFont.systemFont(ofSize: style.size, weight: boldTextAdjusted(style.weight))
        return UIFontMetrics(forTextStyle: style.textStyle)
            .scaledFont(for: base, compatibleWith: traits)
    }

    /// Monospaced-digit variant, for values that must not jitter while updating.
    static func monospacedDigitFont(_ style: Style, compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        let base = UIFont.monospacedDigitSystemFont(ofSize: style.size, weight: boldTextAdjusted(style.weight))
        return UIFontMetrics(forTextStyle: style.textStyle)
            .scaledFont(for: base, compatibleWith: traits)
    }

    /// Scales an arbitrary point value (icon sizes, insets keyed to text).
    static func scaledValue(
        _ value: CGFloat,
        textStyle: UIFont.TextStyle = .body,
        compatibleWith traits: UITraitCollection? = nil
    ) -> CGFloat {
        UIFontMetrics(forTextStyle: textStyle).scaledValue(for: value, compatibleWith: traits)
    }

    /// Bumps a weight one step when the user has enabled Bold Text.
    static func boldTextAdjusted(_ weight: UIFont.Weight) -> UIFont.Weight {
        guard UIAccessibility.isBoldTextEnabled else { return weight }
        switch weight {
        case .ultraLight, .thin, .light, .regular: return .medium
        case .medium: return .semibold
        case .semibold: return .bold
        case .bold, .heavy, .black: return .heavy
        default: return weight
        }
    }

    // MARK: - Labels

    /// Builds a label already wired for Dynamic Type, wrapping and RTL.
    static func makeLabel(
        _ style: Style,
        color: UIColor,
        text: String? = nil,
        alignment: NSTextAlignment = .natural
    ) -> UILabel {
        let label = UILabel()
        apply(style, to: label, color: color)
        label.text = text
        label.textAlignment = alignment
        return label
    }

    /// Applies a style to an existing label without disturbing its text.
    static func apply(_ style: Style, to label: UILabel, color: UIColor? = nil) {
        label.font = font(style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        // Never shrink: growing is the correct Dynamic Type behaviour.
        label.adjustsFontSizeToFitWidth = false
        if let color { label.textColor = color }
    }

    /// Applies tracked (letter-spaced) text. Falls back to plain text when the
    /// style has no tracking, so callers can use it unconditionally.
    static func applyTracked(_ style: Style, text: String, to label: UILabel) {
        guard style.tracking != 0 else {
            label.text = text
            return
        }
        let scaledTracking = scaledValue(style.tracking, textStyle: style.textStyle)
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [.kern: scaledTracking]
        )
    }
}
