//
//  SharedExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/9/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.morevoltage.numpad.container")!
    static var cache = [String: Any]()
    func safeString(forKey defaultName: String) -> String? {
        return UserDefaults.cache[defaultName] as? String ?? string(forKey: defaultName)
    }
    func safeArray(forKey defaultName: String) -> [Any]? {
        return UserDefaults.cache[defaultName] as? [Any] ?? array(forKey: defaultName)
    }
    func safeBool(forKey defaultName: String) -> Bool {
        return UserDefaults.cache[defaultName] as? Bool ?? bool(forKey: defaultName)
    }
    func safeSet(_ value: Any?, forKey defaultName: String) {
        UserDefaults.cache[defaultName] = value
        set(value, forKey: defaultName)
    }
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults
    
    var wrappedValue: T {
        get { return userDefaults.object(forKey: key) as? T ?? defaultValue }
        set { userDefaults.set(newValue, forKey: key) }
    }
}

extension Optional {
    mutating func get(orSet expression: @autoclosure () -> Wrapped) -> Wrapped {
        guard let view = self else {
            let newView = expression()
            self = newView
            return newView
        }
        return view
    }
}

import TinyConstraints

extension UIButton {
    
    var title: String? {
        get { return title(for: .normal) }
        set { setTitle(newValue, for: .normal) }
    }
    
    var titleColor: UIColor? {
        get { return titleColor(for: .normal) }
        set { setTitleColor(newValue, for: .normal) }
    }
    
    var image: UIImage? {
        get { return image(for: .normal) }
        set { setImage(newValue, for: .normal) }
    }
    
    var backgroundImage: UIImage? {
        get { return backgroundImage(for: .normal) }
        set { setBackgroundImage(newValue, for: .normal) }
    }
    
}

typealias Color = UIColor.Custom

extension UIColor {
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
    
    struct Custom {
        static var red: UIColor { return UIColor(red: 244, green: 67, blue: 54) }
        static var pink: UIColor { return UIColor(red: 233, green: 30, blue: 99) }
        static var purple: UIColor { return UIColor(red: 156, green: 39, blue: 176) }
        static var deepPurple: UIColor { return UIColor(red: 103, green: 58, blue: 183) }
        static var indigo: UIColor { return UIColor(red: 63, green: 81, blue: 181) }
        static var blue: UIColor { return UIColor(red: 33, green: 150, blue: 243) }
        static var lightBlue: UIColor { return UIColor(red: 3, green: 169, blue: 244) }
        static var teal: UIColor { return UIColor(red: 0, green: 150, blue: 136) }
        static var green: UIColor { return UIColor(red: 76, green: 175, blue: 80) }
        static var lightGreen: UIColor { return UIColor(red: 139, green: 195, blue: 74) }
        static var lime: UIColor { return UIColor(red: 205, green: 220, blue: 57) }
        static var yellow: UIColor { return UIColor(red: 255, green: 235, blue: 59) }
        static var amber: UIColor { return UIColor(red: 255, green: 193, blue: 7) }
        static var orange: UIColor { return UIColor(red: 255, green: 152, blue: 0) }
        static var deepOrange: UIColor { return UIColor(red: 255, green: 87, blue: 34) }
        
//        static var red: UIColor { KeyboardTheme.isDarkMode ? red500 : red500 }
//        static var red500: UIColor { return UIColor(red: 244, green: 67, blue: 54) }
//        static var pink: UIColor { KeyboardTheme.isDarkMode ? pink500 : pink500 }
//        static var pink500: UIColor { return UIColor(red: 233, green: 30, blue: 99) }
//        static var purple: UIColor { KeyboardTheme.isDarkMode ? purple500 : purple500 }
//        static var purple500: UIColor { return UIColor(red: 156, green: 39, blue: 176) }
//        static var deepPurple: UIColor { KeyboardTheme.isDarkMode ? deepPurple500 : deepPurple500 }
//        static var deepPurple500: UIColor { return UIColor(red: 103, green: 58, blue: 183) }
//        static var indigo: UIColor { KeyboardTheme.isDarkMode ? indigo500 : indigo500 }
//        static var indigo500: UIColor { return UIColor(red: 63, green: 81, blue: 181) }
//        static var blue: UIColor { KeyboardTheme.isDarkMode ? blue500 : blue500 }
//        static var blue200: UIColor { return UIColor(red: 129, green: 212, blue: 250) }
//        static var blue500: UIColor { return UIColor(red: 33, green: 150, blue: 243) }
//        static var lightBlue: UIColor { KeyboardTheme.isDarkMode ? lightBlue500 : lightBlue500 }
//        static var lightBlue500: UIColor { return UIColor(red: 3, green: 169, blue: 244) }
//        static var teal: UIColor { KeyboardTheme.isDarkMode ? teal500 : teal500 }
//        static var teal500: UIColor { return UIColor(red: 0, green: 150, blue: 136) }
//        static var green: UIColor { KeyboardTheme.isDarkMode ? green500 : green500 }
//        static var green500: UIColor { return UIColor(red: 76, green: 175, blue: 80) }
//        static var lightGreen: UIColor { KeyboardTheme.isDarkMode ? lightGreen500 : lightGreen500 }
//        static var lightGreen500: UIColor { return UIColor(red: 139, green: 195, blue: 74) }
//        static var lime: UIColor { KeyboardTheme.isDarkMode ? lime500 : lime500 }
//        static var lime500: UIColor { return UIColor(red: 205, green: 220, blue: 57) }
//        static var yellow: UIColor { KeyboardTheme.isDarkMode ? yellow500 : yellow500 }
//        static var yellow500: UIColor { return UIColor(red: 255, green: 235, blue: 59) }
//        static var amber: UIColor { KeyboardTheme.isDarkMode ? amber500 : amber500 }
//        static var amber500: UIColor { return UIColor(red: 255, green: 193, blue: 7) }
//        static var orange: UIColor { KeyboardTheme.isDarkMode ? orange500 : orange500 }
//        static var orange500: UIColor { return UIColor(red: 255, green: 152, blue: 0) }
//        static var deepOrange: UIColor { KeyboardTheme.isDarkMode ? deepOrange500 : deepOrange500 }
//        static var deepOrange500: UIColor { return UIColor(red: 255, green: 87, blue: 34) }
    }
    
    class var primary: UIColor {
        if #available(iOS 13.0, *) {
            return systemBlue
        } else {
            return UIColor(red: 51, green: 143, blue: 252)
        }
    }
    
    class var text: UIColor {
        guard #available(iOS 13.0, *) else { return UIColor(white: 0.22, alpha: 1) }
        return label
    }
    
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            self.setFill()
            context.fill(.init(origin: .zero, size: size))
        }
    }
    
}

struct Theme {
    static var isDarkMode: Bool {
        guard #available(iOS 13.0, *) else { return false }
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
}

enum Constants: String {
    case reversedMode, roundedCorners, grid, selectedKeyboardType, selectedKeyboardTheme, automaticDarkMode
}

import Firebase
import FirebaseAnalytics

struct Analytics {
    static let start: Void = {
        FirebaseApp.configure()
    }()
    static func logEvent(name: String, attributes: [String: Any] = [:]) {
        let attributes = attributes.mapValues {
            $0 is Bool ? "\($0)" : $0
        }
        FirebaseAnalytics.Analytics.logEvent(name, parameters: attributes)
    }
    static let ParameterValue = FirebaseAnalytics.AnalyticsParameterValue
}
