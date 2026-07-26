//
//  QwertySetupViewController.swift
//  NumPad
//
//  The re-runnable setup wizard for NumPad Type, the full-QWERTY keyboard (owner decision
//  §0.4, docs/plans/full-keyboard/): enablement, the default top-row pack, the LAST-USED vs
//  PRIMARY-SELECTED reopen behavior, and the period/comma layout switch. Reached from Home →
//  NumPad Type (flag-gated) — unlike the one-shot `onboardingShown` first-run flow, this
//  screen can be revisited any time; the first-run onboarding gains its QWERTY step when the
//  rollout flag flips at GA.
//

import UIKit

class QwertySetupViewController: TableViewController {

    private enum Section: Int, CaseIterable {
        case enablement, defaultPack, reopenBehavior, typing, layout, reset
    }

    /// Number Row plus the entitled crossover packs (same machinery as the keyboard itself).
    private var packOptions: [KeyboardType?] {
        [nil] + QwertyPackFamily.members.filter { pack in
            guard !Monetization.isLocked(pack: pack) else { return false }
            if pack == .custom { return !CustomPackManager.shared.keys.isEmpty }
            if pack == .snippets { return SnippetsManager.shared.snippets.contains { !$0.text.isEmpty } }
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("NumPad Type", comment: "QWERTY setup screen title")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData() // enablement state may have changed in Settings
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .enablement: return 1
        case .defaultPack: return packOptions.count
        case .reopenBehavior: return 2
        case .typing: return 3
        case .layout: return 1
        case .reset: return 2
        case nil: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .enablement:
            return NSLocalizedString("Keyboard", comment: "QWERTY setup section header")
        case .defaultPack:
            return NSLocalizedString("Default Top Row", comment: "QWERTY setup section header")
        case .reopenBehavior:
            return NSLocalizedString("Reopen With", comment: "QWERTY setup section header")
        case .typing:
            return NSLocalizedString("Typing", comment: "QWERTY setup section header")
        case .layout:
            return NSLocalizedString("Layout", comment: "QWERTY setup section header")
        case .reset:
            return NSLocalizedString("Privacy", comment: "QWERTY setup section header")
        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .defaultPack:
            return NSLocalizedString("The row above the letters: the number line, or one of your packs.",
                                     comment: "QWERTY setup default-pack footer")
        case .reopenBehavior:
            return NSLocalizedString("Last Used reopens whatever was showing when you left. My Default always reopens your chosen top row.",
                                     comment: "QWERTY setup reopen-behavior footer")
        case .layout:
            return NSLocalizedString("Keeps period and comma next to the space bar, so the most-typed punctuation never needs the 123 key.",
                                     comment: "QWERTY setup period/comma footer")
        case .reset:
            return NSLocalizedString("Clears the words NumPad Type has learned from your typing. Learned words never leave this device.",
                                     comment: "QWERTY setup reset-personalization footer")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.detailTextLabel?.text = nil
        cell.textLabel?.textColor = .text  // undo the reset row's red on reuse

        switch Section(rawValue: indexPath.section) {
        case .enablement:
            cell.textLabel?.text = NSLocalizedString("Enable in Settings",
                                                     comment: "QWERTY setup enablement row")
            cell.accessoryType = .disclosureIndicator
            // Single-keyboard architecture: the QWERTY page ships inside the one NumPad
            // keyboard, so "enabled" means the NumPad keyboard itself is enabled.
            cell.detailTextLabel?.text = KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)
                ?? NSLocalizedString("Off", comment: "QWERTY setup enablement state")
        case .defaultPack:
            let option = packOptions[indexPath.row]
            cell.textLabel?.text = option?.name
                ?? NSLocalizedString("Number Row", comment: "QWERTY setup number-row option")
            cell.accessoryType = UserPrefs.qwertyPrimaryPack == option ? .checkmark : .none
        case .reopenBehavior:
            let behavior: PackDisplayBehavior = indexPath.row == 0 ? .lastUsed : .primarySelected
            cell.textLabel?.text = behavior == .lastUsed
                ? NSLocalizedString("Last Used Pack", comment: "QWERTY setup reopen option")
                : NSLocalizedString("My Default", comment: "QWERTY setup reopen option")
            cell.accessoryType = UserPrefs.packDisplayBehavior == behavior ? .checkmark : .none
        case .typing:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell
                ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            let titles = [
                NSLocalizedString("Autocorrect", comment: "QWERTY setup autocorrect toggle"),
                NSLocalizedString("Suggestions", comment: "QWERTY setup suggestions toggle"),
                NSLocalizedString("Double-Space Period", comment: "QWERTY setup double-space period toggle")
            ]
            let getters: [() -> Bool] = [
                { UserPrefs.qwertyAutocorrect },
                { UserPrefs.qwertySuggestions },
                { UserPrefs.qwertyDoubleSpacePeriod }
            ]
            let setters: [(Bool) -> Void] = [
                { UserPrefs.qwertyAutocorrect = $0 },
                { UserPrefs.qwertySuggestions = $0 },
                { UserPrefs.qwertyDoubleSpacePeriod = $0 }
            ]
            let events = ["qwerty_autocorrect", "qwerty_suggestions", "qwerty_double_space_period"]
            cell.textLabel?.text = titles[indexPath.row]
            cell.switchView.isOn = getters[indexPath.row]()
            cell.valueChanged = { switchView in
                setters[indexPath.row](switchView.isOn)
                SettingsSync.post()
                Analytics.logEvent(name: events[indexPath.row],
                                   attributes: [Analytics.ParameterValue: switchView.isOn])
            }
            return cell
        case .layout:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell
                ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.textLabel?.text = NSLocalizedString("Period & Comma Keys",
                                                     comment: "QWERTY setup period/comma toggle")
            cell.selectionStyle = .none
            cell.switchView.isOn = UserPrefs.qwertyPeriodComma
            cell.valueChanged = { switchView in
                UserPrefs.qwertyPeriodComma = switchView.isOn
                SettingsSync.post()
                Analytics.logEvent(name: "qwerty_period_comma",
                                   attributes: [Analytics.ParameterValue: switchView.isOn])
            }
            return cell
        case .reset:
            if indexPath.row == 0 {
                cell.textLabel?.text = NSLocalizedString("Personal Dictionary",
                                                         comment: "QWERTY personal dictionary row")
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = NSLocalizedString("Reset Typing Personalization",
                                                         comment: "QWERTY setup reset row")
                cell.textLabel?.textColor = .systemRed
            }
        case nil:
            break
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .enablement:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .defaultPack:
            let option = packOptions[indexPath.row]
            UserPrefs.qwertyPrimaryPack = option
            // Seed the live strip too so the choice is visible on the next keyboard raise
            // regardless of the reopen behavior.
            UserPrefs.qwertyTopStripPack = option
            SettingsSync.post()
            Analytics.logEvent(name: "qwerty_default_pack",
                               attributes: [Analytics.ParameterValue: option?.rawValue ?? "numbers"])
            tableView.reloadData()
        case .reopenBehavior:
            UserPrefs.packDisplayBehavior = indexPath.row == 0 ? .lastUsed : .primarySelected
            SettingsSync.post()
            Analytics.logEvent(name: "qwerty_reopen_behavior",
                               attributes: [Analytics.ParameterValue: UserPrefs.packDisplayBehavior.rawValue])
            tableView.reloadData()
        case .typing, .layout:
            break
        case .reset:
            if indexPath.row == 0 {
                show(QwertyPersonalDictionaryViewController(), sender: self)
            } else {
                confirmResetTypingPersonalization()
            }
        default:
            break
        }
    }

    // MARK: - Reset Typing Personalization

    /// Destructive, so it confirms first. PRIVACY (design §2): clearing is the ONLY thing
    /// the app ever does with this data — no SettingsSync broadcast (the keyboard reloads
    /// the store on its next page activation) and no analytics on this path.
    private func confirmResetTypingPersonalization() {
        let alert = UIAlertController(
            title: NSLocalizedString("Reset Typing Personalization?",
                                     comment: "QWERTY setup reset confirmation title"),
            message: NSLocalizedString("This removes every word NumPad Type has learned from your typing and its touch-accuracy tuning. This cannot be undone.",
                                       comment: "QWERTY setup reset confirmation message"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Reset", comment: "QWERTY setup reset confirmation action"),
            style: .destructive) { _ in
                // The odd/even app-group epoch is published before either clear and completed
                // only afterward. Epoch-tagged keyboard writes from before reset therefore fail
                // closed even if their physical UserDefaults write lands late.
                QwertyTouchPersonalizationPersistence.resetAll()
            })
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Cancel", comment: "QWERTY setup reset confirmation cancel"),
            style: .cancel))
        present(alert, animated: true)
    }
}
