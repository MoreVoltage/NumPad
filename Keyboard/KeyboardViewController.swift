//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 1/10/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit
import NumPad

class KeyboardViewController: UIInputViewController {

    @IBOutlet var numPad: NumPad!
    
    let foregroundColor = UIColor(white: 0.3, alpha: 1)
    let backgroundColor = UIColor(white: 0.9, alpha: 1)
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        // Add custom view sizing constraints here
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        numPad = NumPad()
        numPad.translatesAutoresizingMaskIntoConstraints = false
        numPad.backgroundColor = backgroundColor
        numPad.layer.borderColor = backgroundColor.CGColor
        numPad.layer.borderWidth = 1
        numPad.dataSource = self
        numPad.delegate = self
        view.addSubview(numPad)
        
        let views = ["numPad": numPad]
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[numPad]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[numPad]|", options: [], metrics: nil, views: views))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }
    
}

// MARK: - Actions
extension KeyboardViewController {
    
    @IBAction func buttonTouchDown(_: AnyObject) {
        let device = UIDevice.currentDevice()
        if device.hasOpenAccess() {
            device.playInputClick()
        }
    }
    
}

// MARK: - UITextInputDelegate
extension KeyboardViewController {
    
    override func textWillChange(textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }
    
    override func textDidChange(textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
    }
    
}

// MARK: - NumPadDataSource
extension KeyboardViewController: NumPadDataSource {
    
    func numberOfRowsInNumberPad(numPad: NumPad) -> Int {
        return 4
    }
    
    func numPad(numPad: NumPad, numberOfColumnsInRow row: Int) -> Int {
        if row == 3 {
            return 4
        }
        return 3
    }
    
}

// MARK: - NumPadDelegate
extension KeyboardViewController: NumPadDelegate {
    
    func numPad(numPad: NumPad, configureButton button: UIButton, forPosition position: Position) {
        let index = numPad.indexForPosition(position)
        
        // title
        var title: String?
        switch index {
        case 0...8: title = "\(index + 1)"
        case 11: title = "0"
        default: break
        }
        button.setTitle(title, forState: .Normal)
        
        // titleColor
        button.setTitleColor(foregroundColor, forState: .Normal)
        
        // font
        button.titleLabel?.font = UIFont.systemFontOfSize(40)
        
        // image
        var image: UIImage?
        switch index {
        case 9: image = UIImage(named: "globe")
        case 10: image = UIImage(named: "return")
        case 12: image = UIImage(named: "backspace")
        default: break
        }
        button.setImage(image, forState: .Normal)
        
        // backgroundImage
        var backgroundImage = UIColor.whiteColor().toImage()
        button.setBackgroundImage(backgroundImage, forState: .Normal)
        backgroundImage = backgroundColor.toImage()
        button.setBackgroundImage(backgroundImage, forState: .Highlighted)
        button.setBackgroundImage(backgroundImage, forState: .Selected)
        
        // tintColor
        button.tintColor = foregroundColor
        
        // target
        button.addTarget(self, action: "buttonTouchDown:", forControlEvents: .TouchDown)
    }
    
    func numPad(numPad: NumPad, sizeForButtonAtPosition position: Position, defaultSize size: CGSize) -> CGSize {
        let index = numPad.indexForPosition(position)
        var size = size
        if case 9...10 = index {
            size.width = (numPad.frame.width / 6)
        } else if case 11...12 = index {
            size.width = (numPad.frame.width / 3)
        }
        return size
    }
    
    func numPad(numPad: NumPad, buttonTappedAtPosition position: Position) {
        let index = numPad.indexForPosition(position)
        switch index {
        case 9: advanceToNextInputMode()
        case 10: textDocumentProxy.insertText("\n")
        case 12: textDocumentProxy.deleteBackward()
        default:
            guard let
                button = numPad.buttonForPosition(position),
                text = button.titleLabel?.text
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
        var rect = CGRectZero
        rect.size = size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(CGImage: image.CGImage!)
    }
    
}

extension UIDevice {
    
    func hasOpenAccess() -> Bool {
        return UIPasteboard.generalPasteboard().isKindOfClass(UIPasteboard)
    }
    
}
