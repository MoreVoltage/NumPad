//
//  PacksViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class PacksViewController: TableViewController {
    private enum PackOption: CaseIterable {
        // `.tax` is gone: its pack row was removed (Tax/Tip lives in the long-press "%" overlay).
        case none, math, finance, symbols, programmer, datetime
        // NOTE: These names duplicate KeyboardType.name in Libraries/Keyboard.swift.
        // Consider deduplicating by deriving from keyboardType?.name in a future refactor.
        var name: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "Pack option name for no keyboard pack")
            case .math: return NSLocalizedString("Math", comment: "Pack option name for the math keyboard pack")
            case .finance: return NSLocalizedString("Finance", comment: "Pack option name for the finance keyboard pack")
            case .symbols: return NSLocalizedString("Symbols & Science", comment: "Pack option name for the symbols and science keyboard pack")
            case .programmer: return NSLocalizedString("Programmer", comment: "Pack option name for the programmer keyboard pack")
            case .datetime: return NSLocalizedString("Date & Time", comment: "Pack option name for the date and time pack")
            }
        }
        var keyboardType: KeyboardType? {
            switch self {
            case .none: return .default
            case .math: return .math
            case .finance: return .finance
            case .symbols: return .symbols
            case .programmer: return .programmer
            case .datetime: return .datetime
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
            case .datetime: return enabled.contains(.datetime)
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
            lock.tintColor = .tertiaryLabel
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
            let store = StoreViewController()
            store.source = "packs"
            self.show(store, sender: self)
            return
        }
        KeyboardType.selected = option.keyboardType ?? .default
        SettingsSync.post()
        Analytics.logEvent(name: "keyboard_type", attributes: [Analytics.ParameterValue: KeyboardType.selected.rawValue])
        tableView.reloadData()
    }
}
