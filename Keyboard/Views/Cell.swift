//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

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
        button.titleColor = item.style.scheme.control
        button.tintColor = item.style.scheme.control
        button.image = item.imageName.flatMap { UIImage(named: $0) }
        button.setImage(button.image, for: .highlighted)
        button.setImage(button.image, for: .selected)
        button.backgroundImage = UIImage.image(color: item.style.scheme.background)
        button.setBackgroundImage(UIImage.image(color: item.style.scheme.highlightedBackground), for: .highlighted)
        button.setBackgroundImage(UIImage.image(color: item.style.scheme.highlightedBackground), for: .selected)
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
    
}

class Button: UIButton {
    var usesRoundedCorners: Bool = false {
        didSet {
            self.layer.cornerRadius = usesRoundedCorners ? 4 : 0
            self.layer.shadowOpacity = usesRoundedCorners ? 1 : 0
            self.layer.shadowColor = UIColor(red: 0.533, green: 0.541, blue: 0.556, alpha: 1).cgColor
            self.layer.shadowOffset = CGSize(width: 0, height: 1)
            self.layer.shadowRadius = 0
        }
    }
    
    enum Style {
        case `default`
    }
    
    var style: Style = .default
    
    var fillColor: UIColor?
    var highlightedFillColor: UIColor?
    var controlColor: UIColor?
    var highlightedControlColor: UIColor?
    
    var continuousPressTimeInterval: TimeInterval = 0
    var continuousPressTimer: Timer?
    
    override var isHighlighted: Bool {
        didSet {
            if self.isHighlighted || self.isSelected {
                self.backgroundColor = self.highlightedFillColor
                self.imageView?.tintColor = self.controlColor
            } else {
                self.backgroundColor = self.fillColor
                self.imageView?.tintColor = self.highlightedControlColor
            }
        }
    }
    
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
            _beginContinuousPressDelayed()
        }
        return shouldBegin
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        _cancelContinousPressIfNeeded()
    }
    
    @IBAction func _beginContinuousPress() {
        guard isTracking, continuousPressTimeInterval > 0 else { return }
        continuousPressTimer = Timer.scheduledTimer(timeInterval: continuousPressTimeInterval, target: self, selector: #selector(_handleContinuousPressTimer), userInfo: nil, repeats: true)
    }
    
    @IBAction func _beginContinuousPressDelayed() {
        self.perform(#selector(_beginContinuousPress), with: nil, afterDelay: continuousPressTimeInterval * 2)
    }
    
    @IBAction func _handleContinuousPressTimer(_ timer: Timer) {
        guard self.isTracking else {
            return self._cancelContinousPressIfNeeded()
        }
        self.sendActions(for: .valueChanged)
    }
    
    @IBAction func _cancelContinousPressIfNeeded() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_beginContinuousPress), object: nil)
        continuousPressTimer?.invalidate()
        continuousPressTimer = nil
    }
    
//    var _isHighlighted: Bool = false {
//        didSet {
//            guard oldValue != _isHighlighted else { return }
//            UIView.transition(with: self, duration: 0.1, animations: { [unowned self] in
//                self.alpha = self._isHighlighted ? 0.5 : 1
//            })
//        }
//    }
//
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesBegan(touches, with: event)
//
//        _isHighlighted = true
//    }
//
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesMoved(touches, with: event)
//
//        if let touch = touches.first, self.hitTest(touch.location(in: self), with: event) != nil {
//            _isHighlighted = true
//        } else {
//            _isHighlighted = false
//        }
//    }
//
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesEnded(touches, with: event)
//
//        _isHighlighted = false
//    }
//
//    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesCancelled(touches, with: event)
//
//        _isHighlighted = false
//    }
}
