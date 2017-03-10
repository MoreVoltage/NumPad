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
    
    init(title: String, font: UIFont = .numbers, foregroundColor: UIColor = UIColor.cache.theme.foreground, backgroundColor: UIColor = UIColor.cache.theme.background) {
        self.title = title
        self.font = font
        self.imageName = nil
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    init(imageName: String, foregroundColor: UIColor = UIColor.cache.theme.foreground, backgroundColor: UIColor = UIColor.cache.theme.background2) {
        self.title = nil
        self.font = nil
        self.imageName = imageName
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
}
