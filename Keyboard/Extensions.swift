//
//  Extensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

extension UIView {
    
    @discardableResult
    func constrain(constraints: (UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        let constraints = constraints(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
}

extension UIInputView: UIInputViewAudioFeedback {
    
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
    
}

extension UIDevice {
    
    func hasOpenAccess() -> Bool {
        return UIPasteboard.general.isKind(of: UIPasteboard.self)
    }
    
}

extension UIColor {
    
    class var foreground: UIColor {
        return UIColor(white: 0.3, alpha: 1)
    }
    
    class var background: UIColor {
        return UIColor(white: 0.9, alpha: 1)
    }
    
    class var background2: UIColor {
        return UIColor(white: 0.85, alpha: 1)
    }
    
    class var background3: UIColor {
        return UIColor(white: 0.95, alpha: 1)
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

extension UIFont {
    
    private enum SFUIDisplay: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont? {
            return UIFont(name: "SFUIDisplay-\(rawValue)", size: fontSize)
        }
    }
    
    private enum SFUIText: String {
        case Regular
        
        func size(_ fontSize: CGFloat) -> UIFont? {
            return UIFont(name: "SFUIText-\(rawValue)", size: fontSize)
        }
    }
    
    class var font1: UIFont {
        return UIFont.SFUIText.Regular.size(14)!
    }

    class var font2: UIFont {
        return UIFont.SFUIDisplay.Regular.size(27)!
    }
    
}
