//
//  TableViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    private var start = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = UIView()
        self.tableView.tableFooterView = UIView()
        self.tableView.showsVerticalScrollIndicator = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        start = Date()
        Analytics.logContentView(name: String(describing: type(of: self)), contentType: "screen", contentId: nil, attributes: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        Analytics.logContentView(name: String(describing: type(of: self)), contentType: "screen", contentId: nil, attributes: ["duration": Date().timeIntervalSince(start)])
    }
    
    deinit {
        print("\(self) deinit")
    }
    
}

extension TableViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset.left = 54
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets()
    }
    
}
