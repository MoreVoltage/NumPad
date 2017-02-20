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
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(_buttonLongPressed)))
        self.contentView.addSubview(button)
        button.constrain {[
            $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: 1),
            $0.leadingAnchor.constraint(equalTo: $0.superview!.leadingAnchor, constant: 1),
            $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: 0),
            $0.trailingAnchor.constraint(equalTo: $0.superview!.trailingAnchor, constant: 0)
            ]}
        return button
    }()
    
    var buttonTapped: ((UIButton) -> Void)?
    var buttonLongPressed: ((UILongPressGestureRecognizer) -> Void)?
    
    @IBAction func _buttonTapped(sender: UIButton) {
        self.buttonTapped?(sender)
    }
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        if UIDevice.current.hasOpenAccess() {
            UIDevice.current.playInputClick()
        }
    }
    
    @IBAction func _buttonLongPressed(recognizer: UILongPressGestureRecognizer) {
        self.buttonLongPressed?(recognizer)
    }
    
}
