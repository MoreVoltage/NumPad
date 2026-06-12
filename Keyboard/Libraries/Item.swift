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
    
    let title: String?
    let font: UIFont?
    let imageName: String?
    let style: Style
    let isReversed: Bool
    /// Raw assignment token when this key is one of the remappable right-side slots (see CustomKeys).
    let token: String?
    /// Slot index (0–2) for remappable right-side keys; nil for fixed keys.
    let slot: Int?

    init(title: String, font: UIFont = .numbers, style: Style = .default) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.style = style
        self.isReversed = false
        self.token = nil
        self.slot = nil
    }

    init(imageName: String, style: Style = .default, isReversed: Bool = false) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.style = style
        self.isReversed = isReversed
        self.token = nil
        self.slot = nil
    }

    init(slotToken: String, slot: Int) {
        self.title = CustomKeys.displayName(for: slotToken)
        self.font = .text
        self.imageName = nil
        self.style = .secondary
        self.isReversed = false
        self.token = slotToken
        self.slot = slot
    }
    
    static func all(type: KeyboardType = .default, includeSwitchKey: Bool = false) -> [[Item]] {
        var items = [[Item]]()
        items += pack(type: type)
        items += {
            let a = Keyboard.isReversedMode ? numbers().reversed() : numbers()
            let b = characters()
            return zip(a, b).map { $0 + $1 }
        }() as [[Item]]
        var bottomRow = [Item(imageName: "next", style: .primary), Item(title: "0"), Item(imageName: "back", style: .primary, isReversed: true), Item(title: .enter, font: .text, style: .secondary)]
        if includeSwitchKey {
            bottomRow.insert(Item(imageName: "globe", style: .primary), at: 1)
        }
        items += [bottomRow]
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
        case .tax:
            return [
                ["TAX", "TIP", "5%", "10%", "15%", "18%", "20%", "25%", "Copy", "Clear"].map { Item(title: $0, font: .text, style: .secondary) }
            ]
        case .custom:
            // No row at all when the user hasn't defined any keys — the caller renders the
            // default layout instead (see KeyboardViewController.effectiveKeyboardType).
            let keys = CustomPackManager.shared.keys
            guard !keys.isEmpty else { return [] }
            return [
                keys.map { Item(title: $0, font: .text, style: .secondary) }
            ]
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
        // The right-side column is user-remappable (defaults: comma, period, space).
        return CustomKeys.slots.enumerated().map { index, token in
            [Item(slotToken: token, slot: index)]
        }
    }
    
}
