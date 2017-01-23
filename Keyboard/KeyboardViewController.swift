//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 1/17/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class KeyboardViewController: UIInputViewController {
    
    fileprivate let foregroundColor = UIColor(white: 0.3, alpha: 1)
    fileprivate let backgroundColor = UIColor(white: 0.9, alpha: 1)
    
    fileprivate var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let numPad = NumPad()
        numPad.translatesAutoresizingMaskIntoConstraints = false
        numPad.backgroundColor = backgroundColor
        numPad.layer.borderColor = backgroundColor.cgColor
        numPad.layer.borderWidth = 1
        numPad.dataSource = self
        numPad.delegate = self
        view.addSubview(numPad)
        
        let views = ["numPad": numPad]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[numPad]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[numPad]|", options: [], metrics: nil, views: views))
    }

}

// MARK: - Actions
extension KeyboardViewController {
    
    @IBAction func buttonTouchDown(_ button: UIButton) {
        let device = UIDevice.current
        if device.hasOpenAccess() {
            device.playInputClick()
        }
    }
    
    func buttonLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.view?.tag == 12 {
            switch recognizer.state {
            case .began:
                timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.backspace(_:)), userInfo: nil, repeats: true)
            case .ended:
                timer?.invalidate()
                timer = nil
            default: break
            }
        }
    }
    
    @IBAction func backspace(_: AnyObject) {
        textDocumentProxy.deleteBackward()
    }
    
}

// MARK: - NumPadDataSource
extension KeyboardViewController: NumPadDataSource {
    
    func numberOfRowsInNumberPad(_ numPad: NumPad) -> Int {
        return 4
    }
    
    func numPad(_ numPad: NumPad, numberOfColumnsInRow row: Int) -> Int {
        if row == 3 {
            return 4
        }
        return 3
    }
    
}

// MARK: - NumPadDelegate
extension KeyboardViewController: NumPadDelegate {
    
    func numPad(_ numPad: NumPad, willDisplayButton button: UIButton, forPosition position: Position) {
        let index = numPad.indexForPosition(position)
        
        button.tag = index
        
        // tintColor
        button.tintColor = foregroundColor
        
        // title
        var title: String?
        if case 0...8 = index {
            title = "\(index + 1)"
        } else if case 11 = index {
            title = "0"
        }
        button.setTitle(title, for: UIControlState())
        
        // titleColor
        button.setTitleColor(foregroundColor, for: UIControlState())
        
        // font
        button.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        
        // image
        var image: UIImage?
        switch index {
        case 9: image = UIImage(named: "globe")
        case 10: image = UIImage(named: "return")
        case 12: image = UIImage(named: "backspace")
        default: break
        }
        button.setImage(image, for: UIControlState())
        
        // backgroundImage
        var backgroundImage = UIColor.white.toImage()
        button.setBackgroundImage(backgroundImage, for: UIControlState())
        backgroundImage = backgroundColor.toImage()
        button.setBackgroundImage(backgroundImage, for: .highlighted)
        button.setBackgroundImage(backgroundImage, for: .selected)
        
        // tap
        button.addTarget(self, action: #selector(KeyboardViewController.buttonTouchDown(_:)), for: .touchDown)
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.buttonLongPressed(_:))))
    }
    
    func numPad(_ numPad: NumPad, sizeForButtonAtPosition position: Position, defaultSize size: CGSize) -> CGSize {
        let index = numPad.indexForPosition(position)
        var size = size
        if case 9...10 = index {
            size.width = (numPad.frame.width / 6)
        } else if case 11...12 = index {
            size.width = (numPad.frame.width / 3)
        }
        return size
    }
    
    func numPad(_ numPad: NumPad, buttonTappedAtPosition position: Position) {
        let index = numPad.indexForPosition(position)
        switch index {
        case 9: advanceToNextInputMode()
        case 10: textDocumentProxy.insertText("\n")
        case 12: textDocumentProxy.deleteBackward()
        default:
            guard let
                button = numPad.buttonForPosition(position),
                let text = button.titleLabel?.text
            else { return }
            textDocumentProxy.insertText(text)
        }
    }
    
}

// MARK: - UIInputViewAudioFeedback
extension UIInputView: UIInputViewAudioFeedback {
    
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
    
}

// MARK: - Extensions
extension UIColor {
    
    func toImage() -> UIImage {
        return UIImage(color: self)
    }
    
}

extension UIImage {
    
    convenience init(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        var rect = CGRect.zero
        rect.size = size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: (image?.cgImage!)!)
    }
    
}

extension UIDevice {
    
    func hasOpenAccess() -> Bool {
        return UIPasteboard.general.isKind(of: UIPasteboard.self)
    }
    
}
