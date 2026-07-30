//
//  ProfileEditorViewController.swift
//  NumPad
//

import UIKit

enum ProfileEditorField: CaseIterable, Hashable {
    case name, keyboardPack, theme, automaticDarkMode, height
    case reversed, rounded, grid, customLayout, handedness, keyboardPage, numpadPlacement
    case repurposeNextKey, clipboardHistory, inlineCalculator, liveMathPreview
    case cursorControls, smartPackDefaulting, resultTape
    case qwertyPrimaryPack, packDisplayBehavior, qwertyLayoutMode
    case qwertyPeriodComma, qwertyAutocorrect, qwertySuggestions, qwertyDoubleSpacePeriod
    case haptics, sound
    case kioskEnabled, kioskTimeout, kioskResetPageAndPack, kioskDismissOverlays
    case kioskClearResultTape, kioskClearClipboardHistory, kioskAdministratorAuthentication
}

enum ProfileEditorOptionPolicy {
    static func numpadPacks(
        enabledPacks: [KeyboardType],
        entitlements: ProfileEntitlements
    ) -> [KeyboardType] {
        let enabled = enabledPacks.filter {
            KeyboardType.packs.contains($0) && !entitlements.isPackLocked($0)
        }
        return [.default] + enabled
    }

    static func qwertyPacks(
        entitlements: ProfileEntitlements,
        hasCustomKeys: Bool,
        hasSnippets: Bool
    ) -> [KeyboardType] {
        QwertyPackFamily.members.filter {
            guard !entitlements.isPackLocked($0) else { return false }
            if $0 == .custom { return hasCustomKeys }
            if $0 == .snippets { return hasSnippets }
            return true
        }
    }
}

final class ProfileEditorViewController: TableViewController {
    static let editableFields = Set(ProfileEditorField.allCases)

    private enum Section: Int, CaseIterable {
        case name, pack, appearance, layout, behavior, qwerty, kiosk, feedback
    }

