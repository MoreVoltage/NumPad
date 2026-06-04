//
//  StoreViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class StoreViewController: TableViewController {
    private enum Section: Int, CaseIterable { case flags, controls, info }

    /// Sections visible in this build. The paywall/entitlement test toggles and
    /// the gating info row are development-only and must never ship to users.
    #if DEBUG
    private static let visibleSections: [Section] = [.flags, .controls, .info]
    #else
    private static let visibleSections: [Section] = [.controls]
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false
        #if DEBUG
        navigationItem.title = NSLocalizedString("Store (Preview)", comment: "Store preview screen navigation title")
        #else
        navigationItem.title = NSLocalizedString("Settings", comment: "")
        #endif
    }
}

extension StoreViewController {
    override func numberOfSections(in tableView: UITableView) -> Int { Self.visibleSections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < Self.visibleSections.count else { return 0 }
        switch Self.visibleSections[section] {
        case .flags: return 2
        case .controls: return 3
        case .info: return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < Self.visibleSections.count else {
            return UITableViewCell()
        }
        let section = Self.visibleSections[indexPath.section]
        switch section {
        case .flags:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("Enable Paywall", comment: "Store toggle to enable the paywall")
                cell.switchView.isOn = Monetization.paywallEnabled
                cell.valueChanged = { switchView in
                    Monetization.paywallEnabled = switchView.isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "paywall_enabled", attributes: [Analytics.ParameterValue: Monetization.paywallEnabled])
                }
            } else {
                cell.imageView?.image = UIImage(named: "star")
                cell.textLabel?.text = NSLocalizedString("Simulate Pro Entitlement", comment: "Store toggle to simulate a Pro entitlement")
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
                cell.textLabel?.text = NSLocalizedString("Haptics", comment: "Store toggle for haptic feedback")
                cell.switchView.isOn = UserPrefs.hapticsEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.hapticsEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else if indexPath.row == 1 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("Key Click Sound", comment: "Store toggle for key click sound")
                cell.switchView.isOn = UserPrefs.soundEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.soundEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else {
                cell.imageView?.image = UIImage(named: "keyboard")
                cell.textLabel?.text = NSLocalizedString("Repurpose Next Key", comment: "Store toggle to repurpose the next keyboard key")
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
            cell.textLabel?.text = NSLocalizedString("Nothing is gated while paywall is off", comment: "Store info row title explaining gating behavior")
            cell.detailTextLabel?.text = NSLocalizedString("When enabled, features can be marked Pro.", comment: "Store info row detail explaining Pro gating")
            cell.accessoryType = .none
            return cell
        }
    }
}


