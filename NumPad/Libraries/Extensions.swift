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

extension UIFont {
    
    func bold() -> UIFont? {
        return fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) }
    }
    
}

extension NSMutableAttributedString {
    
    func addAttributes(_ attributes: TextAttributes, string: String) {
        let range = (self.string as NSString).range(of: string)
        addAttributes(attributes, range: range)
    }
    
}

extension String {
    
    func bold(_ string: String) -> NSAttributedString {
        let attributes = TextAttributes().font(.preferredFont(forTextStyle: .headline)).foregroundColor(.lightBlue)
        let text = NSMutableAttributedString(string: self)
        text.addAttributes(attributes, string: string)
        return text
    }
    
}

extension URL {
    
    static var keyboard: URL? {
        if #available(iOS 10.0, *) {
            return URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS")
        } else {
            return URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS")
        }
    }
    
}
