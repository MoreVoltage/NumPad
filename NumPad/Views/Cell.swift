//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 4/3/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class Cell: UITableViewCell {
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        imageView?.tintColor = .lightBlue
        imageView?.contentMode = .center
        textLabel?.font = .regular
        textLabel?.textColor = .text
        detailTextLabel?.font = .regularSmall
        detailTextLabel?.textColor = .lightGray
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        
        textLabel?.frame.origin.x = 54
        detailTextLabel?.frame.origin.x = 54
    }
    
}
