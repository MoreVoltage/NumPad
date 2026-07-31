import Foundation
import CoreGraphics
import UIKit

enum QwertyLayoutGeometry {
    static let regularPadMaxWidth: CGFloat = 720
    static let compactPadMaxWidth: CGFloat = 420
    static let narrowPadWidth: CGFloat = 700
    static let minimumSplitGap: CGFloat = 96

    struct RowFrames: Equatable {
        let frames: [CGRect]
    }

    struct Layout: Equatable {
        let mode: QwertyLayoutMode
        let contentFrame: CGRect
        let rows: [RowFrames]
        /// Regions where zero-dead-zone routing is allowed. In split mode the upper rows
        /// deliberately omit the thumb gap; the continuous command row remains interactive.
        let hitRegions: [CGRect]
        let splitGap: CGRect?
    }

    static func resolvedMode(preference: QwertyLayoutMode,
                             bounds: CGRect,
                             idiom: UIUserInterfaceIdiom,
                             horizontalSizeClass: UIUserInterfaceSizeClass?,
                             isFloating: Bool) -> QwertyLayoutMode {
        guard idiom == .pad else { return .automatic }
        let isNarrow = bounds.width < narrowPadWidth || horizontalSizeClass == .compact
        if isFloating || isNarrow {
            switch preference {
            case .compactRight:
                return .compactRight
            default:
                // A narrow/floating canvas is already at or below the compact width. Pinning
                // left is deterministic and preserves all available width.
                return .compactLeft
            }
        }
        return preference == .automatic ? .centered : preference
    }

    static func contentWidth(bounds: CGRect,
                             mode: QwertyLayoutMode,
                             idiom: UIUserInterfaceIdiom) -> CGFloat {
        guard idiom == .pad else { return bounds.width }
        switch mode {
        case .automatic:
            return bounds.width
        case .centered:
            return min(bounds.width, regularPadMaxWidth)
        case .compactLeft, .compactRight:
            return min(bounds.width, compactPadMaxWidth)
        case .split:
            return bounds.width
        }
    }

    static func contentOriginX(bounds: CGRect,
                               mode: QwertyLayoutMode,
                               idiom: UIUserInterfaceIdiom) -> CGFloat {
        let width = contentWidth(bounds: bounds, mode: mode, idiom: idiom)
        switch mode {
        case .compactLeft:
            return bounds.minX
        case .compactRight:
            return bounds.maxX - width
        case .automatic, .centered, .split:
            return bounds.midX - width / 2
        }
    }

    static func contentFrame(bounds: CGRect,
                             mode: QwertyLayoutMode,
                             idiom: UIUserInterfaceIdiom) -> CGRect {
        CGRect(
            x: contentOriginX(bounds: bounds, mode: mode, idiom: idiom),
            y: bounds.minY,
            width: contentWidth(bounds: bounds, mode: mode, idiom: idiom),
            height: bounds.height
        )
    }

