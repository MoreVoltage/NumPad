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
}

extension UIView {
    
    @discardableResult
    func constrainToEdges(_ inset: UIEdgeInsets = UIEdgeInsets()) -> [NSLayoutConstraint] {
        return constrain {[
            $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: inset.top),
            $0.leftAnchor.constraint(equalTo: $0.superview!.leftAnchor, constant: inset.left),
            $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: inset.bottom),
            $0.rightAnchor.constraint(equalTo: $0.superview!.rightAnchor, constant: inset.right)
        ]}
    }
    
    @discardableResult
    func constrain(constraints: (UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        let constraints = constraints(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
    func constraint(attribute: NSLayoutAttribute) -> NSLayoutConstraint? {
        return constraints.filter { $0.firstAttribute == attribute }.first
    }
    
}

extension UILayoutPriority {
    
    static func +(lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        return UILayoutPriority(lhs.rawValue + rhs)
    }
    
    static func -(lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        return UILayoutPriority(lhs.rawValue - rhs)
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
        return cache[color] ?? {
            let image = UIImage(color: color)
            cache[color] = image
            return image
        }()
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
    
    class func white(_ white: CGFloat) -> UIColor {
        return UIColor(white: white, alpha: 1)
    }
    
    class var lightBlue: UIColor {
        return UIColor(red: 51, green: 143, blue: 252)
    }
    
    class var text: UIColor {
        return .white(0.22)
    }
    
    struct Custom {
        static var red: UIColor {
            return UIColor(red: 255, green: 59, blue: 48)
        }
        
        static var orange: UIColor {
            return UIColor(red: 255, green: 149, blue: 0)
        }
        
        static var yellow: UIColor {
            return UIColor(red: 255, green: 204, blue: 0)
        }
        
        static var green: UIColor {
            return UIColor(red: 76, green: 217, blue: 100)
        }
        
        static var tealBlue: UIColor {
            return UIColor(red: 90, green: 200, blue: 250)
        }
        
        static var blue: UIColor {
            return UIColor(red: 0, green: 122, blue: 255)
        }
        
        static var purple: UIColor {
            return UIColor(red: 88, green: 86, blue: 214)
        }
        
        static var pink: UIColor {
            return UIColor(red: 255, green: 45, blue: 85)
        }
    }
    
}

enum Constants: String {
    case reversedMode, selectedKeyboardType, selectedKeyboardTheme
}

import Crashlytics
import FirebaseAnalytics

struct Analytics {
    static func logCustomEvent(name: String, attributes: [String: Any]? = nil) {
        let attributes = attributes?.mapValues {
            $0 is Bool ? "\($0)" : $0
        }
        Answers.logCustomEvent(withName: name, customAttributes: attributes)
        FirebaseAnalytics.Analytics.logEvent(name, parameters: attributes)
    }
    static func logContentView(name: String?, contentType: String? = nil, contentId: String? = nil, attributes: [String: Any]? = nil) {
        Answers.logContentView(withName: name, contentType: contentType, contentId: contentId, customAttributes: attributes)
    }
}
