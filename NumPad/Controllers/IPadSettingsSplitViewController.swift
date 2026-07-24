import UIKit
import SwiftRater

final class IPadSettingsSplitViewController: UISplitViewController {
    static func shouldAnimateTransition(reduceMotionEnabled: Bool) -> Bool {
        !reduceMotionEnabled
    }

    convenience init() {
        self.init(style: .doubleColumn)
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        // Readable primary column — avoid stretching a phone list across an 11/13-inch canvas.
        minimumPrimaryColumnWidth = 280
        maximumPrimaryColumnWidth = 360
        preferredPrimaryColumnWidthFraction = 0.32

        let sections = HomeSettingsModel.sections(
            fullKeyboardVisible: FeatureFlags.isFullKeyboardActive,
            isPad: true
        )
        let list = SettingsSidebarController(sections: sections) { [weak self] destination in
            self?.showDetail(destination)
        }
        setViewController(UINavigationController(rootViewController: list), for: .primary)
        setViewController(UINavigationController(rootViewController: DashboardViewController()), for: .secondary)
    }

    private func showDetail(_ destination: SettingsDestination) {
        switch destination {
        case .feedback:
            if let url = URL(string: "mailto:support@morevoltage.com?subject=NumPad%20Feedback") {
                UIApplication.shared.open(url)
            }
            Analytics.logEvent(name: "send_feedback")
            return
        case .rate:
            let host = viewController(for: .secondary) ?? self
            SwiftRater.rateApp(host: host)
            Analytics.logEvent(name: "rate")
            return
        case .numberOrder:
            Keyboard.isReversedMode.toggle()
            SettingsSync.post()
            Analytics.logEvent(name: "reversed_mode", attributes: [Analytics.ParameterValue: Keyboard.isReversedMode])
            return
        case .roundedCorners:
            Keyboard.hasRoundedCorners.toggle()
            SettingsSync.post()
            Analytics.logEvent(name: "rounded_corners", attributes: [Analytics.ParameterValue: Keyboard.hasRoundedCorners])
            return
        case .grid:
            Keyboard.hasGrid.toggle()
            SettingsSync.post()
            Analytics.logEvent(name: "grid", attributes: [Analytics.ParameterValue: Keyboard.hasGrid])
            return
        default:
            break
        }

        let controller: UIViewController
        switch destination {
        case .dashboard: controller = DashboardViewController()
        case .profiles: controller = ProfilesViewController()
        case .typingBehavior: controller = TypingBehaviorViewController()
        case .kioskProvisioning: controller = KioskProvisioningViewController()
        case .pro: controller = StoreViewController()
        case .privacy: controller = PrivacyViewController()
        case .featureGuide: controller = FeaturesGuideViewController()
        case .keyboardSetup: controller = InstructionsViewController.instantiate()
        case .theme: controller = ThemeViewController.instantiate()
        case .packs: controller = PacksViewController()
        case .height: controller = KeyboardHeightViewController()
        case .customKeyboard: controller = CustomKeyboardEditorViewController()
        case .qwerty: controller = QwertySetupViewController()
        case .snippets: controller = SnippetsViewController()
        case .feedback, .rate, .numberOrder, .roundedCorners, .grid:
            controller = DashboardViewController() // unreachable — handled above
        }
        let navigation = UINavigationController(rootViewController: controller)
        if Self.shouldAnimateTransition(
            reduceMotionEnabled: UIAccessibility.isReduceMotionEnabled
        ) {
            showDetailViewController(navigation, sender: nil)
        } else {
            setViewController(navigation, for: .secondary)
        }
    }
}

final class SettingsSidebarController: TableViewController {
    private let sections: [HomeSection]
    private let onSelect: (SettingsDestination) -> Void

