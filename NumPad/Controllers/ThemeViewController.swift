//
//  ThemeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation

class ThemeViewController: TableViewController {
    
    fileprivate let items = [
        Item(title: "Red", color: Color.red),
        Item(title: "Orange", color: Color.orange),
        Item(title: "Yellow", color: Color.yellow),
        Item(title: "Green", color: Color.green),
        Item(title: "Teal Blue", color: Color.tealBlue),
        Item(title: "Blue", color: Color.blue),
        Item(title: "Purple", color: Color.purple),
        Item(title: "Pink", color: Color.pink)
    ]
    
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
        let reuseIdentifier = String(describing: UITableViewCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        let item = items[indexPath.row]
        cell.imageView?.image = UIImage(color: item.color)
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.accessoryType = true ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }
    
}

// MARK: - Item
private struct Item {
    let title: String
    let color: UIColor
}
