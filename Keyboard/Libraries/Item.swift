//
//  Item.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

struct Item {
    
    let title: String?
    let font: UIFont?
    let imageName: String?
    let foregroundColor: UIColor
    let backgroundColor: UIColor
    
    init(title: String, font: UIFont = .numbers, foregroundColor: UIColor = UIColor.theme.foreground, backgroundColor: UIColor = UIColor.theme.background) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    init(imageName: String, foregroundColor: UIColor = UIColor.theme.foreground, backgroundColor: UIColor = UIColor.theme.background2) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    static func all() -> [[Item]] {
        return [
            [Item(title: "1"), Item(title: "2"), Item(title: "3"), Item(title: ",", font: .text, backgroundColor: UIColor.theme.background3)],
            [Item(title: "4"), Item(title: "5"), Item(title: "6"), Item(title: "Space", font: .text, backgroundColor: UIColor.theme.background3)],
            [Item(title: "7"), Item(title: "8"), Item(title: "9"), Item(title: ".", font: .text, backgroundColor: UIColor.theme.background3)],
            [Item(imageName: "next"), Item(title: "0"), Item(imageName: "back"), Item(title: "Enter", font: .text, backgroundColor: UIColor.theme.background3)]
        ]
    }
    
}
