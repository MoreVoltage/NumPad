//
//  KeyMetrics.swift
//  Keyboard
//
//  Idiom-aware key-grid metrics. Every value here is the iPhone constant StackView/Cell
//  hardcoded before iPad tuning existed — iPhone call sites must see byte-identical output.
//  iPad gets larger touch targets/typography so the grid stops looking iPhone-stretched on a
//  1024pt-wide keyboard.
//

import UIKit

enum KeyMetrics {
    private static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Row/column spacing for the `roundedCorners` / `grid` / flat layouts in `StackView.configure`.
    static func spacing(roundedCorners: Bool, grid: Bool) -> CGFloat {
        if isPad {
            return roundedCorners ? 4 : grid ? 2 : 0
        }
        return roundedCorners ? 2 : grid ? 1 : 0
    }

    /// Intrinsic width given to cells in the horizontally-scrollable top pack row.
    static var packRowChipWidth: CGFloat { isPad ? 64 : 44 }

    /// Width of the legacy layout's narrow right-edge column (slots / return key).
    static func sideColumnWidth(for width: CGFloat) -> CGFloat {
        isPad ? min(width * 2 / 11, 140) : width * (2 / 11) - 0.75
    }

    /// Lock-chip badge size drawn on a locked premium key.
    static var lockChipSize: CGFloat { isPad ? 16 : 12 }

    /// Font size for the "Unlock" tooltip under the lock chip.
    static var lockTooltipFontSize: CGFloat { isPad ? 11 : 9 }

    /// Leading/trailing inset for the key label.
    static var labelInset: CGFloat { isPad ? 4 : 2 }

    /// Corner radius applied to rounded-corner key cells.
    static var cornerRadius: CGFloat { isPad ? 7 : 4 }

    /// Multiplier applied to `Item.font`'s point size before assigning it to the key label
    /// (`Item.swift` stays iPhone-sized; Cell scales it up at render time on iPad only).
    static var keyLabelFontScale: CGFloat { isPad ? 1.25 : 1 }

    /// Returns `font` scaled by `keyLabelFontScale` on iPad; returns `font` unchanged on iPhone.
    static func scaledFont(_ font: UIFont) -> UIFont {
        guard isPad else { return font }
        return font.withSize(font.pointSize * keyLabelFontScale)
    }
}
