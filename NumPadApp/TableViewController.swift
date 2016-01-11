//
//  TableViewController.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 1/10/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
        
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableViewAutomaticDimension
    }

}

// MARK: - UITableViewDataSource
extension TableViewController {
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
        
        var text: String?
        switch indexPath.row {
        case 0: text = "Go to Settings → General → Keyboard → Keyboards → Add New Keyboard"
        default: break
        }
        cell.textLabel?.text = text
        
        cell.textLabel?.numberOfLines = 0
        
        return cell
    }
    
}
