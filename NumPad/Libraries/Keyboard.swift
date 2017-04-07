//
//  Keyboard.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/24/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

struct Keyboard {
    
    enum Theme {
        case white, black, red, orange, yellow, green, tealBlue, blue, purple, pink
        
        static let all: [Theme] = [.white, .black, .red, .orange, .yellow, .green, .tealBlue, .blue, .purple, .pink]
        
        var name: String {
            switch self {
            case .white:
                return "White"
            case .black:
                return "Black"
            case .red:
                return "Red"
            case .orange:
                return "Orange"
            case .yellow:
                return "Yellow"
            case .green:
                return "Green"
            case .tealBlue:
                return "Teal Blue"
            case .blue:
                return "Blue"
            case .purple:
                return "Purple"
            case .pink:
                return "Pink"
            }
        }
        
        var color: UIColor {
            switch self {
            case .white:
                return .white
            case .black:
                return .black
            case .red:
                return Color.red
            case .orange:
                return Color.orange
            case .yellow:
                return Color.yellow
            case .green:
                return Color.green
            case .tealBlue:
                return Color.tealBlue
            case .blue:
                return Color.blue
            case .purple:
                return Color.purple
            case .pink:
                return Color.pink
            }
        }
        
        func enable() {
            
        }
    }
    
    static var isKeyboardEnabled: Bool {
        guard let id = bundleIdentifier else { return false }
        return !id.isEmpty
    }
    
    static var bundleIdentifier: String? {
        guard
            let id = Bundle.main.bundleIdentifier,
            let keyboards = Defaults.array(forKey: "AppleKeyboards") as? [String]
        else { return nil }
        for keyboard in keyboards where keyboard.hasPrefix(id) {
            return keyboard
        }
        return nil
    }
    
    static var isNightMode: Bool {
        get { return Defaults.bool(forKey: "nightMode") }
        set { Defaults.set(newValue, forKey: "nightMode") }
    }
    
}