    private var draft: KeyboardProfile
    var onSave: ((KeyboardProfile) -> Result<Void, Error>)?
    /// Supplied by the legacy profiles flow so persistence is authorized at save time, not only
    /// when the editor is opened.
    var mutationAuthorizer: KioskMutationAuthorizer?

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
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "profile.editor.save"
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
        case .appearance: return 3
        case .layout: return 7
        case .behavior: return 7
        case .qwerty: return 7
        case .kiosk: return 7
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
        case .behavior: return NSLocalizedString("Behavior & Clipboard", comment: "Profile editor section")
        case .qwerty: return NSLocalizedString("QWERTY", comment: "")
        case .kiosk: return NSLocalizedString("Kiosk Session", comment: "Profile editor section")
        case .feedback: return NSLocalizedString("Feedback", comment: "")
        case .none: return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .name:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Name") as? TextFieldCell
                ?? TextFieldCell(style: .default, reuseIdentifier: "Name")
            cell.textField.text = draft.name
            cell.textField.placeholder = NSLocalizedString("Profile name", comment: "")
            cell.textField.accessibilityIdentifier = "profile.editor.name"
            cell.onChange = { [weak self] text in self?.draft.name = text }
            return cell
        case .pack:
            return valueCell(
                title: NSLocalizedString("Keyboard Pack", comment: ""),
                detail: KeyboardType(rawValue: draft.configuration.keyboardTypeRaw)?.name
                    ?? draft.configuration.keyboardTypeRaw,
                identifier: "profile.editor.pack"
            )
        case .appearance:
            switch indexPath.row {
            case 0:
                return valueCell(
                    title: NSLocalizedString("Theme", comment: ""),
                    detail: KeyboardTheme(rawValue: draft.configuration.themeRaw)?.name
                        ?? draft.configuration.themeRaw,
                    identifier: "profile.editor.theme"
                )
            case 1:
                return switchCell(
                    title: NSLocalizedString("Automatic Dark Mode", comment: ""),
                    isOn: draft.configuration.automaticDarkMode,
                    identifier: "profile.editor.automaticDarkMode"
                ) { [weak self] in self?.draft.configuration.automaticDarkMode = $0 }
            default:
                return valueCell(
                    title: NSLocalizedString("Height Preset", comment: ""),
                    detail: KeyboardHeightPreset(rawValue: draft.configuration.heightRaw)?.name
                        ?? draft.configuration.heightRaw,
                    identifier: "profile.editor.height"
                )
            }
        case .layout:
            return layoutCell(indexPath.row)
        case .behavior:
            return behaviorCell(indexPath.row)
        case .qwerty:
            return qwertyCell(indexPath.row)
        case .kiosk:
            return kioskCell(indexPath.row)
        case .feedback:
            if indexPath.row == 0 {
                return switchCell(
                    title: NSLocalizedString("Haptics", comment: ""),
                    isOn: draft.configuration.hapticsEnabled,
                    identifier: "profile.editor.haptics"
                ) { [weak self] in self?.draft.configuration.hapticsEnabled = $0 }
            }
            return switchCell(
                title: NSLocalizedString("Key Click Sound", comment: ""),
                isOn: draft.configuration.soundEnabled,
                identifier: "profile.editor.sound"
            ) { [weak self] in self?.draft.configuration.soundEnabled = $0 }
        case .none:
            return UITableViewCell()
        }
    }

    private func layoutCell(_ row: Int) -> UITableViewCell {
        switch row {
        case 0:
            return switchCell(
                title: NSLocalizedString("7-8-9 on Top", comment: ""),
                isOn: draft.configuration.reversedMode,
                identifier: "profile.editor.reversed"
            ) { [weak self] in self?.draft.configuration.reversedMode = $0 }
        case 1:
            return switchCell(
                title: NSLocalizedString("Rounded", comment: ""),
                isOn: draft.configuration.roundedCorners,
                identifier: "profile.editor.rounded"
            ) { [weak self] in self?.draft.configuration.roundedCorners = $0 }
        case 2:
            return switchCell(
                title: NSLocalizedString("Grid", comment: ""),
                isOn: draft.configuration.grid,
                identifier: "profile.editor.grid"
            ) { [weak self] in self?.draft.configuration.grid = $0 }
        case 3:
            return valueCell(
                title: NSLocalizedString("Custom Layout", comment: "Profile editor custom layout"),
                detail: draft.configuration.customKeyboardConfig?.name
                    ?? NSLocalizedString("Not Configured", comment: "No custom layout"),
                identifier: "profile.editor.customLayout"
            )
        case 4:
            return valueCell(
                title: NSLocalizedString("Handedness", comment: ""),
                detail: Handedness(rawValue: draft.configuration.handednessRaw)?.name
                    ?? draft.configuration.handednessRaw,
                identifier: "profile.editor.handedness"
            )
        case 5:
            return valueCell(
                title: NSLocalizedString("Keyboard Page", comment: ""),
                detail: draft.configuration.keyboardPageRaw == "qwerty"
                    ? NSLocalizedString("QWERTY", comment: "")
                    : NSLocalizedString("Numpad", comment: ""),
                identifier: "profile.editor.page"
            )
        default:
            return valueCell(
                title: NSLocalizedString("Numpad Placement", comment: ""),
                detail: placementName(draft.configuration.numpadPlacementRaw),
                identifier: "profile.editor.numpadPlacement"
            )
        }
    }

    private func behaviorCell(_ row: Int) -> UITableViewCell {
        let titles = [
            NSLocalizedString("Repurpose Next Keyboard Key", comment: ""),
            NSLocalizedString("Clipboard History", comment: ""),
            NSLocalizedString("Inline Calculator", comment: ""),
            NSLocalizedString("Live Math Preview", comment: ""),
            NSLocalizedString("Cursor Controls", comment: ""),
            NSLocalizedString("Smart Pack Defaulting", comment: ""),
            NSLocalizedString("Result Tape", comment: "")
        ]
        let values = [
            draft.configuration.repurposeNextKey,
            draft.configuration.clipboardHistoryEnabled,
            draft.configuration.inlineCalculator,
            draft.configuration.liveMathPreview,
            draft.configuration.cursorControls,
            draft.configuration.smartPackDefaulting,
            draft.configuration.resultTapeEnabled
        ]
        return switchCell(
            title: titles[row],
            isOn: values[row],
            identifier: "profile.editor.behavior.\(row)"
        ) { [weak self] value in
            guard let self else { return }
            switch row {
            case 0: draft.configuration.repurposeNextKey = value
            case 1: draft.configuration.clipboardHistoryEnabled = value
            case 2: draft.configuration.inlineCalculator = value
            case 3: draft.configuration.liveMathPreview = value
            case 4: draft.configuration.cursorControls = value
            case 5: draft.configuration.smartPackDefaulting = value
            default: draft.configuration.resultTapeEnabled = value
            }
        }
    }

    private func qwertyCell(_ row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let detail = draft.configuration.qwertyPrimaryPackRaw
                .flatMap(KeyboardType.init(rawValue:))?.name
                ?? NSLocalizedString("Number Row", comment: "No QWERTY primary pack")
            return valueCell(
                title: NSLocalizedString("Primary Top Row", comment: ""),
                detail: detail,
                identifier: "profile.editor.qwerty.primaryPack"
            )
        case 1:
            return valueCell(
                title: NSLocalizedString("Pack Display", comment: ""),
                detail: packDisplayName(draft.configuration.packDisplayBehaviorRaw),
                identifier: "profile.editor.qwerty.packDisplay"
            )
        case 2:
            return valueCell(
                title: NSLocalizedString("iPad Layout", comment: ""),
                detail: qwertyLayoutName(draft.configuration.qwertyLayoutModeRaw),
                identifier: "profile.editor.qwerty.layout"
            )
        default:
            let titles = [
                NSLocalizedString("Period & Comma Keys", comment: ""),
                NSLocalizedString("Autocorrect", comment: ""),
                NSLocalizedString("Suggestions", comment: ""),
                NSLocalizedString("Double-Space Period", comment: "")
            ]
            let values = [
                draft.configuration.qwertyPeriodComma,
                draft.configuration.qwertyAutocorrect,
                draft.configuration.qwertySuggestions,
                draft.configuration.qwertyDoubleSpacePeriod
            ]
            let switchIndex = row - 3
            return switchCell(
                title: titles[switchIndex],
                isOn: values[switchIndex],
                identifier: "profile.editor.qwerty.\(switchIndex)"
            ) { [weak self] value in
                guard let self else { return }
                switch switchIndex {
                case 0: draft.configuration.qwertyPeriodComma = value
                case 1: draft.configuration.qwertyAutocorrect = value
                case 2: draft.configuration.qwertySuggestions = value
                default: draft.configuration.qwertyDoubleSpacePeriod = value
                }
            }
        }
    }

    private func kioskCell(_ row: Int) -> UITableViewCell {
        let policy = draft.kioskPolicy
        let isEnforceableKiosk = draft.kind == .kiosk
        switch row {
        case 0:
            return switchCell(
                title: NSLocalizedString("Enable Session Policy", comment: ""),
                isOn: policy != nil,
                identifier: "profile.editor.kiosk.enabled",
                enabled: false
            ) { _ in }
        case 1:
            return valueCell(
                title: NSLocalizedString("Inactivity Timeout", comment: ""),
                detail: policy.map {
                    String(
                        format: NSLocalizedString("%.0f seconds", comment: "Kiosk timeout value"),
                        $0.inactivityTimeout
                    )
                } ?? NSLocalizedString("Disabled", comment: ""),
                identifier: "profile.editor.kiosk.timeout",
                enabled: isEnforceableKiosk && policy != nil
            )
        default:
            let titles = [
                NSLocalizedString("Reset Page & Pack", comment: ""),
                NSLocalizedString("Dismiss Overlays", comment: ""),
                NSLocalizedString("Clear Result Tape", comment: ""),
                NSLocalizedString("Clear Clipboard History", comment: ""),
                NSLocalizedString("Require Administrator Authentication", comment: "")
            ]
            let values = [
                policy?.resetPageAndPack ?? false,
                policy?.dismissOverlays ?? false,
                policy?.clearResultTape ?? false,
                policy?.clearClipboardHistory ?? false,
                policy?.requireAdministratorAuthentication ?? false
            ]
            let switchIndex = row - 2
            return switchCell(
                title: titles[switchIndex],
                isOn: values[switchIndex],
                identifier: "profile.editor.kiosk.\(switchIndex)",
                enabled: isEnforceableKiosk && policy != nil
            ) { [weak self] value in
                guard var updated = self?.draft.kioskPolicy else { return }
                switch switchIndex {
                case 0: updated.resetPageAndPack = value
                case 1: updated.dismissOverlays = value
                case 2: updated.clearResultTape = value
                case 3: updated.clearClipboardHistory = value
                default: updated.requireAdministratorAuthentication = value
                }
                self?.draft.kioskPolicy = updated
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .pack:
            cyclePack()
        case .appearance where indexPath.row == 0:
            cycleTheme()
        case .appearance where indexPath.row == 2:
            cycleHeight()
        case .layout where indexPath.row == 3:
            presentCustomLayoutActions(source: indexPath)
            return
        case .layout where indexPath.row == 4:
            cycleHandedness()
        case .layout where indexPath.row == 5:
            draft.configuration.keyboardPageRaw =
                draft.configuration.keyboardPageRaw == "qwerty" ? "numpad" : "qwerty"
        case .layout where indexPath.row == 6:
            cycleNumpadPlacement()
        case .qwerty where indexPath.row == 0:
            cyclePrimaryPack()
        case .qwerty where indexPath.row == 1:
            cyclePackDisplayBehavior()
        case .qwerty where indexPath.row == 2:
            cycleQwertyLayout()
        case .kiosk where indexPath.row == 1:
            guard draft.kind == .kiosk, draft.kioskPolicy != nil else { return }
            cycleKioskTimeout()
        default:
            return
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    private func cyclePack() {
        let entitlements = ProfileEntitlements.live()
        let available = ProfileEditorOptionPolicy.numpadPacks(
            enabledPacks: RemoteConfigManager.shared.enabledPacks,
            entitlements: entitlements
        )
        let packs = available.isEmpty ? [.default] : available
        let current = KeyboardType(rawValue: draft.configuration.keyboardTypeRaw) ?? .default
        let index = packs.firstIndex(of: current).map { ($0 + 1) % packs.count } ?? 0
        draft.configuration.keyboardTypeRaw = packs[index].rawValue
    }

    private func cycleTheme() {
        let entitlements = ProfileEntitlements.live()
        let available = Array(KeyboardTheme.allCases).filter { !entitlements.isThemeLocked($0) }
        let themes = available.isEmpty ? [.white] : available
        let current = KeyboardTheme(rawValue: draft.configuration.themeRaw) ?? .white
        let index = themes.firstIndex(of: current).map { ($0 + 1) % themes.count } ?? 0
        draft.configuration.themeRaw = themes[index].rawValue
    }

    private func cycleHeight() {
        let entitlements = ProfileEntitlements.live()
        var presets = KeyboardHeightPreset.allCases
        if !entitlements.kioskHeightEntitled {
            presets.removeAll { $0 == .kiosk }
        }
        let current = KeyboardHeightPreset(rawValue: draft.configuration.heightRaw) ?? .regular
        let index = presets.firstIndex(of: current).map { ($0 + 1) % presets.count } ?? 0
        draft.configuration.heightRaw = presets[index].rawValue
    }

    private func cycleHandedness() {
        let current = Handedness(rawValue: draft.configuration.handednessRaw) ?? .right
        draft.configuration.handednessRaw = (current == .right ? Handedness.left : .right).rawValue
    }

    private func cycleNumpadPlacement() {
        let values = NumpadPlacement.allCases
        let current = NumpadPlacement(rawValue: draft.configuration.numpadPlacementRaw) ?? .automatic
        let index = values.firstIndex(of: current).map { ($0 + 1) % values.count } ?? 0
        draft.configuration.numpadPlacementRaw = values[index].rawValue
    }

    private func cyclePrimaryPack() {
        let available = ProfileEditorOptionPolicy.qwertyPacks(
            entitlements: .live(),
            hasCustomKeys: CustomPackManager.shared.keys.contains { !$0.isEmpty },
            hasSnippets: SnippetsManager.shared.snippets.contains { !$0.text.isEmpty }
        )
        let values: [KeyboardType?] = [nil] + available.map(Optional.some)
        let current = draft.configuration.qwertyPrimaryPackRaw.flatMap(KeyboardType.init(rawValue:))
        let index = values.firstIndex(where: { $0 == current }).map { ($0 + 1) % values.count } ?? 0
        draft.configuration.qwertyPrimaryPackRaw = values[index]?.rawValue
    }

    private func cyclePackDisplayBehavior() {
        let current = PackDisplayBehavior(rawValue: draft.configuration.packDisplayBehaviorRaw)
            ?? .lastUsed
        draft.configuration.packDisplayBehaviorRaw =
            (current == .lastUsed ? PackDisplayBehavior.primarySelected : .lastUsed).rawValue
    }

    private func cycleQwertyLayout() {
        let values = QwertyLayoutMode.allCases
        let current = QwertyLayoutMode(rawValue: draft.configuration.qwertyLayoutModeRaw) ?? .automatic
        let index = values.firstIndex(of: current).map { ($0 + 1) % values.count } ?? 0
        draft.configuration.qwertyLayoutModeRaw = values[index].rawValue
    }

    private func cycleKioskTimeout() {
        let values: [TimeInterval] = [30, 60, 120, 300, 600, 1_800, 3_600]
        guard var policy = draft.kioskPolicy else { return }
        let index = values.firstIndex(of: policy.inactivityTimeout)
            .map { ($0 + 1) % values.count } ?? 0
        policy.inactivityTimeout = values[index]
        draft.kioskPolicy = policy
    }

    private func presentCustomLayoutActions(source indexPath: IndexPath) {
        let alert = UIAlertController(
            title: NSLocalizedString("Custom Layout", comment: ""),
            message: NSLocalizedString(
                "Use the current custom keyboard layout in this profile, or remove it.",
                comment: "Profile editor custom layout explanation"
            ),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Use Current Layout", comment: ""),
            style: .default
        ) { [weak self] _ in
            self?.draft.configuration.customKeyboardConfig =
                CustomKeyboardStore(defaults: .group).load()
                    ?? CustomKeyboardConfig(name: NSLocalizedString("Custom", comment: ""))
            self?.tableView.reloadRows(at: [indexPath], with: .none)
        })
        if draft.configuration.customKeyboardConfig != nil {
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Remove from Profile", comment: ""),
                style: .destructive
            ) { [weak self] _ in
                self?.draft.configuration.customKeyboardConfig = nil
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = alert.popoverPresentationController,
           let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(alert, animated: true)
    }

    private func placementName(_ raw: String) -> String {
        switch NumpadPlacement(rawValue: raw) {
        case .automatic: return NSLocalizedString("Automatic", comment: "")
        case .center: return NSLocalizedString("Center", comment: "")
        case .left: return NSLocalizedString("Left", comment: "")
        case .right: return NSLocalizedString("Right", comment: "")
        case .fullWidth: return NSLocalizedString("Full Width", comment: "")
        case .none: return raw
        }
    }

    private func qwertyLayoutName(_ raw: String) -> String {
        switch QwertyLayoutMode(rawValue: raw) {
        case .automatic: return NSLocalizedString("Automatic", comment: "")
        case .centered: return NSLocalizedString("Centered", comment: "")
        case .split: return NSLocalizedString("Split", comment: "")
        case .compactLeft: return NSLocalizedString("Compact Left", comment: "")
        case .compactRight: return NSLocalizedString("Compact Right", comment: "")
        case .none: return raw
        }
    }

    private func packDisplayName(_ raw: String) -> String {
        switch PackDisplayBehavior(rawValue: raw) {
        case .lastUsed: return NSLocalizedString("Last Used", comment: "")
        case .primarySelected: return NSLocalizedString("Primary Selected", comment: "")
        case .none: return raw
        }
    }

    private func valueCell(
        title: String,
        detail: String?,
        identifier: String,
        enabled: Bool = true
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Value")
            ?? Cell(style: .value1, reuseIdentifier: "Value")
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.accessoryType = enabled ? .disclosureIndicator : .none
        cell.selectionStyle = enabled ? .default : .none
        cell.isUserInteractionEnabled = enabled
        cell.textLabel?.isEnabled = enabled
        cell.detailTextLabel?.isEnabled = enabled
        cell.accessibilityIdentifier = identifier
        return cell
    }

    private func switchCell(
        title: String,
        isOn: Bool,
        identifier: String,
        enabled: Bool = true,
        onChange: @escaping (Bool) -> Void
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SwitchCell
            ?? SwitchCell(style: .default, reuseIdentifier: "Switch")
        cell.textLabel?.text = title
        cell.selectionStyle = .none
        cell.switchView.isOn = isOn
        cell.switchView.isEnabled = enabled
        cell.textLabel?.isEnabled = enabled
        cell.isUserInteractionEnabled = enabled
        cell.accessibilityIdentifier = identifier
        cell.valueChanged = { switchView in onChange(switchView.isOn) }
        return cell
    }

    @objc private func save() {
        do {
            let validated = try draft.validated()
            let persist: () -> Void = { [weak self] in
                self?.persist(validated)
            }
            guard let mutationAuthorizer else {
                persist()
                return
            }
            mutationAuthorizer.performIfAuthorized(persist) { [weak self] result in
                guard result == .denied else { return }
                self?.presentAuthenticationFailure()
            }
        } catch {
            presentValidationError(error)
        }
    }

    private func persist(_ profile: KeyboardProfile) {
        switch onSave?(profile) ?? .success(()) {
            case .success:
                navigationController?.popViewController(animated: true)
            case .failure(let error):
                presentValidationError(error)
        }
    }

    private func presentValidationError(_ error: Error) {
        let alert = UIAlertController(
            title: NSLocalizedString("Invalid Profile", comment: ""),
            message: String(describing: error),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func presentAuthenticationFailure() {
        let alert = UIAlertController(
            title: NSLocalizedString("Authentication Failed", comment: "Kiosk mutation authentication failed title"),
            message: NSLocalizedString("Authenticate to change saved setups.", comment: "Kiosk mutation authentication failed message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
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
