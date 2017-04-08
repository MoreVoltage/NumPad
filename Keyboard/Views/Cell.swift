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
        button.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        self.contentView.addSubview(button)
        button.constrainToEdges(UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0))
        return button
    }()
    
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    func configure(_ item: Item, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.titleColor = item.foregroundColor
        button.tintColor = item.foregroundColor
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.setBackgroundImage(UIImage(color: item.backgroundColor), for: .normal)
        button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .highlighted)
        button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .selected)
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
    
}
