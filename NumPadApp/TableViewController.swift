//
//  TableViewController.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 2/15/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        style()
    }
    
}

// MARK: - Style
extension TableViewController {
    
    func style() {
        self.title = "NumPad"
        
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        self.tableView.keyboardDismissMode = .Interactive
    }
    
}

// MARK: - UITableViewDataSource
extension TableViewController {
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 6
        case 1: return 1
        case 2: return 2
        default: return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "Go to device settings"
                return cell
            case 1:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "General"
                return cell
            case 2:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "Keyboard"
                return cell
            case 3:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "Keyboards"
                return cell
            case 4:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "Add New Keyboard"
                return cell
            case 5:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = NSBundle.mainBundle().infoDictionary?["CFBundleDisplayName"] as? String
                return cell
            default: break
            }
        case 1:
            switch indexPath.row {
            case 0:
                let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
                cell.textLabel?.text = "Send Feedback"
                return cell
            default: break
            }
        case 2:
            switch indexPath.row {
            case 0:
                let cell = UITableViewCell(style: .Value1, reuseIdentifier: nil)
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String
                return cell
            case 1:
                let cell = UITableViewCell(style: .Value1, reuseIdentifier: nil)
                cell.textLabel?.text = "Build"
                cell.detailTextLabel?.text = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as? String
                return cell
            default: break
            }
        default: break
        }
        
        return UITableViewCell()
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Enable NumPad"
        case 1: return "Support"
        case 2: return "Info"
        default: return nil
        }
    }
    
}

// MARK: - UITableViewDelegate
extension TableViewController {
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let settingsURL = NSURL(string: "prefs:root=General&path=Keyboard/KEYBOARDS") {
            UIApplication.sharedApplication().openURL(settingsURL)
        }
    }
    
}
