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
        let edges = UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0)
//        let edges = UIEdgeInsets(top: 2, left: 2, bottom: -2, right: -2)
        button.constrainToEdges(edges)
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
    
    func configure(_ item: Item, roundedCorners: Bool, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        button.title = item.title
        button.titleLabel?.font = item.font
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.scheme = item.style.scheme
        button.isHighlighted = false
//        button.layer.cornerRadius = roundedCorners ? 4 : 0
//        button.layer.shadowOpacity = roundedCorners ? 1 : 0
//        button.layer.shadowColor = UIColor(red: 0.533, green: 0.541, blue: 0.556, alpha: 1).cgColor // TEMP
//        button.layer.shadowOffset = CGSize(width: 0, height: 1)
//        button.layer.shadowRadius = 0
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
}

class Button: TimerButton {
    var scheme: Item.Style.Scheme! {
        didSet {
            self.titleColor = scheme.control
            self.tintColor = scheme.control
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
//            guard oldValue != isHighlighted else { return }
            self.backgroundColor = isHighlighted ? scheme.highlightedBackground : scheme.background
        }
    }
    
    // https://stackoverflow.com/questions/23046539/uibutton-fails-to-properly-register-touch-in-bottom-region-of-iphone-screen
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inside = super.point(inside: point, with: event)
        if inside != isHighlighted && event?.type == .touches {
            isHighlighted = inside
        }
        return inside
    }
    
}

class TimerButton: UIButton {
    private var continuousPressTimeInterval: TimeInterval = 0
    private var continuousPressTimer: Timer?
    
    deinit {
        _cancelContinousPress()
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
        _cancelContinousPress()
    }
    
    @IBAction func _beginContinuousPress() {
        guard isTracking, continuousPressTimeInterval > 0 else { return }
        continuousPressTimer = Timer.every(continuousPressTimeInterval) { [weak self] in
            guard let `self` = self else { return }
            guard self.isTracking else {
                return self._cancelContinousPress()
            }
            self.sendActions(for: .valueChanged)
        }
    }
    
    @IBAction func _cancelContinousPress() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_beginContinuousPress), object: nil)
        continuousPressTimer?.invalidate()
        continuousPressTimer = nil
    }
}
