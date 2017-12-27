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
        button.isExclusiveTouch = true
        button.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        self.contentView.addSubview(button)
        button.constrainToEdges(UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0))
        return button
    }()
    
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?
    
    deinit {
        print("\(self) deinit")
    }
    
    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }
    
    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }
    
    func configure(_ item: Item, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.scheme = item.style.scheme
        button.isHighlighted = false
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
    
}

class Button: UIButton {
//    var usesRoundedCorners: Bool = false {
//        didSet {
//            self.layer.cornerRadius = usesRoundedCorners ? 4 : 0
//            self.layer.shadowOpacity = usesRoundedCorners ? 1 : 0
//            self.layer.shadowColor = UIColor(red: 0.533, green: 0.541, blue: 0.556, alpha: 1).cgColor
//            self.layer.shadowOffset = CGSize(width: 0, height: 1)
//            self.layer.shadowRadius = 0
//        }
//    }
    
    var scheme: Item.Style.Scheme! {
        didSet {
            self.titleColor = scheme.control
            self.tintColor = scheme.control
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            self.backgroundColor = isHighlighted ? scheme.highlightedBackground : scheme.background
        }
    }
    
    var continuousPressTimeInterval: TimeInterval = 0
    var continuousPressTimer: Timer?
    
    deinit {
        _cancelContinousPressIfNeeded()
    }
    
    func addTarget(_ target: Any?, action: Selector, forContinuousPressWithTimeInterval timeInterval: TimeInterval) {
        continuousPressTimeInterval = timeInterval
        self.addTarget(target, action: action, for: .valueChanged)
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let shouldBegin = super.beginTracking(touch, with: event)
        if shouldBegin, continuousPressTimeInterval > 0 {
            self.perform(#selector(_beginContinuousPress), with: nil, afterDelay: continuousPressTimeInterval)
        }
        return shouldBegin
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        _cancelContinousPressIfNeeded()
    }
    
    @IBAction func _beginContinuousPress() {
        guard isTracking, continuousPressTimeInterval > 0 else { return }
        continuousPressTimer = Timer.every(continuousPressTimeInterval) { [weak self] in
            guard let `self` = self else { return }
            guard self.isTracking else {
                return self._cancelContinousPressIfNeeded()
            }
            self.sendActions(for: .valueChanged)
        }
    }
    
    @IBAction func _cancelContinousPressIfNeeded() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_beginContinuousPress), object: nil)
        continuousPressTimer?.invalidate()
        continuousPressTimer = nil
    }
}
