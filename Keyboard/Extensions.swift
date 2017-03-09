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
    
    static var cache = Cache()
    
    struct Cache {
        var hasOpenAccess: Bool = false
        
        mutating func refresh() {
            hasOpenAccess = current.hasOpenAccess()
        }
    }
    
    private func hasOpenAccess() -> Bool {
        if #available(iOSApplicationExtension 10.0, *) {
            let string = UIPasteboard.general.string
            UIPasteboard.general.string = "TEST"
            defer { UIPasteboard.general.string = string ?? "" }
            return UIPasteboard.general.hasStrings
        } else {
            return UIPasteboard.general.isKind(of: UIPasteboard.self)
        }
    }
    
}

extension UIColor {
    
    class func white(_ white: CGFloat) -> UIColor {
        return UIColor(white: white, alpha: 1)
    }
    
    static var cache = Cache()
    
    struct Cache {
        var theme: Theme = UIColor.themes[1]
        
        mutating func refresh() {
            theme = UIColor.theme
        }
    }
    
    struct Theme {
        let foreground: UIColor
        let background: UIColor
        let background2: UIColor
        let background3: UIColor
        let border: UIColor
    }
    
    private static var theme: Theme {
        return Defaults.bool(forKey: "nightMode") ? themes[1] : themes[0]
    }
    
    private static let themes: [Theme] = [
        Theme(foreground: black, background: white, background2: white.darkened(amount: 0.15), background3: white.darkened(amount: 0.05), border: white.darkened(amount: 0.1)),
        Theme(foreground: white, background: white(0.21), background2: white(0.21).lighter(amount: 0.1), background3: white(0.21).lighter(amount: 0.1), border: white(0.21).lighter(amount: 0.2))
    ]
    
}

extension UIFont {
    
    private enum SFUIDisplay: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIDisplay-\(rawValue)", size: fontSize)!
        }
    }
    
    private enum SFUIText: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIText-\(rawValue)", size: fontSize)!
        }
    }
    
    static let numbers: UIFont = UIFont.SFUIDisplay.Regular.size(27)
    static let text: UIFont = UIFont.SFUIText.Regular.size(14)
    
}
