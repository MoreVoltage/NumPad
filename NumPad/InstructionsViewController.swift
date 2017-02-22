//
//  InstructionsViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class InstructionsViewController: UITableViewController {
    
    fileprivate let items = [Item(title: "Open the Settings App", imageName: "tap"), Item(title: "Tap General", imageName: "tap"), Item(title: "Tap Keyboard", imageName: "tap"), Item(title: "Tap Keyboards", imageName: "tap"), Item(title: "Tap Add New Keyboard...", imageName: "tap"), Item(title: "Tap \(Bundle.main.bundleName!)", imageName: "tap"), Item(title: "Tap \(Bundle.main.bundleName!) again", imageName: "tap"), Item(title: "Turn on Allow Full Access", imageName: "switch")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Instructions"
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = UIView()
        self.tableView.tableFooterView = UIView()
    }
    
}

// MARK: - UITableViewDataSource
extension InstructionsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return items.count
        default:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.imageView?.tintColor = .myBlue
        cell.imageView?.contentMode = .center
        switch indexPath.section {
        case 0:
            cell.selectionStyle = .none
            cell.imageView?.image = UIImage(named: items[indexPath.row].imageName)
            cell.textLabel?.text = items[indexPath.row].title
            cell.accessoryType = .none
        default:
            cell.selectionStyle = .default
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = "Go to Settings"
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset.left = 54
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 1:
            if #available(iOS 10.0, *) {
                _ = URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS").map { UIApplication.shared.open($0) }
            } else {
                _ = URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS").map { UIApplication.shared.openURL($0) }
            }
        default:
            break
        }
    }
    
}

// MARK: - Cell
private class Cell: UITableViewCell {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        
        textLabel?.frame.origin.x = 54
    }
    
}

// MARK: - Item
private struct Item {
    let title: String
    let imageName: String
}
