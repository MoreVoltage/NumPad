//
//  ProfileEditorViewController.swift
//  NumPad
//

import UIKit

final class ProfileEditorViewController: TableViewController {
    private enum Section: Int, CaseIterable {
        case name, pack, appearance, layout, qwerty, feedback
    }

    private var draft: KeyboardProfile
    var onSave: ((KeyboardProfile) -> Void)?

    init(profile: KeyboardProfile) {
        self.draft = profile
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Edit Profile", comment: "Profile editor title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(save)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .name: return 1
        case .pack: return 1
        case .appearance: return 2
        case .layout: return 5
        case .qwerty: return 4
        case .feedback: return 2
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .name: return NSLocalizedString("Name", comment: "")
        case .pack: return NSLocalizedString("Pack", comment: "")
        case .appearance: return NSLocalizedString("Appearance", comment: "")
        case .layout: return NSLocalizedString("Layout", comment: "")
        case .qwerty: return NSLocalizedString("QWERTY", comment: "")
        case .feedback: return NSLocalizedString("Feedback", comment: "")
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .name:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Name") as? TextFieldCell
                ?? TextFieldCell(style: .default, reuseIdentifier: "Name")
            cell.textField.text = draft.name
            cell.textField.placeholder = NSLocalizedString("Profile name", comment: "")
            cell.onChange = { [weak self] text in self?.draft.name = text }
            return cell
        case .pack:
            return valueCell(
                title: NSLocalizedString("Keyboard Pack", comment: ""),
                detail: KeyboardType(rawValue: draft.configuration.keyboardTypeRaw)?.name
                    ?? draft.configuration.keyboardTypeRaw
            )
        case .appearance:
            if indexPath.row == 0 {
                return valueCell(
                    title: NSLocalizedString("Theme", comment: ""),
                    detail: KeyboardTheme(rawValue: draft.configuration.themeRaw)?.name
                        ?? draft.configuration.themeRaw
                )
            }
            return switchCell(
                title: NSLocalizedString("Automatic Dark Mode", comment: ""),
                isOn: draft.configuration.automaticDarkMode
            ) { [weak self] on in self?.draft.configuration.automaticDarkMode = on }
        case .layout:
            if indexPath.row >= 3 {
                if indexPath.row == 3 {
                    return valueCell(
                        title: NSLocalizedString("Height Preset", comment: ""),
                        detail: KeyboardHeightPreset(rawValue: draft.configuration.heightRaw)?.name
                            ?? draft.configuration.heightRaw
                    )
                }
                return valueCell(
                    title: NSLocalizedString("Keyboard Page", comment: ""),
                    detail: draft.configuration.keyboardPageRaw
                )
            }
            let titles = [
                NSLocalizedString("7-8-9 on Top", comment: ""),
                NSLocalizedString("Rounded", comment: ""),
                NSLocalizedString("Grid", comment: "")
            ]
            let values = [
                draft.configuration.reversedMode,
                draft.configuration.roundedCorners,
                draft.configuration.grid
            ]
            return switchCell(title: titles[indexPath.row], isOn: values[indexPath.row]) { [weak self] on in
                guard let self else { return }
                switch indexPath.row {
                case 0: self.draft.configuration.reversedMode = on
                case 1: self.draft.configuration.roundedCorners = on
                default: self.draft.configuration.grid = on
                }
            }
        case .qwerty:
            let titles = [
                NSLocalizedString("Autocorrect", comment: ""),
                NSLocalizedString("Suggestions", comment: ""),
                NSLocalizedString("Double-Space Period", comment: ""),
                NSLocalizedString("Period & Comma Keys", comment: "")
            ]
            let values = [
                draft.configuration.qwertyAutocorrect,
                draft.configuration.qwertySuggestions,
                draft.configuration.qwertyDoubleSpacePeriod,
                draft.configuration.qwertyPeriodComma
            ]
            return switchCell(title: titles[indexPath.row], isOn: values[indexPath.row]) { [weak self] on in
                guard let self else { return }
                switch indexPath.row {
                case 0: self.draft.configuration.qwertyAutocorrect = on
                case 1: self.draft.configuration.qwertySuggestions = on
                case 2: self.draft.configuration.qwertyDoubleSpacePeriod = on
                default: self.draft.configuration.qwertyPeriodComma = on
                }
            }
        case .feedback:
            if indexPath.row == 0 {
                return switchCell(
                    title: NSLocalizedString("Haptics", comment: ""),
                    isOn: draft.configuration.hapticsEnabled
                ) { [weak self] on in self?.draft.configuration.hapticsEnabled = on }
            }
            return switchCell(
                title: NSLocalizedString("Key Click Sound", comment: ""),
                isOn: draft.configuration.soundEnabled
            ) { [weak self] on in self?.draft.configuration.soundEnabled = on }
        case .none:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .pack {
            cyclePack()
            tableView.reloadRows(at: [indexPath], with: .none)
        } else if Section(rawValue: indexPath.section) == .appearance, indexPath.row == 0 {
            cycleTheme()
            tableView.reloadRows(at: [indexPath], with: .none)
        } else if Section(rawValue: indexPath.section) == .layout, indexPath.row == 3 {
            cycleHeight()
            tableView.reloadRows(at: [indexPath], with: .none)
        } else if Section(rawValue: indexPath.section) == .layout, indexPath.row == 4 {
            draft.configuration.keyboardPageRaw =
                draft.configuration.keyboardPageRaw == "qwerty" ? "numpad" : "qwerty"
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func cyclePack() {
        let entitlements = ProfileEntitlements.live()
        let packs = ([KeyboardType.default] + KeyboardType.packs).filter { !entitlements.isPackLocked($0) }
        let current = KeyboardType(rawValue: draft.configuration.keyboardTypeRaw) ?? .default
        let idx = packs.firstIndex(of: current).map { ($0 + 1) % packs.count } ?? 0
        draft.configuration.keyboardTypeRaw = (packs.isEmpty ? [.default] : packs)[idx].rawValue
    }

    private func cycleHeight() {
        let entitlements = ProfileEntitlements.live()
        var presets = KeyboardHeightPreset.allCases
        if !entitlements.kioskHeightEntitled {
            presets.removeAll { $0 == .kiosk }
        }
        let current = KeyboardHeightPreset(rawValue: draft.configuration.heightRaw) ?? .regular
        let idx = presets.firstIndex(of: current).map { ($0 + 1) % presets.count } ?? 0
        draft.configuration.heightRaw = presets[idx].rawValue
    }

    private func cycleTheme() {
        let entitlements = ProfileEntitlements.live()
        let themes = Array(KeyboardTheme.allCases).filter { !entitlements.isThemeLocked($0) }
        let current = KeyboardTheme(rawValue: draft.configuration.themeRaw) ?? .white
        let idx = themes.firstIndex(of: current).map { ($0 + 1) % max(themes.count, 1) } ?? 0
        draft.configuration.themeRaw = (themes.isEmpty ? [.white] : themes)[idx].rawValue
    }

    private func valueCell(title: String, detail: String?) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Value")
            ?? Cell(style: .value1, reuseIdentifier: "Value")
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func switchCell(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SwitchCell
            ?? SwitchCell(style: .default, reuseIdentifier: "Switch")
        cell.textLabel?.text = title
        cell.selectionStyle = .none
        cell.switchView.isOn = isOn
        cell.valueChanged = { switchView in onChange(switchView.isOn) }
        return cell
    }

    @objc private func save() {
        do {
            let validated = try draft.validated()
            onSave?(validated)
            navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(
                title: NSLocalizedString("Invalid Profile", comment: ""),
                message: String(describing: error),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func cancel() {
        navigationController?.popViewController(animated: true)
    }
}

private final class TextFieldCell: UITableViewCell {
    let textField = UITextField()
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.addTarget(self, action: #selector(changed), for: .editingChanged)
        contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func changed() {
        onChange?(textField.text ?? "")
    }
}
