//
//  TypingBehaviorViewController.swift
//  NumPad
//

import UIKit

/// Operational toggles formerly hosted under the Store’s Settings section.
final class TypingBehaviorViewController: TableViewController {

    private enum Section: Int, CaseIterable {
        case behavior
        case sync
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Typing & Behavior", comment: "Typing behavior screen title")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .behavior: return BehaviorSetting.allCases.count
        case .sync: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .behavior:
            return NSLocalizedString("Behavior", comment: "Typing behavior section header")
        case .sync:
            return NSLocalizedString("Sync", comment: "Typing behavior sync section header")
        case .none:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .behavior:
            let setting = BehaviorSetting.allCases[indexPath.row]
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell
                ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            cell.imageView?.image = UIImage(named: setting.imageName)
            cell.textLabel?.text = setting.title
            cell.switchView.isOn = setting.isOn
            cell.valueChanged = { [weak tableView] switchView in
                setting.set(switchView.isOn)
                tableView?.reloadRows(at: [indexPath], with: .none)
            }
            return cell
        case .sync:
            if Monetization.isProEntitled {
                let reuseIdentifier = String(describing: SwitchCell.self)
                let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell
                    ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
                cell.selectionStyle = .none
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("iCloud Sync", comment: "Toggle for syncing packs, snippets and layouts across devices")
                cell.switchView.isOn = UserPrefs.iCloudSyncEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.iCloudSyncEnabled = switchView.isOn
                    if switchView.isOn { CloudSync.start() }
                    SettingsSync.post()
                }
                return cell
            }
            let reuseIdentifier = "iCloudLockedCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
                ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "switch")
            cell.textLabel?.text = NSLocalizedString("iCloud Sync", comment: "Toggle for syncing packs, snippets and layouts across devices")
            let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
            lock.tintColor = .tertiaryLabel
            cell.accessoryView = lock
            cell.accessoryType = .none
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .sync, !Monetization.isProEntitled else { return }
        show(StoreViewController(), sender: self)
    }
}
