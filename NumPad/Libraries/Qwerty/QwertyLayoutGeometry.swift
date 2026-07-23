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
        case .automatic, .centered:
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

enum NumpadGeometry {
    static let regularPadMaxWidth: CGFloat = 560
    static let narrowPadWidth: CGFloat = 700

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
}
