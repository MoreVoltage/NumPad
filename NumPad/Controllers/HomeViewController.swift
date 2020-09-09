//
//  TableViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/22/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftRater

class HomeViewController: TableViewController {
    
    enum Row: Int, CaseIterable {
        case instructions, keyboardTheme, isReversedMode, hasRoundedCorners, hasGrid, keyboardType, rate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = true
        
        self.tableView.tableHeaderView = {
            let view = UIView()
            view.frame.size.height = 300
            let imageView = UIImageView(image: UIImage(named: "header"))
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
            imageView.edgesToSuperview(insets: UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0))
            return view
        }()
        
        SwiftRater.check()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
    }
    
}

// MARK: - UITableViewDataSource
extension HomeViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        switch Row(rawValue: indexPath.row)! {
        case .instructions:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = .enableKeyboard
        case .keyboardTheme:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = .theme
            cell.detailTextLabel?.text = KeyboardTheme.selectedOrAutomatic.name
        case .isReversedMode:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "reversed")
            cell.textLabel?.text = .reversed
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.isReversedMode
            cell.valueChanged = { switchView in
                Keyboard.isReversedMode = switchView.isOn
                Analytics.logEvent(name: "reversed_mode", attributes: [Analytics.ParameterValue: Keyboard.isReversedMode])
            }
            return cell
        case .hasRoundedCorners:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "rounded")
            cell.textLabel?.text = .rounded
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.hasRoundedCorners
            cell.valueChanged = { switchView in
                Keyboard.hasRoundedCorners = switchView.isOn
                Analytics.logEvent(name: "rounded_corners", attributes: [Analytics.ParameterValue: Keyboard.hasRoundedCorners])
            }
            return cell
        case .hasGrid:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "grid")
            cell.textLabel?.text = .grid
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.hasGrid
            cell.valueChanged = { switchView in
                Keyboard.hasGrid = switchView.isOn
                Analytics.logEvent(name: "grid", attributes: [Analytics.ParameterValue: Keyboard.hasGrid])
            }
            return cell
        case .keyboardType:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = .mathPack
            cell.selectionStyle = .none
            cell.switchView.isOn = KeyboardType.packs.contains(KeyboardType.selected)
            cell.valueChanged = { switchView in
                KeyboardType.selected = switchView.isOn ? .math : .default
                Analytics.logEvent(name: "keyboard_type", attributes: [Analytics.ParameterValue: KeyboardType.selected.rawValue])
            }
            return cell
        case .rate:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = .rateMe
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension HomeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Row(rawValue: indexPath.row)! {
        case .instructions:
            show(InstructionsViewController.instantiate(), sender: self)
        case .keyboardTheme:
            show(ThemeViewController.instantiate(), sender: self)
        case .rate:
            SwiftRater.rateApp()
            Analytics.logEvent(name: "rate")
        default:
            break
        }
    }
    
}
