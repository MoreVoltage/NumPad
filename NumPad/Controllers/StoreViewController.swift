//
//  StoreViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class StoreViewController: TableViewController {
    private enum Section: Int, CaseIterable { case flags, controls, info }

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false
        navigationItem.title = "Store (Preview)"
    }
}

extension StoreViewController {
    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .flags: return 2
        case .controls: return 3
        case .info: return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .flags:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = "Enable Paywall"
                cell.switchView.isOn = Monetization.paywallEnabled
                cell.valueChanged = { switchView in
                    Monetization.paywallEnabled = switchView.isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "paywall_enabled", attributes: [Analytics.ParameterValue: Monetization.paywallEnabled])
                }
            } else {
                cell.imageView?.image = UIImage(named: "star")
                cell.textLabel?.text = "Simulate Pro Entitlement"
                cell.switchView.isOn = Monetization.isProEntitled
                cell.valueChanged = { switchView in
                    Monetization.isProEntitled = switchView.isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "pro_entitled", attributes: [Analytics.ParameterValue: Monetization.isProEntitled])
                }
            }
            return cell
        case .controls:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.imageView?.image = UIImage(named: "tap")
                cell.textLabel?.text = "Haptics"
                cell.switchView.isOn = UserPrefs.hapticsEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.hapticsEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else if indexPath.row == 1 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = "Key Click Sound"
                cell.switchView.isOn = UserPrefs.soundEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.soundEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else {
                cell.imageView?.image = UIImage(named: "keyboard")
                cell.textLabel?.text = "Repurpose Next Key"
                cell.switchView.isOn = UserPrefs.repurposeNextKey
                cell.valueChanged = { switchView in
                    UserPrefs.repurposeNextKey = switchView.isOn
                    SettingsSync.post()
                }
            }
            return cell
        case .info:
            let reuseIdentifier = String(describing: Cell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = "Nothing is gated while paywall is off"
            cell.detailTextLabel?.text = "When enabled, features can be marked Pro."
            cell.accessoryType = .none
            return cell
        }
    }
}


