//
//  ThemeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation

class ThemeViewController: TableViewController {
    
    fileprivate let items = Keyboard.Theme.all
    
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
        let item = items[indexPath.row]
        cell.tintColor = .lightBlue
        cell.radioButton.color = item.color
        cell.radioButton.isSelected = item.isSelected
        cell.textLabel?.text = item.name
        cell.selectionStyle = .none
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension ThemeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Keyboard.Theme.selected = items[indexPath.row]
        tableView.reloadData()
    }
    
}