    /// Pure frame resolver used by the production QWERTY view on every layout pass.
    /// The default insets exactly match the pre-iPad manual layout, preserving phone
    /// automatic geometry point-for-point.
    static func layout(bounds: CGRect,
                       rows: [QwertyRow],
                       mode: QwertyLayoutMode,
                       idiom: UIUserInterfaceIdiom,
                       keyGap: CGFloat,
                       rowGap: CGFloat,
                       edgeInset: CGFloat = 3,
                       topInset: CGFloat = 6,
                       bottomInset: CGFloat = 4) -> Layout {
        let content = contentFrame(bounds: bounds, mode: mode, idiom: idiom)
        guard !rows.isEmpty, content.width > 0, content.height > 0 else {
            return Layout(mode: mode,
                          contentFrame: content,
                          rows: rows.map { _ in RowFrames(frames: []) },
                          hitRegions: [],
                          splitGap: nil)
        }

        let usableHeight = max(content.height - topInset - bottomInset, 0)
        let rowSlotHeight = usableHeight / CGFloat(rows.count)
        let bottomRowOriginY = content.minY + topInset
            + CGFloat(max(rows.count - 1, 0)) * rowSlotHeight

        if idiom == .pad, mode == .split {
            let gapWidth = min(140, max(minimumSplitGap, content.width * 0.12))
            let gap = CGRect(
                x: content.midX - gapWidth / 2,
                y: content.minY + topInset,
                width: gapWidth,
                height: max(bottomRowOriginY - (content.minY + topInset), 0)
            )
            let leftRegion = CGRect(
                x: content.minX + edgeInset,
                y: content.minY,
                width: max(gap.minX - (content.minX + edgeInset), 0),
                height: content.height
            )
            let rightRegion = CGRect(
                x: gap.maxX,
                y: content.minY,
                width: max(content.maxX - edgeInset - gap.maxX, 0),
                height: content.height
            )

            let rowFrames = rows.enumerated().map { rowIndex, row -> RowFrames in
                let y = content.minY + topInset + CGFloat(rowIndex) * rowSlotHeight + rowGap / 2
                let height = max(rowSlotHeight - rowGap, 0)
                if rowIndex == rows.count - 1 {
                    return RowFrames(frames: standardFrames(
                        for: row,
                        content: content,
                        y: y,
                        height: height,
                        keyGap: keyGap,
                        edgeInset: edgeInset
                    ))
                }
                let splitIndex = (row.keys.count + 1) / 2
                let leftKeys = Array(row.keys[..<splitIndex])
                let rightKeys = Array(row.keys[splitIndex...])
                return RowFrames(frames:
                    fillFrames(for: leftKeys, in: leftRegion, y: y, height: height, keyGap: keyGap)
                    + fillFrames(for: rightKeys, in: rightRegion, y: y, height: height, keyGap: keyGap)
                )
            }
            let upperHeight = max(bottomRowOriginY - content.minY, 0)
            let hitRegions = [
                CGRect(x: content.minX,
                       y: content.minY,
                       width: max(gap.minX - content.minX, 0),
                       height: upperHeight),
                CGRect(x: gap.maxX,
                       y: content.minY,
                       width: max(content.maxX - gap.maxX, 0),
                       height: upperHeight),
                CGRect(x: content.minX,
                       y: bottomRowOriginY,
                       width: content.width,
                       height: max(content.maxY - bottomRowOriginY, 0)),
            ].filter { !$0.isEmpty }
            return Layout(mode: mode,
                          contentFrame: content,
                          rows: rowFrames,
                          hitRegions: hitRegions,
                          splitGap: gap)
        }

        let rowFrames = rows.enumerated().map { rowIndex, row in
            let y = content.minY + topInset + CGFloat(rowIndex) * rowSlotHeight + rowGap / 2
            return RowFrames(frames: standardFrames(
                for: row,
                content: content,
                y: y,
                height: max(rowSlotHeight - rowGap, 0),
                keyGap: keyGap,
                edgeInset: edgeInset
            ))
        }
        return Layout(mode: mode,
                      contentFrame: content,
                      rows: rowFrames,
                      hitRegions: [content],
                      splitGap: nil)
    }

    private static func standardFrames(for row: QwertyRow,
                                       content: CGRect,
                                       y: CGFloat,
                                       height: CGFloat,
                                       keyGap: CGFloat,
                                       edgeInset: CGFloat) -> [CGRect] {
        let unitWidth = max(content.width - 2 * edgeInset, 0)
            / CGFloat(QwertyLayout.rowUnitWidth)
        var cursorUnits = row.leadingMargin
        return row.keys.map { key in
            let slotX = content.minX + edgeInset + CGFloat(cursorUnits) * unitWidth
            let slotWidth = CGFloat(key.width) * unitWidth
            cursorUnits += key.width
            return CGRect(
                x: slotX + keyGap / 2,
                y: y,
                width: max(slotWidth - keyGap, 0),
                height: height
            )
        }
    }

    private static func fillFrames(for keys: [QwertyKey],
                                   in region: CGRect,
                                   y: CGFloat,
                                   height: CGFloat,
                                   keyGap: CGFloat) -> [CGRect] {
        let totalUnits = keys.reduce(0.0) { $0 + $1.width }
        guard totalUnits > 0 else { return [] }
        let unitWidth = region.width / CGFloat(totalUnits)
        var cursor: Double = 0
        return keys.map { key in
            let slotX = region.minX + CGFloat(cursor) * unitWidth
            let slotWidth = CGFloat(key.width) * unitWidth
            cursor += key.width
            return CGRect(
                x: slotX + keyGap / 2,
                y: y,
                width: max(slotWidth - keyGap, 0),
                height: height
            )
        }
    }
}

