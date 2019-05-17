//
//  ViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import RevealingSplashView

class ViewController: UIViewController {
    
    lazy var splashView: RevealingSplashView = { [unowned self] in
        let image = UIImage(named: "hashtag")!
        let view = RevealingSplashView(iconImage: image, iconInitialSize: image.size, backgroundColor: .lightBlue)
        self.view.addSubview(view)
        return view
    }()
    
    lazy var tableView: HomeViewController = { [unowned self] in
        let viewController = HomeViewController.instantiate()
        viewController.willMove(toParent: self)
        self.addChild(viewController)
        self.view.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        viewController.view.edges()
        return viewController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = true
        
        _ = tableView
        
        splashView.startAnimation() { [unowned self] in
            if #available(iOS 10.0, *), !Keyboard.isKeyboardEnabled {
                self.show(InstructionsViewController.instantiate(), sender: self)
            }
        }
    }
    
    deinit {
        print("\(self) deinit")
    }
    
}
