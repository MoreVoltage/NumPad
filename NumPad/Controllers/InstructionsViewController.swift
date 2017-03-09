//
//  InstructionsViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import TextAttributes

class InstructionsViewController: UITableViewController {
    
    fileprivate let items = [
        Item(title: "Open the Settings App".bold("Settings"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap General".bold("General"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Keyboard".bold("Keyboard"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Keyboards".bold("Keyboards"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Add New Keyboard...".bold("Add New Keyboard"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap \(Bundle.main.bundleName!)".bold("\(Bundle.main.bundleName!)"), subtitle: nil, imageName: "tap"),
        Item(title: "Tap \(Bundle.main.bundleName!) again".bold("\(Bundle.main.bundleName!)"), subtitle: nil, imageName: "tap"),
        Item(title: "Turn on Allow Full Access".bold("Allow Full Access"), subtitle: "(optional)", imageName: "switch")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Instructions"
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = UIView()
        self.tableView.tableFooterView = UIView()
        self.tableView.estimatedRowHeight = 44
    }
    
    deinit {
        print("\(self) deinit")
    }
    
}

// MARK: - UITableViewDataSource
extension InstructionsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
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
        cell.imageView?.tintColor = .myBlue
        cell.imageView?.contentMode = .center
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.textColor = .lightGray
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .caption1)
        switch indexPath.section {
        case 0:
            cell.selectionStyle = .default
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.attributedText = "Go to Settings".bold("Settings")
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        case 1:
            cell.selectionStyle = .none
            cell.imageView?.image = UIImage(named: items[indexPath.row].imageName)
            cell.textLabel?.attributedText = items[indexPath.row].title
            cell.detailTextLabel?.text = items[indexPath.row].subtitle
            cell.accessoryType = .none
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.attributedText = {
                let font = UIFont.preferredFont(forTextStyle: .caption1)
                let text = NSMutableAttributedString(string: "Enabling Full Access enables click sounds and themes. Nothing you type is tracked.")
                text.addAttributes(TextAttributes().font(font))
                text.addAttributes(TextAttributes().font(font.bold()!), string: "Full Access")
                text.addAttributes(TextAttributes().font(font.bold()!), string: "Nothing you type is tracked")
                return text
            }()
            cell.textLabel?.numberOfLines = 0
            return cell
        default:
            break
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 2:
            break
        default:
            cell.separatorInset.left = 54
            cell.preservesSuperviewLayoutMargins = false
            cell.layoutMargins = UIEdgeInsets()
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
        default:
            break
        }
    }
    
}

// MARK: - Cell
private class Cell: UITableViewCell {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        
        textLabel?.frame.origin.x = 54
        detailTextLabel?.frame.origin.x = 54
    }
    
}

// MARK: - Item
private struct Item {
    let title: NSAttributedString
    let subtitle: String?
    let imageName: String
}
