//
//  ViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import RevealingSplashView
import KDInteractiveNavigationController

class ViewController: UIViewController {
    
    lazy var splashView: RevealingSplashView = { [unowned self] in
        let image = UIImage(named: "hashtag")!
        let view = RevealingSplashView(iconImage: image, iconInitialSize: image.size, backgroundColor: .myBlue)
        self.view.addSubview(view)
        return view
    }()
    
    lazy var tableView: TableViewController = { [unowned self] in
        let viewController = TableViewController.instantiate()
        viewController.willMove(toParentViewController: self)
        self.addChildViewController(viewController)
        self.view.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
        viewController.view.constrainToEdges()
        return viewController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = true
        
        _ = tableView
        
        splashView.startAnimation()
    }
    
    deinit {
        print("\(self) deinit")
    }
    
}
