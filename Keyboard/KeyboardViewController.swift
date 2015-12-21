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
        if case 9...12 = indexPath.item {
            if indexPath.item == 11 {
                return "0"
            }
            return nil
        }
        return "\(indexPath.item + 1)"
    }
    
    func numberPad(numberPad: LENumberPad!, buttonTitleColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        return UIColor(white: 0.3, alpha: 1)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonTitleFontForButtonAtIndexPath indexPath: NSIndexPath!) -> UIFont! {
        return UIFont.systemFontOfSize(40)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonImageForButtonAtIndexPath indexPath: NSIndexPath!) -> UIImage! {
        if indexPath.item == 9 {
            return UIImage(named: "globe")
        } else if indexPath.item == 10 {
            return UIImage(named: "return")
        } else if indexPath.item == 12 {
            return UIImage(named: "backspace")
        }
        return nil
    }
    
    func numberPad(numberPad: LENumberPad!, buttonBackgroundColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        return .whiteColor()
    }
    
    func numberPad(numberPad: LENumberPad!, buttonBackgroundHighlightedColorForButtonAtIndexPath indexPath: NSIndexPath!) -> UIColor! {
        return UIColor(white: 0.9, alpha: 1)
    }
    
    func numberPad(numberPad: LENumberPad!, buttonSizeForButtonAtIndexPath indexPath: NSIndexPath!, defaultSize size: CGSize) -> CGSize {
        var size = size
        if case 9...12 = indexPath.item {
            var numberOfColumns: CGFloat = 3
            size.width = (numberPad.frame.width / numberOfColumns)
            size.width -= numberPad.separatorWidth * ((numberOfColumns - 1) / numberOfColumns)
            if case 9...10 = indexPath.item {
                numberOfColumns = 2
                size.width /= numberOfColumns
                size.width -= numberPad.separatorWidth * ((numberOfColumns - 1) / numberOfColumns)
                size.width -= 0.001
            }
        }
        return size
    }
    
}

// MARK: - LENumberPadDelegate
extension KeyboardViewController: LENumberPadDelegate {
    
    func numberPad(numberPad: LENumberPad!, didSelectButtonAtIndexPath indexPath: NSIndexPath!) {
        if indexPath.item == 9 {
            advanceToNextInputMode()
        } else if indexPath.item == 10 {
            textDocumentProxy.insertText("\n")
        } else if indexPath.item == 12 {
            textDocumentProxy.deleteBackward()
        } else {
            let button = numberPad.buttonAtIndexPath(indexPath)
            if let text = button.titleLabel?.text {
                textDocumentProxy.insertText(text)
            }
        }
    }
    
}
