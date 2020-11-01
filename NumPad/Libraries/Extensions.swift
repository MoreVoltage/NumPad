//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import TextAttributes

enum AppStoryboard: String {
    case Main
    
    var instance: UIStoryboard {
        return UIStoryboard(name: rawValue, bundle: .main)
    }
    
    func viewController<T: UIViewController>(of type: T.Type) -> T {
        return instance.instantiateViewController(withIdentifier: type.storyboardId) as! T
    }
}

extension UIViewController {
    class var storyboardId: String {
        return "\(self)"
    }
    
    static func instantiate(from appStoryboard: AppStoryboard = .Main) -> Self {
        return appStoryboard.viewController(of: self)
    }
    
    func add(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }
}

// MARK: -

extension Bundle {
    var version: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var build: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var bundleName: String? {
        return infoDictionary?[kCFBundleNameKey as String] as? String
    }
}

// MARK: -

extension UIFont {
    static var body: UIFont {
        return preferredFont(for: .body)
    }
    static func preferredFont(for style: TextStyle, weight: Weight = .regular) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: style)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let font = UIFont.systemFont(ofSize: desc.pointSize, weight: weight)
        return metrics.scaledFont(for: font)
    }
}

// MARK: -

extension String {
    
    func bold(_ strings: String..., color: UIColor, font: UIFont) -> NSAttributedString {
        let attributes = TextAttributes().foregroundColor(color).font(font)
        let text = NSMutableAttributedString(string: self)
        for string in strings {
            text.addAttributes(attributes, string: string)
        }
        return text
    }
    
}

extension NSMutableAttributedString {
    
    func addAttributes(_ attributes: TextAttributes, string: String) {
        let range = (self.string as NSString).range(of: string)
        addAttributes(attributes, range: range)
    }
    
}

// MARK: -

extension URL {
    static var keyboard: URL? {
        return URL(string: UIApplication.openSettingsURLString)
    }
}

// MARK: -

extension String {
    // Instructions
    static let instructions = NSLocalizedString("Instructions", comment: "")
    static let instructionsTitle = NSLocalizedString("Enable Keyboard", comment: "")
    static let instructionsItem1 = String(format: NSLocalizedString("Open Settings and go to %@", comment: ""), bundleName)
    static let instructionsItem2 = NSLocalizedString("Tap Keyboards", comment: "")
    static let instructionsItem3 = String(format: NSLocalizedString("Turn on %@", comment: ""), bundleName)
    
    static let instructionsHeader = String(format: NSLocalizedString("Almost done! Turn on the %@ Keyboard by going to Settings and following the steps below.", comment: ""), bundleName)
    static let instructionsFooter = NSLocalizedString("Enable Full Access for click sounds. Nothing you type is tracked.", comment: "")
    static let goToSettings = NSLocalizedString("Go to Settings", comment: "")
    static let settings = NSLocalizedString("Settings", comment: "")
    static let keyboards = NSLocalizedString("Keyboards", comment: "")
    static let bundleKeyboard = String(format: NSLocalizedString("%@ Keyboard", comment: ""), bundleName)
    static let fullAccess = NSLocalizedString("Full Access", comment: "")
    static let nothingTracked = NSLocalizedString("Nothing you type is tracked", comment: "")
    
    // Home
    static let enableKeyboard = NSLocalizedString("Enable Keyboard", comment: "")
    static let theme = NSLocalizedString("Theme", comment: "")
    static let reversed = NSLocalizedString("Reversed", comment: "")
    static let rounded = NSLocalizedString("Rounded", comment: "")
    static let grid = NSLocalizedString("Grid", comment: "")
    static let mathPack = NSLocalizedString("Math Pack", comment: "")
    static let rateMe = NSLocalizedString("Rate Me", comment: "")
    
    // Theme
    static let automaticDarkMode = NSLocalizedString("Automatic Dark Mode", comment: "")
    
    // Common
    static let bundleName = Bundle.main.bundleName!
}

// MARK: -

func configure<T>(_ object: T, using closure: (inout T) -> Void) -> T {
    var object = object
    closure(&object)
    return object
}
