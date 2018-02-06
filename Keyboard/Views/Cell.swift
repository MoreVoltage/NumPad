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
        _constraints = button.constrainToEdges()
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

class Button: TimerButton {
    var scheme: Item.Style.Scheme! {
        didSet {
            self.titleColor = scheme.control
            self.tintColor = scheme.control
        }
    }
    var _isHighlighted: Bool = false {
        didSet {
            guard oldValue != _isHighlighted else { return }
            self.backgroundColor = _isHighlighted ? scheme.highlightedBackground : scheme.background
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        _isHighlighted = true
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touches.first, self.hitTest(touch.location(in: self), with: event) != nil {
//            _isHighlighted = true // comment out if panning enabled
        } else {
            _isHighlighted = false
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        _isHighlighted = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        _isHighlighted = false
    }
    
    // https://stackoverflow.com/questions/23046539/uibutton-fails-to-properly-register-touch-in-bottom-region-of-iphone-screen
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inside = super.point(inside: point, with: event)
        if inside != _isHighlighted, event?.type == .touches {
            _isHighlighted = inside
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
