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
            let keyboards = UserDefaults.group.safeArray(forKey: "AppleKeyboards") as? [String]
        else { return nil }
        for keyboard in keyboards where keyboard.hasPrefix(id) {
            return keyboard
        }
        return nil
    }
    
    static var isReversedMode: Bool {
        get { return UserDefaults.group.safeBool(forKey: Constants.reversedMode.rawValue) }
        set { UserDefaults.group.safeSet(newValue, forKey: Constants.reversedMode.rawValue) }
    }
    
    static var hasRoundedCorners: Bool {
        get { return UserDefaults.group.safeBool(forKey: Constants.roundedCorners.rawValue) }
        set { UserDefaults.group.safeSet(newValue, forKey: Constants.roundedCorners.rawValue) }
    }
    
}

enum KeyboardType: String {
    case `default`, math, math2, finance
    
    static var packs: [KeyboardType] {
        return [.math, .math2, .finance]
    }
    
    var name: String {
        switch self {
        case .default:
            return "Default"
        case .math, .math2:
            return "Math"
        case .finance:
            return "Finance"
        }
    }
    
    static var selected: KeyboardType {
        get { return UserDefaults.group.safeString(forKey: Constants.selectedKeyboardType.rawValue).flatMap { KeyboardType(rawValue: $0) } ?? .default }
        set { UserDefaults.group.safeSet(newValue.rawValue, forKey: Constants.selectedKeyboardType.rawValue) }
    }
    
    var isSelected: Bool {
        return KeyboardType.selected == self
    }
    
    mutating func toggleMath() {
        switch self {
        case .math:
            self = .math2
        case .math2:
            self = .math
        default: break
        }
    }
}

enum KeyboardTheme: String, CaseIterable {
    case white, black, red, pink, purple, deepPurple, indigo, blue, lightBlue, teal, green, lightGreen, lime, yellow, amber, orange, deepOrange
    
    var name: String {
        switch self {
        case .deepPurple: return "Deep Purple"
        case .lightBlue: return "Light Blue"
        case .lightGreen: return "Light Green"
        case .deepOrange: return "Deep Orange"
        default: return rawValue.capitalized
        }
    }
    
    var color: UIColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .red: return Color.red
        case .pink: return Color.pink
        case .purple: return Color.purple
        case .deepPurple: return Color.deepPurple
        case .indigo: return Color.indigo
        case .blue: return Color.blue
        case .lightBlue: return Color.lightBlue
        case .teal: return Color.teal
        case .green: return Color.green
        case .lightGreen: return Color.lightGreen
        case .lime: return Color.lime
        case .yellow: return Color.yellow
        case .amber: return Color.amber
        case .orange: return Color.orange
        case .deepOrange: return Color.deepOrange
        }
    }
    
    static var selected: KeyboardTheme {
        get { return UserDefaults.group.safeString(forKey: Constants.selectedKeyboardTheme.rawValue).flatMap { KeyboardTheme(rawValue: $0) } ?? .white }
        set { UserDefaults.group.safeSet(newValue.rawValue, forKey: Constants.selectedKeyboardTheme.rawValue) }
    }
    
    var isSelected: Bool {
        return KeyboardTheme.selected == self
    }
}
