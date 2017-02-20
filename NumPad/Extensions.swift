//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

let Defaults = UserDefaults(suiteName: "group.morevoltage.numpad.container")!

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

extension UIView {
    
    @discardableResult
    func constrain(constraints: (UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        let constraints = constraints(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
}

extension UIColor {
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
    }
    
    class var myBlue: UIColor {
        return UIColor(red: 51, green: 143, blue: 252)
    }
    
}
