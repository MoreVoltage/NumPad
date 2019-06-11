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
    
    init(title: String, font: UIFont = .numbers, style: Style = .default) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.style = style
    }
    
    init(imageName: String, style: Style = .default) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.style = style
    }
    
    static func all(type: KeyboardType = .default) -> [[Item]] {
        var items = [[Item]]()
        items += pack(type: type)
        items += {
            let a = Keyboard.isReversedMode ? numbers().reversed() : numbers()
            let b = characters()
            return zip(a, b).map { $0 + $1 }
        }() as [[Item]]
        items += [
            [Item(imageName: "next", style: .primary), Item(title: "0"), Item(imageName: "back", style: .primary), Item(title: "Enter", font: .text, style: .secondary)]
        ]
        return items
    }
    
}

private extension Item {
    
    static func pack(type: KeyboardType) -> [[Item]] {
        switch type {
        case .math:
            return [
                ["+", "-", "*", "/", "=", "%", "#", "(", ")"].map { Item(title: $0) } + [Item(imageName: "math2", style: .primary)]
            ]
        case .math2:
            return [
                ["\'", "\"", "\\", ":", ";", "!", "?", "[", "]"].map { Item(title: $0) } + [Item(imageName: "math", style: .primary)]
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
        return [
            [Item(title: ",", font: .text, style: .secondary)],
            [Item(title: ".", font: .text, style: .secondary)],
            [Item(title: "Space", font: .text, style: .secondary)]
        ]
    }
    
}
