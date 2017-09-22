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
        return UIStoryboard(name: rawValue, bundle: Bundle.main)
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
    
    static var regular: UIFont {
        return systemFont(ofSize: 17, weight: .regular)
    }
    
    static var regularSmall: UIFont {
        return systemFont(ofSize: 12, weight: .regular)
    }
    
    static var bold: UIFont {
        return systemFont(ofSize: 16, weight: .bold)
    }
    
    static var boldSmall: UIFont {
        return systemFont(ofSize: 11, weight: .bold)
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
        if #available(iOS 10.0, *) {
            return URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS")
        } else {
            return URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS")
        }
    }
    
}
