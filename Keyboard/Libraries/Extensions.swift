//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import DynamicColor

extension UIDevice {
    
    var hasOpenAccess: Bool {
        let pasteboard = UIPasteboard.general
        if #available(iOSApplicationExtension 10.0, *) {
            if pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages || pasteboard.hasColors { return true }
            let string = pasteboard.string
            pasteboard.string = "TEST"
            defer { pasteboard.string = string ?? "" }
            return pasteboard.hasStrings
        } else {
            return pasteboard.isKind(of: UIPasteboard.self)
        }
    }
    
}

extension UIColor {
    
    struct Theme {
        let foreground: UIColor
        let background: UIColor
        let background2: UIColor
        let background3: UIColor
        let border: UIColor
    }
    
    static var theme: Theme {
        return Keyboard.isNightMode ? themes[1] : themes[0]
    }
    
    private static let themes: [Theme] = [
        Theme(foreground: black, background: white, background2: white.darkened(amount: 0.15), background3: white.darkened(amount: 0.05), border: white.darkened(amount: 0.1)),
        Theme(foreground: white, background: white(0.21), background2: white(0.21).lighter(amount: 0.1), background3: white(0.21).lighter(amount: 0.1), border: white(0.21).lighter(amount: 0.2))
    ]
    
}

extension UIFont {
    
    static let numbers: UIFont = UIFont.SFUIDisplay.Regular.size(27)
    static let text: UIFont = UIFont.SFUIText.Regular.size(14)
    
}
