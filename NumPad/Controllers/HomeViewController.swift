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
    
    enum Row: Int {
        case instructions, keyboardTheme, isReversedMode, hasRoundedCorners, keyboardType, feedback, rate
        
        static let all: [Row] = [instructions, keyboardTheme, isReversedMode, hasRoundedCorners, keyboardType, feedback, rate]
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
            imageView.edges(UIEdgeInsets(top: 10, left: 0, bottom: -20, right: 0))
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
        return Row.all.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        switch Row(rawValue: indexPath.row)! {
        case .instructions:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = "Enable Keyboard"
        case .keyboardTheme:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = "Theme"
            cell.detailTextLabel?.text = KeyboardTheme.selected.name
        case .isReversedMode:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "reversed")
            cell.textLabel?.text = "Reversed"
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.isReversedMode
            cell.valueChanged = { switchView in
                Keyboard.isReversedMode = switchView.isOn
                Analytics.logCustomEvent(name: "reversed_mode", attributes: ["value": Keyboard.isReversedMode])
            }
            return cell
        case .hasRoundedCorners:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "square")
            cell.textLabel?.text = "Rounded"
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.hasRoundedCorners
            cell.valueChanged = { switchView in
                Keyboard.hasRoundedCorners = switchView.isOn
                Analytics.logCustomEvent(name: "rounded_corners", attributes: ["value": Keyboard.hasRoundedCorners])
            }
            return cell
        case .keyboardType:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = "Math Pack"
            cell.selectionStyle = .none
            cell.switchView.isOn = KeyboardType.math.isSelected
            cell.valueChanged = { switchView in
                KeyboardType.selected = switchView.isOn ? .math : .default
                Analytics.logCustomEvent(name: "keyboard_type", attributes: ["value": KeyboardType.selected.rawValue])
            }
            return cell
        case .feedback:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = "Feedback"
        case .rate:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = "Rate Me"
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
        case .feedback:
            let viewController = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController
            HelpshiftSupport.showFAQs(viewController, with: nil)
            Analytics.logCustomEvent(name: "feedback")
        case .rate:
            SwiftRater.rateApp()
            Analytics.logCustomEvent(name: "rate")
        default:
            break
        }
    }
    
}
