//
//  KeyboardHeightViewController.swift
//  NumPad
//
//  Checkmark picker for the keyboard height preset (Small / Default / Tall).
//

import UIKit

class KeyboardHeightViewController: TableViewController {
    private let options = KeyboardHeightPreset.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Keyboard Height", comment: "Keyboard height screen navigation title")
    }
}

extension KeyboardHeightViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return NSLocalizedString("Applies on iPhone. On iPad the keyboard uses the system height.", comment: "Keyboard height screen footer")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        let option = options[indexPath.row]
        cell.textLabel?.text = option.name
        cell.accessoryType = option == KeyboardHeightPreset.selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        KeyboardHeightPreset.selected = options[indexPath.row]
        SettingsSync.post()
        Analytics.logEvent(name: "keyboard_height", attributes: [Analytics.ParameterValue: KeyboardHeightPreset.selected.rawValue])
        tableView.reloadData()
    }
}
