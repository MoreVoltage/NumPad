//
//  KeyboardHeightViewController.swift
//  NumPad
//
//  Checkmark picker for the keyboard height preset (Small / Default / Tall, plus the Pro-gated
//  Kiosk preset on iPad).
//

import UIKit

class KeyboardHeightViewController: TableViewController {
    /// Presets shown for this device — Kiosk is iPad-only (extra-tall, meant for counter/kiosk
    /// mounts; it isn't offered as an iPhone height, so it's filtered out of the list entirely there).
    private var options: [KeyboardHeightPreset] {
        let all = KeyboardHeightPreset.allCases
        return UIDevice.current.userInterfaceIdiom == .pad ? all : all.filter { $0 != .kiosk }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Keyboard Height", comment: "Keyboard height screen navigation title")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Picks up a Kiosk purchase made on the Store screen and returned from.
        tableView.reloadData()
    }
}

extension KeyboardHeightViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return NSLocalizedString("Applies on iPhone and iPad. Pinching the keyboard into its floating mini layout always uses the system height.", comment: "Keyboard height screen footer")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let option = options[indexPath.row]
        cell.textLabel?.text = option.name
        cell.detailTextLabel?.text = option == .kiosk
            ? NSLocalizedString("Extra tall — for counters & kiosks", comment: "Keyboard height Kiosk preset subtitle")
            : nil
        if option == .kiosk, !Monetization.isKioskHeightEntitled {
            cell.accessoryType = .none
            let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
            lock.tintColor = .tertiaryLabel
            cell.accessoryView = lock
        } else {
            cell.accessoryView = nil
            cell.accessoryType = option == KeyboardHeightPreset.selected ? .checkmark : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = options[indexPath.row]
        if option == .kiosk, !Monetization.isKioskHeightEntitled {
            let store = StoreViewController()
            store.source = "kiosk_preset"
            self.show(store, sender: self)
            return
        }
        KeyboardHeightPreset.selected = option
        SettingsSync.post()
        Analytics.logEvent(name: "keyboard_height", attributes: [Analytics.ParameterValue: KeyboardHeightPreset.selected.rawValue])
        tableView.reloadData()
    }
}
