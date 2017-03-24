//
//  Keyboard.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/24/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation

struct Keyboard {
    
    enum Theme {
        case white, black, red, orange, yellow, green, tealBlue, blue, purple, pink
        
        var name: String {
            switch self {
            case .white:
                <#code#>
            case .black:
                <#code#>
            case .red:
                <#code#>
            case .orange:
                <#code#>
            case .yellow:
                <#code#>
            case .green:
                <#code#>
            case .tealBlue:
                <#code#>
            case .blue:
                <#code#>
            case .purple:
                <#code#>
            case .pink:
                <#code#>
            }
        }
        
        var color: UIColor {
            switch self {
            case .white:
                <#code#>
            case .black:
                <#code#>
            case .red:
                <#code#>
            case .orange:
                <#code#>
            case .yellow:
                <#code#>
            case .green:
                <#code#>
            case .tealBlue:
                <#code#>
            case .blue:
                <#code#>
            case .purple:
                <#code#>
            case .pink:
                <#code#>
            }
        }
        
        func enable() {
            
        }
    }
    
    static func isKeyboardEnabled() -> Bool {
        guard
            let id = Bundle.main.bundleIdentifier,
            let keyboards = Defaults.array(forKey: "AppleKeyboards") as? [String]
        else { return false }
        for keyboard in keyboards where keyboard.hasPrefix(id) {
            return true
        }
        return false
    }
    
}
