//
//  CustomKeysViewController.swift
//  NumPad
//

import UIKit

/// Settings screen for the customizable keys:
/// - Section 0: the three remappable right-side slots (defaults: comma, period, space)
/// - Section 1: the user-built Custom pack (add / delete / reorder keys)
class CustomKeysViewController: TableViewController {

    private enum Section: Int, CaseIterable {
        case slots, customPack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Custom Keys", comment: "Custom keys screen navigation title")
        navigationItem.rightBarButtonItem = editButtonItem
    }

    private func slotName(for index: Int) -> String {
        switch index {
        case 0: return NSLocalizedString("Top Right Key", comment: "Name of the top remappable key slot")
        case 1: return NSLocalizedString("Middle Right Key", comment: "Name of the middle remappable key slot")
        default: return NSLocalizedString("Bottom Right Key", comment: "Name of the bottom remappable key slot")
        }
    }

    private func settingsChanged() {
        SettingsSync.post()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension CustomKeysViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .slots:
            return CustomKeys.slotCount
        case .customPack:
            // +1 for the trailing "Add Key…" row (hidden once the pack is full)
            let count = CustomPackManager.shared.keys.count
            return count < CustomPackManager.maxKeys ? count + 1 : count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .slots:
            return NSLocalizedString("Right-Side Keys", comment: "Header for the remappable key slots section")
        case .customPack:
            return NSLocalizedString("Custom Pack", comment: "Header for the custom pack keys section")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .slots:
            return NSLocalizedString("These keys appear to the right of the number grid. Assign Tab to move between cells in spreadsheet apps.", comment: "Footer explaining the remappable key slots")
        case .customPack:
            var footer = NSLocalizedString("Build your own key row: up to 10 keys, 4 characters each. Select the Custom pack in Keyboard Packs to use it.", comment: "Footer explaining the custom pack keys")
            if Monetization.isLocked(pack: .custom) {
                footer += "\n" + NSLocalizedString("The Custom pack requires NumPad Pro.", comment: "Footer note that the custom pack is a Pro feature")
            }
            return footer
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.accessoryView = nil
        cell.detailTextLabel?.text = nil
        switch Section(rawValue: indexPath.section) {
        case .slots:
            cell.textLabel?.text = slotName(for: indexPath.row)
            cell.detailTextLabel?.text = CustomKeys.displayName(for: CustomKeys.slots[indexPath.row])
            cell.accessoryType = .disclosureIndicator
        case .customPack:
            let keys = CustomPackManager.shared.keys
            if indexPath.row < keys.count {
                cell.textLabel?.text = keys[indexPath.row]
            } else {
                cell.textLabel?.text = NSLocalizedString("Add Key…", comment: "Row title to add a new custom pack key")
            }
        default:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard Section(rawValue: indexPath.section) == .customPack else { return false }
        return indexPath.row < CustomPackManager.shared.keys.count
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, Section(rawValue: indexPath.section) == .customPack else { return }
        CustomPackManager.shared.remove(at: indexPath.row)
        SettingsSync.post()
        Analytics.logEvent(name: "custom_pack_remove_key")
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return self.tableView(tableView, canEditRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Keep reordering inside the key rows of the Custom Pack section
        let keyCount = CustomPackManager.shared.keys.count
        guard Section(rawValue: proposedDestinationIndexPath.section) == .customPack,
              proposedDestinationIndexPath.row < keyCount else {
            return IndexPath(row: max(keyCount - 1, 0), section: Section.customPack.rawValue)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        CustomPackManager.shared.move(from: sourceIndexPath.row, to: destinationIndexPath.row)
        SettingsSync.post()
    }
}

// MARK: - UITableViewDelegate
extension CustomKeysViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .slots:
            presentSlotPicker(forSlot: indexPath.row)
        case .customPack:
            guard indexPath.row >= CustomPackManager.shared.keys.count else { return }
            presentAddKeyAlert()
        default:
            break
        }
    }

    private func presentSlotPicker(forSlot slot: Int) {
        let sheet = UIAlertController(title: slotName(for: slot), message: nil, preferredStyle: .actionSheet)
        for token in CustomKeys.palette {
            let title = CustomKeys.displayName(for: token)
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.assign(token: token, toSlot: slot)
            })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Custom…", comment: "Action to type a custom character for a key slot"), style: .default) { [weak self] _ in
            self?.presentCustomTokenAlert(forSlot: slot)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        // Required on iPad — action sheets without a popover anchor crash.
        if let popover = sheet.popoverPresentationController {
            let cell = tableView.cellForRow(at: IndexPath(row: slot, section: Section.slots.rawValue))
            popover.sourceView = cell ?? tableView
            popover.sourceRect = cell?.bounds ?? .zero
        }
        present(sheet, animated: true)
    }

    private func presentCustomTokenAlert(forSlot slot: Int) {
        let alert = UIAlertController(
            title: NSLocalizedString("Custom Key", comment: "Alert title for entering a custom key character"),
            message: NSLocalizedString("Enter the text this key should type (up to 4 characters).", comment: "Alert message for entering a custom key character"),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default) { [weak self, weak alert] _ in
            let text = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            self?.assign(token: String(text.prefix(CustomPackManager.maxKeyLength)), toSlot: slot)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    private func assign(token: String, toSlot slot: Int) {
        var slots = CustomKeys.slots
        guard slots.indices.contains(slot) else { return }
        slots[slot] = token
        CustomKeys.slots = slots
        SettingsSync.post()
        Analytics.logEvent(name: "custom_key_slot", attributes: ["slot": slot, Analytics.ParameterValue: token])
        tableView.reloadData()
    }

    private func presentAddKeyAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("Add Key", comment: "Alert title for adding a custom pack key"),
            message: NSLocalizedString("Enter the text this key should type (up to 4 characters).", comment: "Alert message for adding a custom pack key"),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            CustomPackManager.shared.add(text)
            SettingsSync.post()
            Analytics.logEvent(name: "custom_pack_add_key")
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }
}
