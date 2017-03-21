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
        return 4
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: UITableViewCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Enable Keyboard"
        case 1:
            cell.textLabel?.text = "Themes"
        case 2:
            cell.textLabel?.text = "Feedback"
        case 3:
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
        case 2:
            HelpshiftSupport.showFAQs(self.parent!, with: nil)
        case 3:
            iRate.sharedInstance().promptForRating()
        default:
            break
        }
    }
    
}
