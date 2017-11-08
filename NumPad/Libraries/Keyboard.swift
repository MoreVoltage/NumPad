//
//  Keyboard.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/24/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

struct Keyboard {
    
    static var isKeyboardEnabled: Bool {
        guard let id = bundleIdentifier else { return false }
        return !id.isEmpty
    }
    
    static var bundleIdentifier: String? {
        guard
            let id = Bundle.main.bundleIdentifier,
            let keyboards = UserDefaults.group.array(forKey: "AppleKeyboards") as? [String]
        else { return nil }
        for keyboard in keyboards where keyboard.hasPrefix(id) {
            return keyboard
        }
        return nil
    }
    
    static var isReversedMode: Bool {
        get { return UserDefaults.group.bool(forKey: Constants.reversedMode.rawValue) }
        set { UserDefaults.group.set(newValue, forKey: Constants.reversedMode.rawValue) }
    }
    
}

enum KeyboardType: String {
    case `default`, math, finance
    
    var name: String {
        switch self {
        case .default:
            return "Default"
        case .math:
            return "Math"
        case .finance:
            return "Finance"
        }
    }
    
    static var selected: KeyboardType {
        get { return UserDefaults.group.string(forKey: Constants.selectedKeyboardType.rawValue).flatMap { KeyboardType(rawValue: $0) } ?? .default }
        set { UserDefaults.group.set(newValue.rawValue, forKey: Constants.selectedKeyboardType.rawValue) }
    }
    
    var isSelected: Bool {
        return KeyboardType.selected == self
    }
}

enum KeyboardTheme: String {
    case white, black, red, orange, yellow, green, tealBlue, blue, purple, pink
    
    static let all: [KeyboardTheme] = [white, black, red, orange, yellow, green, tealBlue, blue, purple, pink]
    
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
    
    static var selected: KeyboardTheme {
        get { return UserDefaults.group.string(forKey: Constants.selectedKeyboardTheme.rawValue).flatMap { KeyboardTheme(rawValue: $0) } ?? .white }
        set { UserDefaults.group.set(newValue.rawValue, forKey: Constants.selectedKeyboardTheme.rawValue) }
    }
    
    var isSelected: Bool {
        return KeyboardTheme.selected == self
    }
}
