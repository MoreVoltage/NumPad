//
//  InputViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/13/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class InputViewController: UIInputViewController {
    
    fileprivate var heightConstraint: NSLayoutConstraint?
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        _ = heightConstraint.map { NSLayoutConstraint.deactivate([$0]) }
        heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.view.frame.height)
        heightConstraint?.priority = 999
        _ = heightConstraint.map { NSLayoutConstraint.activate([$0]) }
    }
    
//    override func updateViewConstraints() {
//        super.updateViewConstraints()
//        
//        _ = heightConstraint.map { NSLayoutConstraint.deactivate([$0]) }
//        heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.view.frame.height)
//        heightConstraint?.priority = 999
//        _ = heightConstraint.map { NSLayoutConstraint.activate([$0]) }
//    }
    
    deinit {
        print("\(self) deinit")
    }
    
}
