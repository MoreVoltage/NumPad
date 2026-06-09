//
//  Item.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

struct Item {

    enum Style {
        case `default`, primary, secondary
    }

    /// Semantic role of a key, used by the tap handler to identify special keys independently of
    /// their *display* title. The return key's label changes with the field's returnKeyType
    /// (Go/Search/Done/…), so matching it by title would break — the role keeps it identifiable.
    enum Role {
        case standard, returnKey
    }

    let title: String?
    let font: UIFont?
    let imageName: String?
    let style: Style
    let isReversed: Bool
    let role: Role

    init(title: String, font: UIFont = .numbers, style: Style = .default, role: Role = .standard) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.style = style
        self.isReversed = false
        self.role = role
    }

    init(imageName: String, style: Style = .default, isReversed: Bool = false) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.style = style
        self.isReversed = isReversed
        self.role = .standard
    }

    /// - Parameter returnKeyTitle: label for the bottom-right return key, derived from the host
    ///   field's `returnKeyType` (e.g. "Go", "Search", "Done"). Defaults to the generic "Enter".
    static func all(type: KeyboardType = .default, returnKeyTitle: String = .enter) -> [[Item]] {
        var items = [[Item]]()
        items += pack(type: type)
        items += {
            let a = Keyboard.isReversedMode ? numbers().reversed() : numbers()
            let b = characters()
            return zip(a, b).map { $0 + $1 }
        }() as [[Item]]
        items += [
            [Item(imageName: "next", style: .primary), Item(title: "0"), Item(imageName: "back", style: .primary, isReversed: true), Item(title: returnKeyTitle, font: .text, style: .secondary, role: .returnKey)]
        ]
        return items
    }

}

private extension Item {
    
    static func pack(type: KeyboardType) -> [[Item]] {
        switch type {
        case .math:
            return [
                ["+", "-", "*", "/", "=", "%", "#", "$", "(", ")"].map { Item(title: $0) } + [Item(imageName: "math2", style: .primary)]
            ]
        case .math2:
            return [
                ["\'", "\"", "\\", ":", ";", "!", "?", "&", "[", "]"].map { Item(title: $0) } + [Item(imageName: "math", style: .primary)]
            ]
        case .finance:
            return [
                ["$", "€", "£", "¥", ",", ".", "%", "+/-", "(", ")"].map { Item(title: $0) }
            ]
        case .symbols:
            return [
                ["@", "#", "&", "*", "=", "+", "-", "/", "\\", "~"].map { Item(title: $0) }
            ]
        case .programmer:
            return [
                ["0x", "&", "|", "^", "~", "<<", ">>", "(", ")", ";"].map { Item(title: $0) }
            ]
        // NOTE: the `.tax` pack row was removed — its TAX/TIP/Copy/Clear keys had no tap handler and
        // inserted their own labels as literal text, duplicating the (working) long-press "%" Tax/Tip
        // overlay. Tax/Tip is now reachable only via that overlay. `.tax` is no longer offered as a
        // selectable pack (see KeyboardType.packs); a stale `.tax` selection falls back to no pack row.
        default:
            return []
        }
    }
    
    static func numbers() -> [[Item]] {
        return [
            [Item(title: "1"), Item(title: "2"), Item(title: "3")],
            [Item(title: "4"), Item(title: "5"), Item(title: "6")],
            [Item(title: "7"), Item(title: "8"), Item(title: "9")]
        ]
    }
    
    static func characters() -> [[Item]] {
        return [
            [Item(title: ",", font: .text, style: .secondary)],
            [Item(title: ".", font: .text, style: .secondary)],
            [Item(title: .space, font: .text, style: .secondary)]
        ]
    }
    
}
