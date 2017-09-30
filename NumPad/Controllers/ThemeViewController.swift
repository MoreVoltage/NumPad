//
//  ThemeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import Crashlytics

class ThemeViewController: TableViewController {
    
    fileprivate let items = KeyboardTheme.all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Themes"
    }
    
}

// MARK: - UITableViewDataSource
extension ThemeViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: ThemeCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? ThemeCell ?? ThemeCell(style: .default, reuseIdentifier: reuseIdentifier)
        let item: KeyboardTheme = items[indexPath.row]
        cell.tintColor = .lightBlue
        cell.imageView?.image = UIImage()
        cell.radioButton.color = item.color
        cell.textLabel?.text = item.name
        cell.accessoryType = item.isSelected ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension ThemeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        KeyboardTheme.selected = items[indexPath.row]
        tableView.reloadData()
        Answers.logCustomEvent(withName: "actions", customAttributes: ["keyboardTheme": KeyboardTheme.selected.rawValue])
    }
    
}
