//
//  InstructionsViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import TextAttributes

class InstructionsViewController: TableViewController {
    
    private let items = [
        Item(title: String.instructionsItem1.bold(.settings, String.bundleName, color: .primary, font: .headlineBold), imageName: "tap"),
        Item(title: String.instructionsItem2.bold(.keyboards, color: .primary, font: .headlineBold), imageName: "tap"),
        Item(title: String.instructionsItem3.bold(String.bundleName, color: .primary, font: .headlineBold), imageName: "switch")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = false
        
        self.navigationItem.title = .instructionsTitle
        
        self.tableView.tableHeaderView = {
            let attributedText: NSAttributedString = {
                let text = NSMutableAttributedString(string: .instructionsHeader)
                text.addAttributes(TextAttributes().font(.preferredFont(for: .subheadline)))
                for string in [String.bundleKeyboard, String.settings] {
                    text.addAttributes(TextAttributes().font(.preferredFont(for: .subheadline, weight: .bold)).foregroundColor(.primary), string: string)
                }
                return text
            }()
            return HeaderFooterView(attributedText: attributedText, maxWidth: self.tableView.frame.width, insets: .uniform(20))
        }()
        self.tableView.tableFooterView = {
            let attributedText: NSAttributedString = {
                let text = NSMutableAttributedString(string: .instructionsFooter)
                text.addAttributes(TextAttributes().font(.preferredFont(for: .caption2)))
                for string in [String.fullAccess, String.nothingTracked] {
                    text.addAttributes(TextAttributes().font(.preferredFont(for: .caption2, weight: .bold)).foregroundColor(.primary), string: string)
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
        cell.selectionStyle = .none
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.attributedText = String.goToSettings.bold(.settings, color: .primary, font: .headlineBold)
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        default:
            let item = items[indexPath.row]
            cell.imageView?.image = UIImage(named: item.imageName)
            cell.textLabel?.attributedText = item.title
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView, let textLabel = view.textLabel else { return }
        textLabel.font = .body
        textLabel.textColor = .secondaryLabel
        textLabel.text = textLabel.text?.capitalized
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return .instructions
        default:
            return nil
        }
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            URL.keyboard.map { UIApplication.shared.open($0) }
            Analytics.logEvent(name: "settings")
        default:
            break
        }
    }
    
}

// MARK: - Item
private struct Item {
    let title: NSAttributedString
    let imageName: String
}

private extension UIFont {
    static var headlineBold: UIFont {
        return preferredFont(for: .headline, weight: .bold)
    }
}
