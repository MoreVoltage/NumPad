//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import DynamicColor

extension KeyboardTheme {
    
    struct Scheme {
        let border: UIColor
    }
    
    static var scheme: Scheme {
        return UIColor.scheme(KeyboardTheme.selectedOrAutomatic)
    }
    
}

extension Item.Style {
    
    struct Scheme {
        let control: UIColor // title/image color
        let background: UIColor // background color
        let highlightedBackground: UIColor
    }
    
    var scheme: Scheme {
        return UIColor.itemScheme(KeyboardTheme.selectedOrAutomatic, style: self)
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
            let foreground: UIColor = white
            let background: UIColor = theme.color.lighter(amount: 0.1)
            let background2: UIColor = background.lighter(amount: 0.05)
            let highlightedBackground: UIColor = background.lighter(amount: 0.3)
            switch style {
            case .default:
                return ItemScheme(control: foreground, background: background, highlightedBackground: highlightedBackground)
            case .primary, .secondary:
                return ItemScheme(control: foreground, background: background2, highlightedBackground: highlightedBackground)
            }
        default:
            // Choose black or white text by the theme color's luminance so light themes
            // (lime/yellow/amber) get readable dark text instead of low-contrast white.
            let foreground: UIColor = theme.color.isLight() ? black : white
            let background: UIColor = theme.color
            let background2: UIColor = theme.color.isLight() ? theme.color.darkened(amount: 0.05) : theme.color.lighter(amount: 0.05)
            let highlightedBackground: UIColor = theme.color.isLight() ? theme.color.darkened(amount: 0.3) : theme.color.lighter(amount: 0.3)
            switch style {
            case .default:
                return ItemScheme(control: foreground, background: background, highlightedBackground: highlightedBackground)
            case .primary, .secondary:
                return ItemScheme(control: foreground, background: background2, highlightedBackground: highlightedBackground)
            }
        }
    }
    
}

extension UIFont {

    private static let numbersMetrics = UIFontMetrics(forTextStyle: .title1)
    private static let textMetrics = UIFontMetrics(forTextStyle: .caption1)

    /// Scale factor for iPad height presets so button text grows with the keyboard.
    private static var iPadScale: CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return 1.0 }
        switch UserPrefs.iPadHeightPreset {
        case 1: return 1.4  // medium
        case 2: return 1.8  // large
        default: return 1.0
        }
    }

    static var numbers: UIFont {
        return numbersMetrics.scaledFont(for: .systemFont(ofSize: 27 * iPadScale, weight: .regular))
    }

    static var text: UIFont {
        return textMetrics.scaledFont(for: .systemFont(ofSize: 14 * iPadScale, weight: .regular))
    }

}

extension String {
    static let space = NSLocalizedString("Space", comment: "")
    static let enter = NSLocalizedString("Enter", comment: "")

    static let unlock = NSLocalizedString("Unlock", comment: "Tooltip shown on a premium-locked key")
}
