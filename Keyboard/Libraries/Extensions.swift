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
        let background: UIColor // background color
        let highlightedBackground: UIColor
    }
    
    var scheme: Scheme {
        return UIColor.itemScheme(KeyboardTheme.selected, style: self)
    }
    
}

private extension UIColor {
    
    typealias Scheme = KeyboardTheme.Scheme
    typealias ItemScheme = Item.Style.Scheme
    
    // keyboard styling
    static func scheme(_ theme: KeyboardTheme) -> Scheme {
        switch theme {
        case .black:
            return Scheme(border: black.lighter(amount: 0.2))
        default:
            return Scheme(border: theme == .white ? theme.color.darkened(amount: 0.1) : theme.color.lighter(amount: 0.1))
        }
    }
    
    // keyboard item styling
    static func itemScheme(_ theme: KeyboardTheme, style: Item.Style) -> ItemScheme {
        switch theme {
        case .black:
            let background: UIColor = theme.color.lighter(amount: 0.1)
            let highlightedBackground: UIColor = background.lighter(amount: 0.05)
            let highlightedBackground2: UIColor = background.lighter(amount: 0.1)
            switch style {
            case .default:
                return ItemScheme(control: white, background: background, highlightedBackground: highlightedBackground)
            case .primary, .secondary:
                return ItemScheme(control: white, background: highlightedBackground, highlightedBackground: highlightedBackground2)
            }
        default:
            let foreground: UIColor = theme == .white ? black : white
            let background: UIColor = theme.color.isLight() ? theme.color.darkened(amount: 0.05) : theme.color.lighter(amount: 0.05)
            let highlightedBackground: UIColor = theme.color.isLight() ? theme.color.darkened(amount: 0.1) : theme.color.lighter(amount: 0.1)
            switch style {
            case .default:
                return ItemScheme(control: foreground, background: theme.color, highlightedBackground: background)
            case .primary, .secondary:
                return ItemScheme(control: foreground, background: background, highlightedBackground: highlightedBackground)
            }
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
