//
//  ThemeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class ThemeViewController: TableViewController {
    
    private let items = KeyboardTheme.allCases
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Theme"
    }
    
}

// MARK: - UITableViewDataSource
extension ThemeViewController {
    
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
        switch indexPath.section {
        case 0:
            let reuseIdentifier = String(describing: ThemeCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? ThemeCell ?? ThemeCell(style: .default, reuseIdentifier: reuseIdentifier)
            let item: KeyboardTheme = items[indexPath.row]
            cell.contentView.alpha = KeyboardTheme.automaticDarkMode ? 0.5 : 1
            cell.tintColor = UIColor.primary.withAlphaComponent(cell.contentView.alpha)
            cell.imageView?.image = UIImage()
            cell.radioButton.color = item.color
            cell.textLabel?.text = item.name
            cell.accessoryType = item.isSelected ? .checkmark : .none
            cell.selectionStyle = .none
            return cell
        default:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "darkmode")
            cell.textLabel?.text = "Automatic Dark Mode"
            cell.selectionStyle = .none
            cell.switchView.isOn = KeyboardTheme.automaticDarkMode
            cell.valueChanged = { [weak self] switchView in
                KeyboardTheme.automaticDarkMode = switchView.isOn
                self?.tableView.reloadSections([0], with: .none)
                Analytics.logEvent(name: "automatic_dark_mode", attributes: [Analytics.ParameterValue: KeyboardTheme.automaticDarkMode])
            }
            return cell
        }
    }
    
}

// MARK: - UITableViewDelegate
extension ThemeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0 where !KeyboardTheme.automaticDarkMode:
            KeyboardTheme.selected = items[indexPath.row]
            tableView.reloadData()
            Analytics.logEvent(name: "keyboard_theme", attributes: [Analytics.ParameterValue: KeyboardTheme.selected.rawValue])
        default:
            break
        }
    }
    
}
