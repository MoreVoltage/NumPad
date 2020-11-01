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
    
    lazy var _imageView: UIImageView = configure(UIImageView()) {
        self.contentView.addSubview($0)
        $0.leadingAndCenterY(to: self.contentView, offset: 15)
    }
    override var imageView: UIImageView? { _imageView }
    
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView?.image = nil
        textLabel?.text = nil
        detailTextLabel?.text = nil
    }
    
}
