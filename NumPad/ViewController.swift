//
//  ViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import RevealingSplashView

class ViewController: UITableViewController {
    
    lazy var splashView: RevealingSplashView = { [unowned self] in
        let image = UIImage(named: "hashtag")!
        let view = RevealingSplashView(iconImage: image, iconInitialSize: image.size, backgroundColor: .myBlue)
        view.animationType = .squeezeAndZoomOut
        self.view.addSubview(view)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = {
            let view = UIView()
            view.frame.size.height = 300
            let imageView = UIImageView(image: UIImage(named: "header"))
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
            imageView.constrain {[
                $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: 10),
                $0.leadingAnchor.constraint(equalTo: $0.superview!.leadingAnchor, constant: 0),
                $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: -20),
                $0.trailingAnchor.constraint(equalTo: $0.superview!.trailingAnchor, constant: 0)
            ]}
            return view
        }()
        self.tableView.tableFooterView = UIView()
        self.tableView.showsVerticalScrollIndicator = false
        
        splashView.startAnimation()
    }
    
}

// MARK: - UITableViewDataSource
extension ViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let reuseIdentifier = String(describing: UITableViewCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.textLabel?.text = "Instructions"
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            let reuseIdentifier = String(describing: SwitchTableViewCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchTableViewCell ?? SwitchTableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            cell.textLabel?.text = "Night mode"
            cell.switchView.isOn = Defaults.bool(forKey: "nightMode")
            cell.valueChanged = { switchView in
                Defaults.set(switchView.isOn, forKey: "nightMode")
            }
            return cell
        case 2:
            let reuseIdentifier = String(describing: UITableViewCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.textLabel?.text = "Feedback"
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return UITableViewCell()
        }
    }
    
}

// MARK: - UITableViewDelegate
extension ViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 0:
            show(InstructionsViewController.instantiate(), sender: self)
        case 2:
            HelpshiftSupport.showFAQs(self, with: nil)
        default:
            break
        }
    }
    
}

// MARK: - SwitchTableViewCell
private class SwitchTableViewCell: UITableViewCell {
    
    lazy var switchView: UISwitch = { [unowned self] in
        let view = UISwitch()
        view.addTarget(self, action: #selector(_valueChanged), for: .valueChanged)
        self.accessoryView = view
        return view
    }()
    
    var valueChanged: ((UISwitch) -> Void)?
    
    @IBAction func _valueChanged(sender: UISwitch) {
        self.valueChanged?(sender)
    }
    
}