/// Horizontal composition for the two supported iPad QWERTY presentations. This owns only
/// pane frames: existing keyboard-height logic remains the sole owner of vertical sizing.
enum IPadKeyboardCompositionGeometry {
    static let qwertyShare: CGFloat = 0.68
    static let paneGap: CGFloat = 8

    struct Layout: Equatable {
        let qwertyFrame: CGRect
        let numpadFrame: CGRect?
    }

    struct CalculatorOverlayLayout: Equatable {
        /// The upper part of the NumPad pane occupied by Tax/Tip or Conversion.
        let overlayFrame: CGRect
        /// The lower part left unobscured for calculator-routed numpad keys.
        let inputFrame: CGRect
    }

    static func resolve(
        bounds: CGRect,
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        layout: IPadQwertyLayout,
        numpadSide: FullKeyboardNumpadSide,
        isFloating: Bool = false
    ) -> Layout {
        let usesStandardComposition = layout == .standard
            || idiom != .pad
            || horizontalSizeClass == .compact
            || isFloating
            || bounds.width < NumpadGeometry.narrowPadWidth
        guard !usesStandardComposition else {
            return Layout(qwertyFrame: bounds, numpadFrame: nil)
        }

        let qwertyWidth = bounds.width * qwertyShare
        let numpadWidth = max(bounds.width - qwertyWidth - paneGap, 0)
        switch numpadSide {
        case .left:
            let numpadFrame = CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: numpadWidth,
                height: bounds.height
            )
            return Layout(
                qwertyFrame: CGRect(
                    x: numpadFrame.maxX + paneGap,
                    y: bounds.minY,
                    width: qwertyWidth,
                    height: bounds.height
                ),
                numpadFrame: numpadFrame
            )
        case .right:
            let qwertyFrame = CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: qwertyWidth,
                height: bounds.height
            )
            return Layout(
                qwertyFrame: qwertyFrame,
                numpadFrame: CGRect(
                    x: qwertyFrame.maxX + paneGap,
                    y: bounds.minY,
                    width: numpadWidth,
                    height: bounds.height
                )
            )
        }
    }

    static func shouldForceNumberStrip(idiom: UIUserInterfaceIdiom,
                                       layout: IPadQwertyLayout) -> Bool {
        idiom == .pad && (layout == .standard || layout == .full)
    }

    /// Full Keyboard overlays replace only the real side numpad's visible area. Standard has no
    /// side pane, so its established top-band/side-panel presentation remains unchanged.
    static func overlayFrame(for layout: Layout, verticalInset: CGFloat) -> CGRect? {
        guard let numpadFrame = layout.numpadFrame else { return nil }
        return numpadFrame.insetBy(dx: 0, dy: verticalInset)
    }

    /// Calculator overlays must retain a lower NumPad input surface: digits, delete, and return
    /// continue routing into their amount field while the upper pane hosts the calculator controls.
    static func calculatorOverlayLayout(for layout: Layout,
                                        verticalInset: CGFloat) -> CalculatorOverlayLayout? {
        guard let numpadFrame = layout.numpadFrame else { return nil }
        let usableFrame = numpadFrame.insetBy(dx: 0, dy: verticalInset)
        let overlayFrame = CGRect(
            x: usableFrame.minX,
            y: usableFrame.minY,
            width: usableFrame.width,
            height: usableFrame.height * 0.5
        )
        let inputFrame = CGRect(
            x: numpadFrame.minX,
            y: overlayFrame.maxY,
            width: numpadFrame.width,
            height: numpadFrame.maxY - overlayFrame.maxY
        )
        return CalculatorOverlayLayout(overlayFrame: overlayFrame, inputFrame: inputFrame)
    }
}

/// Shared classification of keys the calculator overlays accept. The extension owns the actual
/// callbacks, while this pure seam lets both targets verify that digit, delete, and return/apply
/// actions stay available independent of a particular overlay's frame.
enum CalculatorOverlayInputRouting {
    enum Action: Equatable {
        case append(String)
        case delete
        case apply
        case ignore
    }

    static func action(title: String?, imageName: String?, isReturnKey: Bool) -> Action {
        if isReturnKey { return .apply }
        switch (title, imageName) {
        case (let title?, _) where ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", ","].contains(title):
            return .append(title)
        case (_, "back"?):
            return .delete
        default:
            return .ignore
        }
    }
}

enum NumpadGeometry {
    static let regularPadMaxWidth: CGFloat = 560
    static let narrowPadWidth: CGFloat = 700

