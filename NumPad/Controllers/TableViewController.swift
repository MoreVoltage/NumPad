//
//  TableViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = UIView()
        self.tableView.tableFooterView = UIView()
        self.tableView.showsVerticalScrollIndicator = false
    }
    
    deinit {
        print("\(self) deinit")
    }
    
}
