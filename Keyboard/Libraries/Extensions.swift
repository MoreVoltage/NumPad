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

extension KeyboardTheme {
    
    // palette
    struct Scheme {
        let foreground: UIColor
        let background: UIColor
        let background2: UIColor
        let background3: UIColor
        let border: UIColor
    }
    
    // colorScheme
    static var scheme: Scheme {
        return UIColor.scheme(KeyboardTheme.selected)
    }
    
}

private extension UIColor {
    
    typealias Scheme = KeyboardTheme.Scheme
    
    static func scheme(_ theme: KeyboardTheme) -> Scheme {
        switch theme {
        case .white:
            return Scheme(foreground: black, background: white, background2: white.darkened(amount: 0.15), background3: white.darkened(amount: 0.05), border: white.darkened(amount: 0.1))
        case .black:
            return Scheme(foreground: white, background: white(0.21), background2: white(0.21).lighter(amount: 0.1), background3: white(0.21).lighter(amount: 0.1), border: white(0.21).lighter(amount: 0.2))
        default:
            let background = theme.color.lighter(amount: 0.1)
            return Scheme(foreground: white, background: theme.color, background2: background, background3: background, border: white.darkened(amount: 0.1))
        }
    }
    
}

extension UIFont {
    
    static let numbers: UIFont = systemFont(ofSize: 27, weight: .regular)
    static let text: UIFont = systemFont(ofSize: 14, weight: .regular)
    
}
