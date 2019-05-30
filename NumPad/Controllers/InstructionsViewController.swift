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
    
    private let items = [
        Item(title: "Open Settings and go to \(bundleName)".bold("Settings", bundleName, color: .lightBlue, font: .headlineBold), subtitle: nil, imageName: "tap"),
        Item(title: "Tap Keyboards".bold("Keyboards", color: .lightBlue, font: .headlineBold), subtitle: nil, imageName: "tap"),
        Item(title: "Turn on \(bundleName)".bold(bundleName, color: .lightBlue, font: .headlineBold), subtitle: nil, imageName: "switch")
//        Item(title: "Turn on Allow Full Access".bold("Allow Full Access", color: .lightBlue, font: .bold), subtitle: "(optional)", imageName: "switch")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Enable Keyboard"
        
        self.tableView.tableHeaderView = {
            let attributedText: NSAttributedString = {
                let text = NSMutableAttributedString(string: "Almost done! Turn on the \(bundleName) Keyboard by going to Settings and following the steps below.")
                text.addAttributes(TextAttributes().font(.preferredFont(for: .subheadline)))
                for string in ["\(bundleName) Keyboard", "Settings"] {
                    text.addAttributes(TextAttributes().font(.preferredFont(for: .subheadline, weight: .bold)).foregroundColor(.lightBlue), string: string)
                }
                return text
            }()
            return HeaderFooterView(attributedText: attributedText, maxWidth: self.tableView.frame.width, insets: .uniform(20))
        }()
        self.tableView.tableFooterView = {
            let attributedText: NSAttributedString = {
                let text = NSMutableAttributedString(string: "Enable Full Access for click sounds. Nothing you type is tracked.")
                text.addAttributes(TextAttributes().font(.preferredFont(for: .caption2)))
                for string in ["Full Access", "Nothing you type is tracked"] {
                    text.addAttributes(TextAttributes().font(.preferredFont(for: .caption2, weight: .bold)).foregroundColor(.lightBlue), string: string)
                }
                return text
            }()
            return HeaderFooterView(attributedText: attributedText, maxWidth: self.tableView.frame.width, insets: .horizontal(20))
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
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .none
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.attributedText = "Go to Settings".bold("Settings", color: .lightBlue, font: .headlineBold)
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
        textLabel.font = .body
        textLabel.textColor = .lightGray
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
            Analytics.logEvent(name: "settings")
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

private extension UIFont {
    static var headlineBold: UIFont {
        return preferredFont(for: .headline, weight: .bold)
    }
}
