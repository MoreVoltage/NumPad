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
    static func synchronize() {
        standard.synchronize()
        group.synchronize()
    }
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

extension TinyConstraints.Constrainable where Self: UIView {
    @discardableResult
    func edges(_ insets: UIEdgeInsets = .zero, priority: UILayoutPriority = .required) -> Constraints {
        return edgesToSuperview(insets: insets, priority: priority)
    }
}

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

extension UIImage {
    
    static var cache = [UIColor: UIImage]()
    
    static func image(color: UIColor) -> UIImage {
        return cache[color].get(orSet: UIImage(color: color))
    }
    
    convenience init(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        var rect = CGRect()
        rect.size = size
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
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
    }
    
    class var lightBlue: UIColor {
        return UIColor(red: 51, green: 143, blue: 252)
    }
    
    class var text: UIColor {
        return UIColor(white: 0.22, alpha: 1)
    }
    
}

enum Constants: String {
    case reversedMode, roundedCorners, selectedKeyboardType, selectedKeyboardTheme
}

import FirebaseCore
import FirebaseAnalytics
import Fabric
import Crashlytics

struct Analytics {
    static let start: Void = {
        FirebaseApp.configure()
        Fabric.with([Crashlytics.self])
    }()
    static func logEvent(name: String, attributes: [String: Any] = [:]) {
        let attributes = attributes.mapValues {
            $0 is Bool ? "\($0)" : $0
        }
        FirebaseAnalytics.Analytics.logEvent(name, parameters: attributes)
    }
    static let ParameterValue = FirebaseAnalytics.AnalyticsParameterValue
}
