//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 11/6/15.
//  Copyright © 2015 Lasha Efremidze. All rights reserved.
//

import UIKit
import LEAmountInputView

class KeyboardViewController: UIInputViewController {
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    
        // Add custom view sizing constraints here
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Perform custom UI setup here
        let numPad = LENumberPad()
        numPad.dataSource = self
        numPad.delegate = self
        numPad.layer.borderColor = UIColor(white: 0.9, alpha: 1).CGColor
        numPad.layer.borderWidth = 1
        numPad.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(numPad)
        
        let viewsDictionary = ["numPad": numPad]
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[numPad]|", options: [], metrics: nil, views: viewsDictionary))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[numPad]|", options: [], metrics: nil, views: viewsDictionary))
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

// MARK: - LENumberPadDataSource
extension KeyboardViewController: LENumberPadDataSource {
    
    func numberOfRowsInNumberPad(numberPad: LENumberPad!) -> Int {
        return 4
    }
    
    func numberPad(numberPad: LENumberPad!, numberOfColumnsInRow row: Int) -> Int {
        if row == 3 {
            return 4
        }
        return 3
    }
    
    func numberPad(numberPad: LENumberPad!, buttonTitleForButtonAtIndexPath indexPath: NSIndexPath!) -> String! {
        if indexPath.item == 9 {
            return "C"
        } else if indexPath.item == 10 {
            return "0"
        } else if indexPath.item == 11 {
            return "00"
        }
        return "\(indexPath.item + 1)"
    }
    
    func numberPad(numberPad: LENumberPad!, buttonTitleColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        if indexPath.item == 9 {
            return .orangeColor()
        }
        return UIColor(white: 0.3, alpha: 1)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonTitleFontForButtonAtIndexPath indexPath: NSIndexPath!) -> UIFont! {
        return UIFont.systemFontOfSize(40)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonBackgroundColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        return .whiteColor()
    }
    
    func numberPad(numberPad: LENumberPad!, buttonBackgroundHighlightedColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        return UIColor(white: 0.9, alpha: 1)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonSizeForButtonAtIndexPath indexPath: NSIndexPath!, defaultSize size: CGSize) -> CGSize {
        return size
    }
    
}

// MARK: - LENumberPadDelegate
extension KeyboardViewController: LENumberPadDelegate {
    
    func numberPad(numberPad: LENumberPad!, didSelectButtonAtIndexPath indexPath: NSIndexPath!) {
        if indexPath.item == 9 {
            textDocumentProxy.deleteBackward()
        } else {
            let button = numberPad.buttonAtIndexPath(indexPath)
            if let text = button.titleLabel?.text {
                textDocumentProxy.insertText(text)
            }
        }
    }
    
}
