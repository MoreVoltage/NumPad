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
    
    struct Scheme {
        let border: UIColor
    }
    
    static var scheme: Scheme {
        return UIColor.scheme(KeyboardTheme.selected)
    }
    
}

extension Item.Style {
    
    struct Scheme {
        let control: UIColor // title/image color
        let highlightedControl: UIColor
        let background: UIColor // background color
        let highlightedBackground: UIColor
    }
    
    var scheme: Scheme {
        return UIColor.itemScheme(KeyboardTheme.selected, itemStyle: self)
    }
    
}

private extension UIColor {
    
    typealias Scheme = KeyboardTheme.Scheme
    typealias ItemScheme = Item.Style.Scheme
    
    // keyboard styling
    static func scheme(_ theme: KeyboardTheme) -> Scheme {
        switch theme {
        case .black:
            return Scheme(border: black)
        default:
            return Scheme(border: white(0.9))
        }
    }
    
    // keyboard item styling
    static func itemScheme(_ theme: KeyboardTheme, itemStyle: Item.Style) -> ItemScheme {
        switch itemStyle {
        case .default:
            switch theme {
            default:
                return ItemScheme(control: black, highlightedControl: black, background: white.darkened(amount: 0.15), highlightedBackground: white.darkened(amount: 0.05))
            }
        default:
            return ItemScheme(control: black, highlightedControl: white, background: white.darkened(amount: 0.15), highlightedBackground: white.darkened(amount: 0.05))
        }
    }
    
}

extension UIFont {
    
    static var numbers: UIFont {
        return systemFont(ofSize: 27, weight: .regular)
    }
    
    static var text: UIFont {
        return systemFont(ofSize: 14, weight: .regular)
    }
    
}
