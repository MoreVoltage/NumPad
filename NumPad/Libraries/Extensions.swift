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
        guard #available(iOS 11.0, *) else { return preferredFont(forTextStyle: style) }
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
//        if #available(iOS 11.0, *) {
            return URL(string: UIApplication.openSettingsURLString)
//        } else if #available(iOS 10.0, *) {
//            return URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS")
//        } else {
//            return URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS")
//        }
    }
    
}

extension UIApplication {
    
    func safeOpen(_ url: URL) {
        if #available(iOS 10.0, *) {
            open(url)
        } else {
            openURL(url)
        }
    }
    
}
