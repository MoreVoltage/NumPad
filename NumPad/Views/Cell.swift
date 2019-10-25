//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 4/3/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class Cell: UITableViewCell {
    
    let style: UITableViewCell.CellStyle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.style = style
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        imageView?.tintColor = .primary
        imageView?.contentMode = .center
        textLabel?.font = .body
        textLabel?.textColor = .text
        switch style {
        case .subtitle:
            detailTextLabel?.font = .preferredFont(for: .caption1)
            detailTextLabel?.textColor = .lightGray
        default:
            detailTextLabel?.font = .body
            detailTextLabel?.textColor = .lightGray
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        textLabel?.frame.origin.x = 54
        switch style {
        case .subtitle:
            detailTextLabel?.frame.origin.x = 54
        default: break
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView?.image = nil
        textLabel?.text = nil
        detailTextLabel?.text = nil
    }
    
}
