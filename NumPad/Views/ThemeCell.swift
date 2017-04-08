//
//  ThemeCell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 4/3/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation

class ThemeCell: Cell {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size: CGFloat = 10
        imageView?.frame.size = CGSize(width: size, height: size)
        imageView?.center.y = contentView.center.y
        imageView?.layer.cornerRadius = size / 2
        imageView?.layer.masksToBounds = true
    }
    
}
