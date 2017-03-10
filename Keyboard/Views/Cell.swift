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
    
    func configure(_ item: Item) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.titleColor = item.foregroundColor
        button.tintColor = item.foregroundColor
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setBackgroundImage(UIImage(color: item.backgroundColor), for: .normal)
        button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .highlighted)
        button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .selected)
    }
    
}
