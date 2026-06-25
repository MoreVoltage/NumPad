import UIKit

/// Turns the pure `CustomKeyboardLayout` cells into `Item`s for the keyboard grid. Peripheral keys
/// reuse the `CustomKeys` token vocabulary so a literal inserts itself and a function token
/// (`{space}`/`{tab}`/`{left}`/`{right}`/`{dismiss}`) behaves like the matching right-side slot —
/// the existing tap handler routes on `Item.token` with no special-casing.
enum CustomKeyboardItems {
    static func items(for rows: [[CustomKeyboardCell]], returnKeyTitle: String) -> [[Item]] {
        rows.map { row in row.map { item(for: $0, returnKeyTitle: returnKeyTitle) } }
    }

    private static func item(for cell: CustomKeyboardCell, returnKeyTitle: String) -> Item {
        switch cell {
        case .digit(let d):        return Item(title: d)
        case .peripheral(let key): return Item(title: CustomKeys.displayName(for: key), actionToken: key)
        case .blank:               return Item(title: "")
        case .next:                return Item(imageName: "next", style: .primary)
        case .globe:               return Item(imageName: "globe", style: .primary)
        case .zero:                return Item(title: "0")
        case .back:                return Item(imageName: "back", style: .primary, isReversed: true)
        case .ret:                 return Item(title: returnKeyTitle, font: .text, style: .secondary, role: .returnKey)
        }
    }
}
