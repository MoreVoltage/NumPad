//
//  SharedExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/9/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

let Defaults = UserDefaults(suiteName: "group.morevoltage.numpad.container")!

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

extension UIFont {
    
    enum SFUIDisplay: String {
        case Regular, Bold
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIDisplay-\(rawValue)", size: fontSize)!
        }
    }
    
    enum SFUIText: String {
        case Regular, Bold
        
        func size(_ fontSize: CGFloat) -> UIFont {
            return UIFont(name: "SFUIText-\(rawValue)", size: fontSize)!
        }
    }
    
}
