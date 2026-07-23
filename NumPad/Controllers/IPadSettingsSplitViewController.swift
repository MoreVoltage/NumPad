import UIKit

final class IPadSettingsSplitViewController: UISplitViewController {
    convenience init() {
        self.init(style: .doubleColumn)
        preferredDisplayMode = .oneBesideSecondary
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
            controller = DashboardViewController()
        }
        showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
    }
}

private final class SettingsSidebarController: TableViewController {
    private let sections: [HomeSection]
    private let onSelect: (SettingsDestination) -> Void

    init(sections: [HomeSection], onSelect: @escaping (SettingsDestination) -> Void) {
        self.sections = sections
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = NSLocalizedString("NumPad", comment: "iPad sidebar title")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Side")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Side")
        let destination = sections[indexPath.section].rows[indexPath.row]
        cell.textLabel?.text = sidebarTitle(for: destination)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(sections[indexPath.section].rows[indexPath.row])
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
