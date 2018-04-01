//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftyTimer

class Cell: UICollectionViewCell {
    lazy var button: Button = { [unowned self] in
        let button = Button(type: .custom)
        button.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        self.contentView.addSubview(button)
        _constraints = button.edges()
        return button
    }()
    
    var _constraints: [NSLayoutConstraint]?
    var edgeInsets: UIEdgeInsets = .zero
    
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?
    
    deinit {
        print("\(self) deinit")
    }
    
    override func updateConstraints() {
        for constaint in _constraints ?? [] {
            switch constaint.firstAttribute {
            case .top: constaint.constant = edgeInsets.top
            case .left: constaint.constant = edgeInsets.left
            case .bottom: constaint.constant = edgeInsets.bottom
            case .right: constaint.constant = edgeInsets.right
            default: break
            }
        }
        super.updateConstraints()
    }
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    func configure(_ item: Item, roundedCorners: Bool, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.scheme = item.style.scheme
        button.showsTouchWhenHighlighted = false
        button.layer.cornerRadius = roundedCorners ? 4 : 0
        button.layer.shadowOpacity = roundedCorners ? 1 : 0
        button.layer.shadowColor = item.style.scheme.highlightedBackground.withAlphaComponent(0.5).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0
        if roundedCorners {
            edgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: -2, right: -2)
        } else {
            edgeInsets = UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0)
        }
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
}
