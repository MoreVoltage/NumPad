//
//  PacksViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class PacksViewController: TableViewController {
    private enum PackOption: CaseIterable {
        case none, math, finance, symbols, programmer, tax, custom
        // NOTE: These names duplicate KeyboardType.name in Libraries/Keyboard.swift.
        // Consider deduplicating by deriving from keyboardType?.name in a future refactor.
        var name: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "Pack option name for no keyboard pack")
            case .math: return NSLocalizedString("Math", comment: "Pack option name for the math keyboard pack")
            case .finance: return NSLocalizedString("Finance", comment: "Pack option name for the finance keyboard pack")
            case .symbols: return NSLocalizedString("Symbols", comment: "Pack option name for the symbols keyboard pack")
            case .programmer: return NSLocalizedString("Programmer", comment: "Pack option name for the programmer keyboard pack")
            case .tax: return NSLocalizedString("Tax/Tips", comment: "Pack option name for the tax/tips keyboard pack")
            case .custom: return NSLocalizedString("Custom", comment: "Pack option name for the user-defined custom keyboard pack")
            }
        }
        var keyboardType: KeyboardType? {
            switch self {
            case .none: return .default
            case .math: return .math
            case .finance: return .finance
            case .symbols: return .symbols
            case .programmer: return .programmer
            case .tax: return .tax
            case .custom: return .custom
            }
        }
        var isLocked: Bool { Monetization.isLocked(pack: keyboardType ?? .default) }
    }

    private var options: [PackOption] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Keyboard Packs", comment: "Keyboard packs screen navigation title")
        reloadOptionsFromRC()
        SettingsSync.observe(self) { [weak self] in self?.reloadOptionsFromRC() }
    }

    private func reloadOptionsFromRC() {
        let enabled = Set(RemoteConfigManager.shared.enabledPacks.map { $0 })
        let all = PackOption.allCases
        options = all.filter { pack in
            switch pack {
            case .none: return true
            case .math: return enabled.contains(.math)
            case .finance: return enabled.contains(.finance)
            case .symbols: return enabled.contains(.symbols)
            case .programmer: return enabled.contains(.programmer)
            case .tax: return enabled.contains(.tax)
            case .custom: return enabled.contains(.custom)
            }
        }
        tableView.reloadData()
    }

    deinit {
        SettingsSync.remove(self)
    }
}

extension PacksViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        let option = options[indexPath.row]
        cell.textLabel?.text = option.name
        let selected = (option.keyboardType ?? .default) == KeyboardType.selected
        cell.accessoryType = selected ? .checkmark : .none
        if option.isLocked {
            let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
            lock.tintColor = .lightGray
            cell.accessoryView = lock
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = options[indexPath.row]
        if option.isLocked {
            // If locked, nudge to the Store
            self.show(StoreViewController(), sender: self)
            return
        }
        KeyboardType.selected = option.keyboardType ?? .default
        SettingsSync.post()
        Analytics.logEvent(name: "keyboard_type", attributes: [Analytics.ParameterValue: KeyboardType.selected.rawValue])
        tableView.reloadData()
        // A Custom pack with no keys renders like the default keyboard — guide the user to add keys
        if option == .custom && CustomPackManager.shared.keys.isEmpty {
            self.show(CustomKeysViewController(), sender: self)
        }
    }
}
