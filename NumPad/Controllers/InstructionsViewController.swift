//
//  InstructionsViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import TextAttributes

private let bundleName = Bundle.main.bundleName!

class InstructionsViewController: TableViewController {
    
    fileprivate let items = [
        Item(title: "Open Settings and go to General".bold("Settings", "General", color: .lightBlue, font: .bold), subtitle: nil, imageName: "tap"),
        Item(title: "Choose Keyboard and then Keyboards".bold("Keyboard", "Keyboards", color: .lightBlue, font: .bold), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Add New Keyboard, pick \(bundleName)".bold("Add New Keyboard", bundleName, color: .lightBlue, font: .bold), subtitle: nil, imageName: "tap"),
        Item(title: "Tap on \(Bundle.main.bundleName!)".bold(bundleName, color: .lightBlue, font: .bold), subtitle: nil, imageName: "tap"),
        Item(title: "Turn on Allow Full Access".bold("Allow Full Access", color: .lightBlue, font: .bold), subtitle: "(optional)", imageName: "switch")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Enable Keyboard"
        
        self.tableView.tableHeaderView = {
            let view = UIView()
            view.frame.size = CGSize(width: self.tableView.frame.width, height: 100)
            let label = UILabel()
            label.textColor = .text
            label.attributedText = {
                let text = NSMutableAttributedString(string: "Almost done! Turn on the \(bundleName) Keyboard by\ngoing to Settings and following the steps below.")
                text.addAttributes(TextAttributes().font(.systemFont(ofSize: 15, weight: .regular)))
                for string in ["\(bundleName) Keyboard", "Settings"] {
                    text.addAttributes(TextAttributes().font(.systemFont(ofSize: 15, weight: .bold)).foregroundColor(.lightBlue), string: string)
                }
                return text
            }()
            label.numberOfLines = 0
            label.textAlignment = .center
            label.sizeToFit()
            label.center = view.center
            view.addSubview(label)
            return view
        }()
        self.tableView.tableFooterView = {
            let label = UILabel()
            label.textColor = .text
            label.attributedText = {
                let text = NSMutableAttributedString(string: "Enabling Full Access enables click sounds and themes.\nNothing you type is tracked.")
                text.addAttributes(TextAttributes().font(.regularSmall))
                for string in ["Full Access", "Nothing you type is tracked"] {
                    text.addAttributes(TextAttributes().font(.boldSmall).foregroundColor(.lightBlue), string: string)
                }
                return text
            }()
            label.numberOfLines = 0
            label.sizeToFit()
            label.frame.origin.x = (self.tableView.frame.width - label.frame.width) / 2
            label.frame.size.height += 10
            return label
        }()
    }
    
}

// MARK: - UITableViewDataSource
extension InstructionsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return items.count
        default:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        cell.imageView?.image = nil
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .none
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.attributedText = "Go to Settings".bold("Settings", color: .lightBlue, font: .bold)
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case 1:
            let item = items[indexPath.row]
            cell.imageView?.image = UIImage(named: item.imageName)
            cell.textLabel?.attributedText = item.title
            cell.detailTextLabel?.text = item.subtitle
        default:
            break
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView, let textLabel = view.textLabel else { return }
        textLabel.font = .regular
        textLabel.textColor = UIColor.white(0.4)
        textLabel.text = textLabel.text?.capitalized
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Instructions"
        default:
            return nil
        }
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            if #available(iOS 10.0, *) {
                _ = URL.keyboard.map { UIApplication.shared.open($0) }
            } else {
                _ = URL.keyboard.map { UIApplication.shared.openURL($0) }
            }
            Analytics.logCustomEvent(name: "actions", attributes: ["url": "settings"])
        default:
            break
        }
    }
    
}

// MARK: - Item
private struct Item {
    let title: NSAttributedString
    let subtitle: String?
    let imageName: String
}
