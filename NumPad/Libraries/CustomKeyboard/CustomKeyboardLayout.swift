import Foundation

/// One rendered cell in a custom keyboard grid. The fixed numpad keys (digits, 0, delete, return,
/// next/globe) are produced by the builder itself and are never user-editable; `.peripheral`
/// carries a user key (a literal to insert, or a CustomKeys function token); `.blank` is an empty
/// filler that keeps a short column aligned with the numpad's rows.
enum CustomKeyboardCell: Equatable {
    case digit(String)
    case peripheral(String)
    case blank
    case next
    case globe
    case zero
    case back
    case ret
}

/// Builds the row/column structure of a custom keyboard from a `CustomKeyboardConfig`. Pure and
/// deterministic so it is unit-testable; a thin keyboard-side adapter turns the cells into `Item`s.
///
/// The fixed numpad (digits 0–9, delete, return) is always emitted and never editable, and the
/// keyboard-switch key is always emitted when the device needs one — so the Phase-5 device bugs
/// (movable digits, a vanishing globe) cannot recur by construction.
enum CustomKeyboardLayout {
    /// The numpad's three digit rows, top-to-bottom in normal (non-reversed) order.
    static let digitRows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    static func rows(for config: CustomKeyboardConfig,
                     handedness: Handedness,
                     needsSwitchKey: Bool,
                     reversed: Bool) -> [[CustomKeyboardCell]] {
        var result: [[CustomKeyboardCell]] = []

        // Top-row strip above the numpad (only its non-empty keys).
        let topKeys = (config.topRow ?? []).filter { !$0.isEmpty }
        if !topKeys.isEmpty {
            result.append(topKeys.map { .peripheral($0) })
        }

        // Number rows with the customizable columns on the handed side (Column 1 nearest the digits).
        let digits = reversed ? Array(digitRows.reversed()) : digitRows
        let col1 = columnCells(config.column1, rowCount: digits.count)
        let col2 = columnCells(config.column2, rowCount: digits.count)
        for i in digits.indices {
            let numbers = digits[i].map { CustomKeyboardCell.digit($0) }
            let side = [col1[i], col2[i]].compactMap { $0 } // inner → outer
            switch handedness {
            case .right: result.append(numbers + side)
            case .left:  result.append(Array(side.reversed()) + numbers)
            }
        }

        // Fixed bottom row. The switch key is always present when the device needs one.
        var bottom: [CustomKeyboardCell] = [.next, .zero, .back, .ret]
        if needsSwitchKey { bottom.insert(.globe, at: 1) }
        result.append(bottom)

        return result
    }

    /// Per-row cells for one column, aligned to the numpad's rows. A disabled (`nil`) or all-empty
    /// column contributes no cell to any row; otherwise each row gets its key, or `.blank` where the
    /// column has fewer keys than rows (so the column stays aligned with the digits).
    private static func columnCells(_ column: [String]?, rowCount: Int) -> [CustomKeyboardCell?] {
        guard let column = column, column.contains(where: { !$0.isEmpty }) else {
            return Array(repeating: nil, count: rowCount)
        }
        return (0..<rowCount).map { i in
            let key = i < column.count ? column[i] : ""
            return key.isEmpty ? .blank : .peripheral(key)
        }
    }
}
