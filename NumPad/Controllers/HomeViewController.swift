//
//  TableViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/22/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import iRate

class HomeViewController: TableViewController {

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
    }
    
}

// MARK: - UITableViewDataSource
extension TableViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        switch indexPath.row {
        case 0:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = "Enable Keyboard"
        case 1:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = "Themes"
        case 2:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = "Math Pack"
            cell.selectionStyle = .none
            cell.switchView.isOn = KeyboardType.math.isSelected
            cell.valueChanged = { switchView in
                KeyboardType.selected = switchView.isOn ? .math : .default
            }
            return cell
        case 3:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "moon")
            cell.textLabel?.text = "Night Mode"
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.isNightMode
            cell.valueChanged = { switchView in
                Keyboard.isNightMode = switchView.isOn
            }
            return cell
        case 4:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = "Feedback"
        case 5:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = "Rate Me"
        default:
            break
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension TableViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 0:
            show(InstructionsViewController.instantiate(), sender: self)
        case 1:
            show(ThemeViewController.instantiate(), sender: self)
        case 4:
            HelpshiftSupport.showFAQs(self.parent!, with: nil)
        case 5:
            iRate.sharedInstance().promptForRating()
        default:
            break
        }
    }
    
}
