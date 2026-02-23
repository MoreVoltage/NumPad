//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation
import UIKit
import SwiftyTimer

class Cell: Button {
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    // https://spin.atomicobject.com/2017/02/07/uistackviev-proportional-custom-uiviews/
    var width: CGFloat = UIView.noIntrinsicMetric
    override var intrinsicContentSize: CGSize {
        return CGSize(width: width, height: super.intrinsicContentSize.height)
    }
}

extension Cell {
    func configure(_ item: Item, roundedCorners: Bool, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        self.title = item.title
        self.titleLabel?.font = item.font
        self.image = item.imageName.flatMap(UIImage.init(named:)).map { item.isReversed ? $0.imageFlippedForRightToLeftLayoutDirection() : $0 }
        self.setImage(self.image, for: .highlighted)
        self.setImage(self.image, for: .selected)
        self.scheme = item.style.scheme
        self.layer.cornerRadius = roundedCorners ? 4 : 0
        self.layer.shadowOpacity = roundedCorners ? 1 : 0
        self.layer.shadowColor = item.style.scheme.highlightedBackground.withAlphaComponent(0.5).cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 1)
        self.layer.shadowRadius = 0
        self.removeTarget(nil, action: nil, for: .allEvents)
        self.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        self.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
}
