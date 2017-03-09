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

extension UIColor {
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
    }
    
}
