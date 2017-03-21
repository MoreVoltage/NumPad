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
private let font = UIFont.preferredFont(forTextStyle: .subheadline)
private let subfont = UIFont.preferredFont(forTextStyle: .caption1)

class InstructionsViewController: TableViewController {
    
    fileprivate let items = [
        Item(title: "Open Settings and go to General".bold("Settings", "General", font: font), subtitle: nil, imageName: "tap"),
        Item(title: "Choose Keyboard and then Keyboards".bold("Keyboard", "Keyboards", font: font), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Add New Keyboard, pick \(bundleName)".bold("Add New Keyboard", bundleName, font: font), subtitle: nil, imageName: "tap"),
        Item(title: "Tap on \(Bundle.main.bundleName!)".bold(bundleName, font: font), subtitle: nil, imageName: "tap"),
        Item(title: "Turn on Allow Full Access".bold("Allow Full Access", font: font), subtitle: "(optional)", imageName: "switch")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Instructions"
        
        self.tableView.estimatedRowHeight = 44
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
        cell.imageView?.image = nil
        cell.imageView?.tintColor = .lightBlue
        cell.imageView?.contentMode = .center
        cell.textLabel?.font = font
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.text = nil
        cell.detailTextLabel?.textColor = .lightGray
        cell.detailTextLabel?.font = subfont
        cell.selectionStyle = .none
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.attributedText = "Go to Settings".bold("Settings", font: font)
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case 1:
            let item = items[indexPath.row]
            cell.imageView?.image = UIImage(named: item.imageName)
            cell.textLabel?.attributedText = item.title
            cell.detailTextLabel?.text = item.subtitle
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.attributedText = {
                let font = subfont
                let text = NSMutableAttributedString(string: "Enabling Full Access enables click sounds and themes. Nothing you type is tracked.")
                text.addAttributes(TextAttributes().font(font))
                text.addAttributes(TextAttributes().font(font.bold()!).foregroundColor(.lightBlue), string: "Full Access")
                text.addAttributes(TextAttributes().font(font.bold()!).foregroundColor(.lightBlue), string: "Nothing you type is tracked")
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
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case 1:
            let label = UILabel()
            label.text = "or"
            label.textColor = .lightBlue
            label.textAlignment = .center
            label.font = UIFont.preferredFont(forTextStyle: .caption1).bold()
            return label
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 1:
            return 40
        default:
            return UITableViewAutomaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 1
        default:
            return UITableViewAutomaticDimension
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