    struct ConstraintLayout: Equatable {
        let resolvedPlacement: NumpadPlacement
        let contentFrame: CGRect
        let leadingConstant: CGFloat
        let trailingConstant: CGFloat
    }

    /// Resolves the selected iPad numpad width without owning or changing any vertical geometry.
    /// Phone, compact, narrow, and floating contexts retain the existing full-width behavior.
    static func resolve(
        width: NumpadWidthSize,
        bounds: CGRect,
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        isFloating: Bool
    ) -> ConstraintLayout {
        let fallsBackToFullWidth = idiom != .pad
            || isFloating
            || horizontalSizeClass == .compact
            || bounds.width < narrowPadWidth
        let resolvedWidth = fallsBackToFullWidth ? bounds.width : bounds.width * width.fraction
        let frame = CGRect(
            x: bounds.midX - resolvedWidth / 2,
            y: bounds.minY,
            width: resolvedWidth,
            height: bounds.height
        )
        let leading = frame.minX - bounds.minX
        let trailing = frame.maxX - bounds.maxX
        return ConstraintLayout(
            resolvedPlacement: fallsBackToFullWidth ? .fullWidth : .center,
            contentFrame: frame,
            leadingConstant: leading,
            trailingConstant: trailing
        )
    }

    static func resolvedPlacement(preference: NumpadPlacement,
                                  bounds: CGRect,
                                  idiom: UIUserInterfaceIdiom,
                                  horizontalSizeClass: UIUserInterfaceSizeClass?,
                                  isFloating: Bool) -> NumpadPlacement {
        guard idiom == .pad else { return .fullWidth }
        if preference != .automatic { return preference }
        if isFloating || horizontalSizeClass == .compact || bounds.width < narrowPadWidth {
            return .fullWidth
        }
        return .center
    }

    static func contentFrame(bounds: CGRect,
                             placement: NumpadPlacement,
                             idiom: UIUserInterfaceIdiom) -> CGRect {
        guard idiom == .pad else { return bounds }
        let effective: NumpadPlacement
        if placement == .automatic {
            effective = bounds.width < narrowPadWidth ? .fullWidth : .center
        } else {
            effective = placement
        }
        let width = min(bounds.width, regularPadMaxWidth)
        switch effective {
        case .automatic, .center:
            return CGRect(x: bounds.midX - width / 2,
                          y: bounds.minY,
                          width: width,
                          height: bounds.height)
        case .left:
            return CGRect(x: bounds.minX,
                          y: bounds.minY,
                          width: width,
                          height: bounds.height)
        case .right:
            return CGRect(x: bounds.maxX - width,
                          y: bounds.minY,
                          width: width,
                          height: bounds.height)
        case .fullWidth:
            return bounds
        }
    }

    /// Applies the production leading/trailing constraint constants and returns the complete
    /// resolution for integration assertions and callers that need the selected content frame.
    @discardableResult
    static func apply(
        preference: NumpadPlacement,
        bounds: CGRect,
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        isFloating: Bool,
        leadingConstraint: NSLayoutConstraint,
        trailingConstraint: NSLayoutConstraint
    ) -> ConstraintLayout {
        let placement = resolvedPlacement(
            preference: preference,
            bounds: bounds,
            idiom: idiom,
            horizontalSizeClass: horizontalSizeClass,
            isFloating: isFloating
        )
        let frame = contentFrame(bounds: bounds, placement: placement, idiom: idiom)
        let leading = frame.minX - bounds.minX
        let trailing = frame.maxX - bounds.maxX
        leadingConstraint.constant = leading
        trailingConstraint.constant = trailing
        return ConstraintLayout(
            resolvedPlacement: placement,
            contentFrame: frame,
            leadingConstant: leading,
            trailingConstant: trailing
        )
    }

    /// Applies only the horizontal constraints resolved from the current width preference.
    @discardableResult
    static func apply(
        width: NumpadWidthSize,
        bounds: CGRect,
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        isFloating: Bool,
        leadingConstraint: NSLayoutConstraint,
        trailingConstraint: NSLayoutConstraint
    ) -> ConstraintLayout {
        let layout = resolve(
            width: width,
            bounds: bounds,
            idiom: idiom,
            horizontalSizeClass: horizontalSizeClass,
            isFloating: isFloating
        )
        leadingConstraint.constant = layout.leadingConstant
        trailingConstraint.constant = layout.trailingConstant
        return layout
    }
}
