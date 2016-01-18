//
//  ViewController.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 1/17/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            
            tableView.tableHeaderView = UIView()
            tableView.tableFooterView = UIView()
            
            tableView.estimatedRowHeight = 44
            tableView.rowHeight = UITableViewAutomaticDimension
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
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
