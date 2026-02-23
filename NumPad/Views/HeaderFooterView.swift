//
//  HeaderFooterView.swift
//  NumPad
//
//  Created by Lasha Efremidze on 5/28/19.
//  Copyright © 2019 MoreVoltage. All rights reserved.
//

import UIKit

class HeaderFooterView: UIView {
    lazy var label: UILabel = { [unowned self] in
        let label = UILabel()
        label.textColor = .text
        label.numberOfLines = 0
        self.addSubview(label)
        return label
    }()
    
    convenience init(attributedText: NSAttributedString, maxWidth: CGFloat, insets: UIEdgeInsets) {
        self.init()
        
        label.attributedText = attributedText
        label.topToSuperview(offset: insets.top)
        label.bottomToSuperview(offset: -insets.bottom)
        label.leftToSuperview(offset: insets.left, relation: .equalOrGreater)
        label.rightToSuperview(offset: -insets.right, relation: .equalOrLess)
        label.centerXToSuperview()
        
        self.frame.size.height = label.textRect(forBounds: CGRect(x: 0, y: 0, width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), limitedToNumberOfLines: 0).height + insets.top + insets.bottom
    }
}
