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
        case instructions, keyboardTheme, isReversedMode, keyboardType, feedback, rateMe
        
        static let all: [Row] = [instructions, keyboardTheme, isReversedMode, keyboardType, feedback, rateMe]
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
            imageView.constrainToEdges(UIEdgeInsets(top: 10, left: 0, bottom: -20, right: 0))
            return view
        }()
        
        SwiftRater.check()
    }
    
}

// MARK: - UITableViewDataSource
extension HomeViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.all.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        switch Row(rawValue: indexPath.row)! {
        case .instructions:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = "Enable Keyboard"
        case .keyboardTheme:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = "Themes"
        case .isReversedMode:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "reversed")
            cell.textLabel?.text = "Reversed"
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.isReversedMode
            cell.valueChanged = { switchView in
                Keyboard.isReversedMode = switchView.isOn
                Analytics.logCustomEvent(name: "actions", attributes: ["isReversedMode": Keyboard.isReversedMode.hashValue])
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
                Analytics.logCustomEvent(name: "actions", attributes: ["keyboardType": KeyboardType.selected.rawValue])
            }
            return cell
        case .feedback:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = "Feedback"
        case .rateMe:
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
        case .rateMe:
            SwiftRater.rateApp()
        default:
            break
        }
    }
    
}
