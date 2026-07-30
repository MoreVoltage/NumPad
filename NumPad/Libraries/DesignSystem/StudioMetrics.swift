//
//  StudioMetrics.swift
//  NumPad
//
//  Studio design system — spacing, radii, sizing and motion.
//

import UIKit

enum StudioMetrics {

    // MARK: - Spacing

    public enum Spacing {
        public static let hair: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
        public static let xxxl: CGFloat = 40
    }

    // MARK: - Corner radii

    public enum Radius {
        /// Cards and other top-level grouping containers.
        public static let card: CGFloat = 16
        /// Selectable tiles.
        public static let tile: CGFloat = 14
        /// Buttons, segmented control track, inner containers.
        public static let control: CGFloat = 12
        /// Segment thumb, small inner chrome.
        public static let inner: CGFloat = 10
        /// Icon wells and swatches.
        public static let chip: CGFloat = 9
        /// Pill tags.
        public static let tag: CGFloat = 7
    }

    // MARK: - Sizing

    public enum Size {
        /// Apple HIG minimum interactive target.
        public static let minTouchTarget: CGFloat = 44
        public static let iconSmall: CGFloat = 15
        public static let icon: CGFloat = 18
        public static let iconLarge: CGFloat = 22
        /// Rounded well behind a row icon.
        public static let iconWell: CGFloat = 32
        /// Theme / colour swatch inside a tile.
        public static let swatch: CGFloat = 28
        /// Status hero symbol.
        public static let heroSymbol: CGFloat = 26
        /// Selected-state checkmark badge on a tile.
        public static let selectionBadge: CGFloat = 22
        /// Hairline separator thickness (device-pixel aligned).
        public static func hairline(for traits: UITraitCollection? = nil) -> CGFloat {
            let scale = (traits ?? UITraitCollection.current).displayScale
            return 1 / max(scale, 1)
        }
        /// Visible border on cards / tiles / status heroes.
        public static let border: CGFloat = 1
        /// Emphasised border for a selected tile.
        public static let borderSelected: CGFloat = 2
    }

    // MARK: - Layout

    public enum Layout {
        /// Readable content width cap so pages do not sprawl on iPad.
        public static let readableMaxWidth: CGFloat = 620
        /// Default horizontal page margin.
        public static let pageMargin: CGFloat = Spacing.l
        /// Default inset inside a card.
        public static let cardInsets = NSDirectionalEdgeInsets(
            top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l
        )
        /// Default inset inside a row.
        public static let rowInsets = NSDirectionalEdgeInsets(
            top: Spacing.m, leading: Spacing.l, bottom: Spacing.m, trailing: Spacing.l
        )
        /// Default inset inside a tile.
        public static let tileInsets = NSDirectionalEdgeInsets(
            top: Spacing.m, leading: Spacing.m, bottom: Spacing.m, trailing: Spacing.m
        )
    }

    // MARK: - Shadow

    public enum Shadow {
        public static let opacity: Float = 0.28
        public static let radius: CGFloat = 14
        public static let offset = CGSize(width: 0, height: 6)
        /// Flatter shadow for lightly raised chrome.
        public static let subtleOpacity: Float = 0.18
        public static let subtleRadius: CGFloat = 6
        public static let subtleOffset = CGSize(width: 0, height: 2)
    }

    // MARK: - Helpers

    /// Dynamic-Type-scales a metric so icon wells and paddings track text growth.
    public static func scaled(
        _ value: CGFloat,
        textStyle: UIFont.TextStyle = .body,
        compatibleWith traits: UITraitCollection? = nil
    ) -> CGFloat {
        StudioTypography.scaledValue(value, textStyle: textStyle, compatibleWith: traits)
    }

    /// `true` when the content size category is one of the accessibility sizes,
    /// i.e. when horizontal layouts should stack vertically instead of clipping.
    public static func prefersVerticalLayout(for traits: UITraitCollection) -> Bool {
        traits.preferredContentSizeCategory.isAccessibilityCategory
    }
}

// MARK: - Motion

/// Animation helpers that degrade to no animation under Reduce Motion.
enum StudioMotion {

    public static let quick: TimeInterval = 0.16
    public static let standard: TimeInterval = 0.25

    public static var isReduced: Bool { UIAccessibility.isReduceMotionEnabled }

    /// Runs `animations` with a spring, or applies them instantly under Reduce Motion.
    public static func animate(
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
    public static func pressedTransform(scale: CGFloat = 0.97) -> CGAffineTransform {
        isReduced ? .identity : CGAffineTransform(scaleX: scale, y: scale)
    }
}
