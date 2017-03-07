//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import TextAttributes

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

extension UIColor {
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
    }
    
    class var myBlue: UIColor {
        return UIColor(red: 51, green: 143, blue: 252)
    }
    
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

extension NSMutableAttributedString {
    
    func addAttributes(_ attributes: TextAttributes, string: String) {
        let range = (self.string as NSString).range(of: string)
        addAttributes(attributes, range: range)
    }
    
}

extension String {
    
    func bold(_ string: String) -> NSAttributedString {
        let attributes = TextAttributes().font(.preferredFont(forTextStyle: .headline))
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

extension UIFont {
    
    func bold() -> UIFont? {
        return fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) }
    }
    
}
