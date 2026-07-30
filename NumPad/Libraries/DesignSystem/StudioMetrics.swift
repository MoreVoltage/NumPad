//
//  StudioMetrics.swift
//  NumPad
//
//  Studio design system — spacing, radii, sizing and motion.
//

import UIKit

enum StudioMetrics {

    // MARK: - Spacing

    enum Spacing {
        static let hair: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
    }

    // MARK: - Corner radii

    enum Radius {
        /// Cards and other top-level grouping containers.
        static let card: CGFloat = 16
        /// Selectable tiles.
        static let tile: CGFloat = 14
        /// Buttons, segmented control track, inner containers.
        static let control: CGFloat = 12
        /// Segment thumb, small inner chrome.
        static let inner: CGFloat = 10
        /// Icon wells and swatches.
        static let chip: CGFloat = 9
        /// Pill tags.
        static let tag: CGFloat = 7
    }

    // MARK: - Sizing

    enum Size {
        /// Apple HIG minimum interactive target.
        static let minTouchTarget: CGFloat = 44
        static let iconSmall: CGFloat = 15
        static let icon: CGFloat = 18
        static let iconLarge: CGFloat = 22
        /// Rounded well behind a row icon.
        static let iconWell: CGFloat = 32
        /// Theme / colour swatch inside a tile.
        static let swatch: CGFloat = 28
        /// Status hero symbol.
        static let heroSymbol: CGFloat = 26
        /// Selected-state checkmark badge on a tile.
        static let selectionBadge: CGFloat = 22
        /// Hairline separator thickness (device-pixel aligned).
        static func hairline(for traits: UITraitCollection? = nil) -> CGFloat {
            let scale = (traits ?? UITraitCollection.current).displayScale
            return 1 / max(scale, 1)
        }
        /// Visible border on cards / tiles / status heroes.
        static let border: CGFloat = 1
        /// Emphasised border for a selected tile.
        static let borderSelected: CGFloat = 2
    }

    // MARK: - Layout

    enum Layout {
        /// Readable content width cap so pages do not sprawl on iPad.
        static let readableMaxWidth: CGFloat = 620
        /// Default horizontal page margin.
        static let pageMargin: CGFloat = Spacing.l
        /// Default inset inside a card.
        static let cardInsets = NSDirectionalEdgeInsets(
            top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l
        )
        /// Default inset inside a row.
        static let rowInsets = NSDirectionalEdgeInsets(
            top: Spacing.m, leading: Spacing.l, bottom: Spacing.m, trailing: Spacing.l
        )
        /// Default inset inside a tile.
        static let tileInsets = NSDirectionalEdgeInsets(
            top: Spacing.m, leading: Spacing.m, bottom: Spacing.m, trailing: Spacing.m
        )
    }

    // MARK: - Shadow

    enum Shadow {
        static let opacity: Float = 0.28
        static let radius: CGFloat = 14
        static let offset = CGSize(width: 0, height: 6)
        /// Flatter shadow for lightly raised chrome.
        static let subtleOpacity: Float = 0.18
        static let subtleRadius: CGFloat = 6
        static let subtleOffset = CGSize(width: 0, height: 2)
    }

    // MARK: - Helpers

    /// Dynamic-Type-scales a metric so icon wells and paddings track text growth.
    static func scaled(
        _ value: CGFloat,
        textStyle: UIFont.TextStyle = .body,
        compatibleWith traits: UITraitCollection? = nil
    ) -> CGFloat {
        StudioTypography.scaledValue(value, textStyle: textStyle, compatibleWith: traits)
    }

    /// `true` when the content size category is one of the accessibility sizes,
    /// i.e. when horizontal layouts should stack vertically instead of clipping.
    static func prefersVerticalLayout(for traits: UITraitCollection) -> Bool {
        traits.preferredContentSizeCategory.isAccessibilityCategory
    }
}

// MARK: - Motion

/// Animation helpers that degrade to no animation under Reduce Motion.
enum StudioMotion {

    static let quick: TimeInterval = 0.16
    static let standard: TimeInterval = 0.25

    static var isReduced: Bool { UIAccessibility.isReduceMotionEnabled }

    /// Runs `animations` with a spring, or applies them instantly under Reduce Motion.
    static func animate(
        duration: TimeInterval = standard,
        delay: TimeInterval = 0,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isReduced else {
            animations()
            completion?(true)
            return
        }
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: animations,
            completion: completion
        )
    }

    /// Press-feedback transform. Identity under Reduce Motion.
    static func pressedTransform(scale: CGFloat = 0.97) -> CGAffineTransform {
        isReduced ? .identity : CGAffineTransform(scaleX: scale, y: scale)
    }
}
