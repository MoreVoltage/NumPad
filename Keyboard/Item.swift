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
    let backgroundColor: UIColor
    init(title: String, font: UIFont = .numbers, backgroundColor: UIColor = UIColor.cache.theme.background) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.backgroundColor = backgroundColor
    }
    init(imageName: String, backgroundColor: UIColor = UIColor.cache.theme.background2) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.backgroundColor = backgroundColor
    }
}