    init(sections: [HomeSection], onSelect: @escaping (SettingsDestination) -> Void) {
        self.sections = sections
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = NSLocalizedString("NumPad", comment: "iPad sidebar title")
        tableView.estimatedRowHeight = 56
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let destination = sections[indexPath.section].rows[indexPath.row]
        switch destination {
        case .numberOrder:
            return switchCell(
                title: NSLocalizedString("7-8-9 on Top", comment: ""),
                isOn: Keyboard.isReversedMode
            ) { isOn in
                Keyboard.isReversedMode = isOn
                SettingsSync.post()
            }
        case .roundedCorners:
            return switchCell(title: .rounded, isOn: Keyboard.hasRoundedCorners) { isOn in
                Keyboard.hasRoundedCorners = isOn
                SettingsSync.post()
            }
        case .grid:
            return switchCell(title: .grid, isOn: Keyboard.hasGrid) { isOn in
                Keyboard.hasGrid = isOn
                SettingsSync.post()
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Side")
                ?? UITableViewCell(style: .default, reuseIdentifier: "Side")
            cell.textLabel?.text = sidebarTitle(for: destination)
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "sidebar.\(destination)"
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityHint = NSLocalizedString(
                "Opens the selected settings screen.",
                comment: "iPad sidebar navigation accessibility hint"
            )
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let destination = sections[indexPath.section].rows[indexPath.row]
        switch destination {
        case .numberOrder, .roundedCorners, .grid:
            tableView.deselectRow(
                at: indexPath,
                animated: !UIAccessibility.isReduceMotionEnabled
            )
        default:
            onSelect(destination)
        }
    }

    private func switchCell(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SideSwitch") as? SwitchCell
            ?? SwitchCell(style: .default, reuseIdentifier: "SideSwitch")
        cell.textLabel?.text = title
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.selectionStyle = .none
        cell.switchView.isOn = isOn
        cell.switchView.accessibilityLabel = title
        cell.switchView.accessibilityHint = NSLocalizedString(
            "Double tap to change this setting.",
            comment: "iPad sidebar switch accessibility hint"
        )
        cell.valueChanged = { switchView in onChange(switchView.isOn) }
        return cell
    }

    private func sidebarTitle(for destination: SettingsDestination) -> String {
        switch destination {
        case .dashboard: return NSLocalizedString("Dashboard", comment: "")
        case .profiles: return NSLocalizedString("Profiles", comment: "")
        case .keyboardSetup: return NSLocalizedString("Enable Keyboard", comment: "")
        case .theme: return NSLocalizedString("Theme", comment: "")
        case .packs: return NSLocalizedString("Keyboard Packs", comment: "")
        case .height: return NSLocalizedString("Keyboard Height", comment: "")
        case .customKeyboard: return NSLocalizedString("Custom Keyboard", comment: "")
        case .qwerty: return NSLocalizedString("NumPad Type", comment: "")
        case .typingBehavior: return NSLocalizedString("Typing & Behavior", comment: "")
        case .snippets: return NSLocalizedString("Snippets", comment: "")
        case .privacy: return NSLocalizedString("Privacy & Full Access", comment: "")
        case .featureGuide: return NSLocalizedString("Features & Guide", comment: "")
        case .pro: return NSLocalizedString("NumPad Pro", comment: "")
        case .feedback: return NSLocalizedString("Send Feedback", comment: "")
        case .rate: return NSLocalizedString("Rate", comment: "")
        case .kioskProvisioning: return NSLocalizedString("Kiosk Provisioning", comment: "")
        case .numberOrder: return NSLocalizedString("7-8-9 on Top", comment: "")
        case .roundedCorners: return NSLocalizedString("Rounded", comment: "")
        case .grid: return NSLocalizedString("Grid", comment: "")
        }
    }
}

enum IPadPresentationLocalization {
    static let requiredKeys = [
        "NumPad",
        "Dashboard",
        "Profiles",
        "Keyboard",
        "Typing & Behavior",
        "Content & Automation",
        "Account",
        "Help",
        "Enable Keyboard",
        "Theme",
        "Keyboard Packs",
        "Keyboard Height",
        "Custom Keyboard",
        "NumPad Type",
        "Snippets",
        "Privacy & Full Access",
        "Features & Guide",
        "NumPad Pro",
        "Send Feedback",
        "Rate",
        "Kiosk Provisioning",
        "7-8-9 on Top",
        "Rounded",
        "Grid",
        "Opens the selected settings screen.",
        "Double tap to change this setting.",
        "Try the NumPad keyboard here",
        "Try the NumPad keyboard",
        "Type here to confirm the NumPad keyboard works with this profile.",
        "Status",
        "Preview",
        "Keyboard preview",
        "Preview of the active keyboard theme and layout.",
        "Kiosk Readiness",
        "Keyboard Status",
        "On",
        "Enabled",
        "Off — enable NumPad in Settings → Keyboards",
        "Full Access",
        "Full Access is configured in Settings → Keyboards → NumPad. The app cannot read that switch reliably; clipboard, haptics, and key sounds need it. MDM cannot grant Full Access.",
        "Active Profile",
        "None",
        "Entitlement Fallbacks",
        "Opens profile management.",
        "Opens kiosk provisioning settings.",
        "Ready",
        "Needs Attention",
        "Blocked",
        "Active profile is not Kiosk",
        "Active Kiosk policy or configuration is invalid",
        "Keyboard is not enabled",
        "Active profile cannot apply",
        "Full Access not confirmed",
        "Entitlement fallback in effect",
        "Try It field not confirmed on this device",
        "Guided Access software keyboards not acknowledged",
        "Kiosk height is unavailable; using Tall",
        "%@ is locked; using Default",
        "Custom Keyboard is locked; using the profile’s standard layout",
        "QWERTY is locked; using the numpad page",
        "%@ is locked; using White"
    ]
}
