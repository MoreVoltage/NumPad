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
        switch type {
        case .math:
            items += [
                [Item(title: "+"), Item(title: "-"), Item(title: "*"), Item(title: "/"), Item(title: "="), Item(title: "%"), Item(title: "("), Item(title: ")")]
            ]
        default: break
        }
        items += {
            let items = [
                [Item(title: "1"), Item(title: "2"), Item(title: "3"), Item(title: "Space", font: .text, style: .secondary)],
                [Item(title: "4"), Item(title: "5"), Item(title: "6"), Item(title: ".", font: .text, style: .secondary)],
                [Item(title: "7"), Item(title: "8"), Item(title: "9"), Item(title: ",", font: .text, style: .secondary)]
            ]
            if Keyboard.isReversedMode {
                return items.reversed()
            }
            return items
        }() as [[Item]]
        items += [
            [Item(imageName: "next", style: .primary), Item(title: "0"), Item(imageName: "back", style: .primary), Item(title: "Enter", font: .text, style: .secondary)]
        ]
        return items
    }
    
}
