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
            let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String]
        else { return nil }
        return keyboards.first { $0.hasPrefix(id) }
    }
    
    @UserDefault(key: Constants.reversedMode.rawValue, defaultValue: false, userDefaults: .group)
    static var isReversedMode: Bool
    
    @UserDefault(key: Constants.roundedCorners.rawValue, defaultValue: false, userDefaults: .group)
    static var hasRoundedCorners: Bool

    @UserDefault(key: Constants.grid.rawValue, defaultValue: true, userDefaults: .group)
    static var hasGrid: Bool
    
}

enum KeyboardType: String {
    case `default`, math, math2, finance, symbols, programmer, tax
    
    static var packs: [KeyboardType] {
        return [.math, .math2, .finance, .symbols, .programmer, .tax]
    }
    
    var name: String {
        switch self {
        case .default:
            return "Default"
        case .math, .math2:
            return "Math"
        case .finance:
            return "Finance"
        case .symbols:
            return "Symbols"
        case .programmer:
            return "Programmer"
        case .tax:
            return "Tax/Tips"
        }
    }
    
    @UserDefault(key: Constants.selectedKeyboardType.rawValue, defaultValue: nil, userDefaults: .group)
    private static var _selected: String?
    static var selected: KeyboardType {
        get { return _selected.flatMap(KeyboardType.init) ?? .default }
        set { _selected = newValue.rawValue }
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
        case .deepPurple: return NSLocalizedString("Deep Purple", comment: "")
        case .lightBlue: return NSLocalizedString("Light Blue", comment: "")
        case .lightGreen: return NSLocalizedString("Light Green", comment: "")
        case .deepOrange: return NSLocalizedString("Deep Orange", comment: "")
        default: return NSLocalizedString(rawValue.capitalized, comment: "")
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
    
    @UserDefault(key: Constants.selectedKeyboardTheme.rawValue, defaultValue: KeyboardTheme.white.rawValue, userDefaults: .group)
    private static var _selected: String
    
    static var selected: KeyboardTheme {
        get { return KeyboardTheme(rawValue: _selected) ?? .white }
        set { _selected = newValue.rawValue }
    }
    
    var isSelected: Bool {
        return KeyboardTheme.selected == self
    }
    
    static var selectedOrAutomatic: KeyboardTheme {
        if automaticDarkMode {
            return Theme.isDarkMode ? .black : .white
        }
        return selected
    }
    
    @UserDefault(key: Constants.automaticDarkMode.rawValue, defaultValue: false, userDefaults: .group)
    static var automaticDarkMode: Bool
}
