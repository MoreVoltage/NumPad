//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class Cell: UICollectionViewCell {
    
    lazy var button: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        button.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        self.contentView.addSubview(button)
        button.constrainToEdges(UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0))
        return button
    }()
    
    var buttonTapped: ((UIButton) -> Void)?
    var buttonTouchDown: ((UIButton) -> Void)?
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
}
