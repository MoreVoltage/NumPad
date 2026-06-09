//
//  Button.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 3/31/18.
//  Copyright © 2018 MoreVoltage. All rights reserved.
//

import UIKit

class Button: TimerButton {
    /// Whether the keyboard has Full Access. Haptics in a keyboard extension are a silent no-op
    /// without it, so we skip warming/firing the Taptic engine entirely. Set by KeyboardViewController.
    static var isFullAccessAvailable = false

    /// One shared, reusable impact generator for the whole keyboard. Allocating a fresh
    /// `UIImpactFeedbackGenerator` per tap (the old behavior) skipped `prepare()`, so the Taptic
    /// engine spun up cold and the first tap often produced no haptic. Reusing + preparing it on
    /// touch-down gives consistent, low-latency feedback and avoids per-tap allocation churn in the
    /// memory-constrained extension.
    private static let feedback = UIImpactFeedbackGenerator(style: .light)

    private static var hapticsActive: Bool { isFullAccessAvailable && UserPrefs.hapticsEnabled }

    var scheme: Item.Style.Scheme! {
        didSet {
            self.titleColor = scheme.control
            self.tintColor = scheme.control
            self._isHighlighted = false
        }
    }
    var _isHighlighted: Bool = false {
        didSet {
            let color = _isHighlighted ? scheme.highlightedBackground : scheme.background
            guard self.backgroundColor != color else { return }
            self.backgroundColor = color
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        _isHighlighted = true
        // Warm the Taptic engine so the haptic on touch-up fires with no latency.
        if Button.hapticsActive { Button.feedback.prepare() }
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

        if Button.hapticsActive { Button.feedback.impactOccurred() }
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
        _cancelContinuousPress()
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
        _cancelContinuousPress()
    }
    
    @objc private func _beginContinuousPress() {
        guard isTracking, continuousPressTimeInterval > 0 else { return }
        continuousPressTimer = Timer.every(continuousPressTimeInterval) { [weak self] in
            guard let self else { return }
            guard self.isTracking else {
                return self._cancelContinuousPress()
            }
            self.sendActions(for: .valueChanged)
        }
    }
    
    @objc private func _cancelContinuousPress() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_beginContinuousPress), object: nil)
        continuousPressTimer?.invalidate()
        continuousPressTimer = nil
    }
}
