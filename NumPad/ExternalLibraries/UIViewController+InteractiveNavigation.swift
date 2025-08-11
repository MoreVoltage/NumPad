//
//  UIViewController+InteractiveNavigation.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

private var interactiveNavigationBarHiddenAssociationKey: UInt8 = 0

private let swizzling: (AnyClass, Selector, Selector) -> () = { forClass, originalSelector, swizzledSelector in
    let originalMethod = class_getInstanceMethod(forClass, originalSelector)!
    let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector)!
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

@IBDesignable
extension UIViewController {
    
    @IBInspectable public var interactiveNavigationBarHidden: Bool {
        get { return objc_getAssociatedObject(self, &interactiveNavigationBarHiddenAssociationKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &interactiveNavigationBarHiddenAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    static let classInit: Void = {
        let originalSelector = #selector(viewWillAppear)
        let swizzledSelector = #selector(swizzled_viewWillAppear)
        swizzling(UIViewController.self, originalSelector, swizzledSelector)
    }()
    
    @objc func swizzled_viewWillAppear(_ animated: Bool) {
        swizzled_viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(interactiveNavigationBarHidden, animated: animated)
    }
    
}
