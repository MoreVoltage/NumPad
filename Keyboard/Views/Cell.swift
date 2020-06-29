//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftyTimer

class Cell: UIView {
    lazy var button: Button = { [unowned self] in
        let button = Button(type: .custom)
        self.addSubview(button)
        button.edgesToSuperview()
        return button
    }()
    
    func configure(_ item: Item, roundedCorners: Bool, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.image = item.imageName.flatMap(UIImage.init(named:))
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.scheme = item.style.scheme
        button.showsTouchWhenHighlighted = false
        button.layer.cornerRadius = roundedCorners ? 4 : 0
        button.layer.shadowOpacity = roundedCorners ? 1 : 0
        button.layer.shadowColor = item.style.scheme.highlightedBackground.withAlphaComponent(0.5).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0
        button.removeTarget(nil, action: nil, for: .allEvents)
        button.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
    
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    // https://spin.atomicobject.com/2017/02/07/uistackviev-proportional-custom-uiviews/
    var width = 1.0
    override var intrinsicContentSize: CGSize {
        return CGSize(width: width, height: 1.0)
    }
}
