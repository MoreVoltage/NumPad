//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import DynamicColor

let Defaults = UserDefaults(suiteName: "group.morevoltage.numpad.container")!

extension UIView {
    
    @discardableResult
    func constrainToEdges(_ inset: UIEdgeInsets = UIEdgeInsets()) -> [NSLayoutConstraint] {
        return constrain {[
            $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: inset.top),
            $0.leadingAnchor.constraint(equalTo: $0.superview!.leadingAnchor, constant: inset.left),
            $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: inset.bottom),
            $0.trailingAnchor.constraint(equalTo: $0.superview!.trailingAnchor, constant: inset.right)
        ]}
    }
    
    @discardableResult
    func constrain(constraints: (UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        let constraints = constraints(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
}

extension UIDevice {
    
    func hasOpenAccess() -> Bool {
        if #available(iOSApplicationExtension 10.0, *) {
            let string = UIPasteboard.general.string
            UIPasteboard.general.string = "TEST"
            defer { UIPasteboard.general.string = string ?? "" }
            return UIPasteboard.general.hasStrings
        } else {
            return UIPasteboard.general.isKind(of: UIPasteboard.self)
        }
    }
    
}

extension UIColor {
    
    class func white(_ white: CGFloat) -> UIColor {
        return UIColor(white: white, alpha: 1)
    }
    
    struct Theme {
        let foreground: UIColor
        let background: UIColor
        let background2: UIColor
        let background3: UIColor
        let border: UIColor
    }
    
    class var theme: Theme {
        return Defaults.bool(forKey: "nightMode") ? themes[1] : themes[0]
    }
    
    private static let themes: [Theme] = [
        Theme(foreground: black, background: white, background2: white.darkened(amount: 0.15), background3: white.darkened(amount: 0.05), border: white.darkened(amount: 0.1)),
        Theme(foreground: white, background: white(0.21), background2: white(0.21).lighter(amount: 0.1), background3: white(0.21).lighter(amount: 0.1), border: white(0.21).lighter(amount: 0.2))
    ]
    
}

extension UIImage {
    
    convenience init(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        var rect = CGRect()
        rect.size = size
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
    }
    
}

extension UIButton {
    
    var title: String? {
        get { return self.title(for: UIControlState()) }
        set { setTitle(newValue, for: UIControlState()) }
    }
    
    var titleColor: UIColor? {
        get { return self.titleColor(for: UIControlState()) }
        set { setTitleColor(newValue, for: UIControlState()) }
    }
    
    var image: UIImage? {
        get { return self.image(for: UIControlState()) }
        set { setImage(newValue, for: UIControlState()) }
    }
    
    var backgroundImage: UIImage? {
        get { return self.backgroundImage(for: UIControlState()) }
        set { setBackgroundImage(newValue, for: UIControlState()) }
    }
    
}

extension UIFont {
    
    private enum SFUIDisplay: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIDisplay-\(rawValue)", size: fontSize)!
        }
    }
    
    private enum SFUIText: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIText-\(rawValue)", size: fontSize)!
        }
    }
    
    static let numbers: UIFont = UIFont.SFUIDisplay.Regular.size(27)
    static let text: UIFont = UIFont.SFUIText.Regular.size(14)
    
}
