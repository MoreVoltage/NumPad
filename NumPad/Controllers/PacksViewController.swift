//
//  PacksViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class PacksViewController: TableViewController {
    private enum PackOption: CaseIterable {
        case none, math, finance, symbols, programmer, tax
        var name: String {
            switch self {
            case .none: return "None"
            case .math: return "Math"
            case .finance: return "Finance"
            case .symbols: return "Symbols"
            case .programmer: return "Programmer"
            case .tax: return "Tax/Tips"
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
            }
        }
        var isPremium: Bool { self != .none }
    }

    private var options: [PackOption] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = "Keyboard Packs"
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
            }
        }
        tableView.reloadData()
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
        let shouldLock = Monetization.paywallEnabled && option.isPremium && !Monetization.isProEntitled
        if shouldLock {
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
        let locked = Monetization.paywallEnabled && option.isPremium && !Monetization.isProEntitled
        if locked {
            // If locked, nudge to Store (Preview)
            self.show(StoreViewController(), sender: self)
            return
        }
        KeyboardType.selected = option.keyboardType ?? .default
        Analytics.logEvent(name: "keyboard_type", attributes: [Analytics.ParameterValue: KeyboardType.selected.rawValue])
        tableView.reloadData()
    }
}


