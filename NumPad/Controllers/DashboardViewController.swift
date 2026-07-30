import UIKit

/// iPad (and reusable) settings dashboard: keyboard status, active profile + fallbacks,
/// live preview, real Try It field, readiness summary, and profile/kiosk actions.
final class DashboardViewController: UIViewController {
    static let maximumReadableContentWidth: CGFloat = 760
    static let kioskSummaryIndexPath = IndexPath(row: Row.readiness.rawValue, section: 0)
    static let profilesIndexPath = IndexPath(row: Row.profiles.rawValue, section: 0)
    static let kioskProvisioningIndexPath = IndexPath(row: Row.kiosk.rawValue, section: 0)

    let contentTableView = UITableView(frame: .zero, style: .insetGrouped)
    let tryItTextField = UITextField()
    private var preview: StudioKeyboardPreviewView?
    private var lastFallbacks: [ProfileFallback] = []
    private var readiness = KioskReadiness.evaluate(.init(
        keyboardEnabled: false,
        activeProfileIsKiosk: false,
        kioskConfigurationIsValid: false,
        fullAccessConfirmed: false,
        profileApplies: false,
        usedEntitlementFallback: false,
        tryItConfirmed: false,
        guidedAccessAcknowledged: false
    ))

    private enum Row: Int, CaseIterable {
        case readiness
        case keyboardStatus
        case activeProfile
        case fullAccess
        case fallbacks
        case tryIt
        case profiles
        case kiosk
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Dashboard", comment: "Dashboard screen title")
        view.backgroundColor = .systemGroupedBackground
        contentTableView.dataSource = self
        contentTableView.delegate = self
        contentTableView.rowHeight = UITableView.automaticDimension
        contentTableView.estimatedRowHeight = 72
        contentTableView.accessibilityIdentifier = "dashboard.content"
        contentTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentTableView)
        let fillAvailableWidth = contentTableView.widthAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.widthAnchor
        )
        fillAvailableWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            contentTableView.topAnchor.constraint(equalTo: view.topAnchor),
            contentTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentTableView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            contentTableView.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            contentTableView.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor
            ),
            contentTableView.widthAnchor.constraint(
                lessThanOrEqualToConstant: Self.maximumReadableContentWidth
            ),
            fillAvailableWidth
        ])

        tryItTextField.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Dashboard Try It placeholder")
        tryItTextField.borderStyle = .roundedRect
        tryItTextField.font = .preferredFont(forTextStyle: .body)
        tryItTextField.adjustsFontForContentSizeCategory = true
        tryItTextField.accessibilityIdentifier = "dashboard.tryIt"
        tryItTextField.accessibilityLabel = NSLocalizedString(
            "Try the NumPad keyboard",
            comment: "Dashboard Try It accessibility label"
        )
        tryItTextField.accessibilityHint = NSLocalizedString(
            "Type here to confirm the NumPad keyboard works with this profile.",
            comment: "Dashboard Try It accessibility hint"
        )
        tryItTextField.addTarget(self, action: #selector(tryItChanged), for: .editingChanged)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .keyboardProfileDidChange,
            object: nil
        )
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    @objc private func refresh() {
        let store = KeyboardProfileStore(defaults: .group)
        let active = store.activeProfile()
        let activeProfileIsKiosk = active?.kind == .kiosk
        let kioskConfiguration = KioskSessionPolicy.activeConfiguration(defaults: .group)
        let kioskConfigurationIsValid = activeProfileIsKiosk
            && kioskConfiguration?.activeProfileID == active?.id
        // Factual apply probe: attempt a dry validation+fallback resolution without claiming success
        // unless apply would succeed under current entitlements.
        var profileApplies = false
        var usedFallback = false
        if let active {
            do {
                let result = try KeyboardProfileApplier(defaults: .group)
                    .probe(active, entitlements: .live())
                profileApplies = true
                usedFallback = !result.fallbacks.isEmpty
                lastFallbacks = result.fallbacks
            } catch {
                profileApplies = false
                lastFallbacks = []
            }
        }
        readiness = KioskReadiness.evaluate(.init(
            keyboardEnabled: Keyboard.isKeyboardEnabled,
            activeProfileIsKiosk: activeProfileIsKiosk,
            kioskConfigurationIsValid: kioskConfigurationIsValid,
            fullAccessConfirmed: UserDefaults.group.bool(forKey: "kioskFullAccessConfirmed"),
            profileApplies: profileApplies,
            usedEntitlementFallback: usedFallback,
            tryItConfirmed: UserDefaults.group.bool(forKey: "kioskTryItConfirmed"),
            guidedAccessAcknowledged: UserDefaults.group.bool(forKey: "kioskGuidedAccessAcknowledged")
        ))
        contentTableView.reloadData()
    }

    @objc private func tryItChanged() {
        let text = tryItTextField.text ?? ""
        guard !text.isEmpty else { return }
        // Confirm only on actual text entry (not a row tap).
        UserDefaults.group.set(true, forKey: "kioskTryItConfirmed")
        refresh()
    }
}

extension DashboardViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? Row.allCases.count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0
            ? NSLocalizedString("Status", comment: "Dashboard status section")
            : NSLocalizedString("Preview", comment: "Dashboard preview section")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Preview")
                ?? UITableViewCell(style: .default, reuseIdentifier: "Preview")
            cell.selectionStyle = .none
            if preview == nil {
                let view = StudioKeyboardPreviewView(
                    model: .current(idiom: traitCollection.userInterfaceIdiom)
                )
                view.translatesAutoresizingMaskIntoConstraints = false
                preview = view
            }
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            if let preview {
                cell.contentView.addSubview(preview)
                NSLayoutConstraint.activate([
                    preview.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
                    preview.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
                    preview.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                    preview.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                    preview.heightAnchor.constraint(equalToConstant: 160)
                ])
                preview.model = .current(idiom: traitCollection.userInterfaceIdiom)
            }
            return cell
        }

        let row = Row(rawValue: indexPath.row) ?? .keyboardStatus
        if row == .tryIt {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TryIt")
                ?? UITableViewCell(style: .default, reuseIdentifier: "TryIt")
            cell.selectionStyle = .none
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            tryItTextField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(tryItTextField)
            NSLayoutConstraint.activate([
                tryItTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                tryItTextField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                tryItTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                tryItTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                tryItTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "Dash")
            ?? Cell(style: .subtitle, reuseIdentifier: "Dash")
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.accessibilityTraits = []
        cell.accessibilityIdentifier = nil
        cell.accessibilityHint = nil
        switch row {
        case .readiness:
            cell.textLabel?.text = NSLocalizedString("Kiosk Readiness", comment: "")
            let reasons = readiness.reasons.isEmpty ? "" : " — " + readiness.reasons.joined(separator: "; ")
            cell.detailTextLabel?.text = readiness.status.localizedTitle + reasons
            cell.selectionStyle = .none
            cell.accessibilityIdentifier = "dashboard.kioskReadiness"
        case .keyboardStatus:
            cell.textLabel?.text = NSLocalizedString("Keyboard Status", comment: "")
            cell.detailTextLabel?.text = KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)
                ?? (Keyboard.isKeyboardEnabled
                    ? NSLocalizedString("Enabled", comment: "")
                    : NSLocalizedString("Off — enable NumPad in Settings → Keyboards", comment: ""))
            cell.selectionStyle = .none
        case .fullAccess:
            cell.textLabel?.text = NSLocalizedString("Full Access", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(
                "Full Access is configured in Settings → Keyboards → NumPad. The app cannot read that switch reliably; clipboard, haptics, and key sounds need it. MDM cannot grant Full Access.",
                comment: "Honest Full Access explanation"
            )
            cell.selectionStyle = .none
        case .activeProfile:
            cell.textLabel?.text = NSLocalizedString("Active Profile", comment: "")
            cell.detailTextLabel?.text = KeyboardProfileStore(defaults: .group).activeProfile()?.name
                ?? NSLocalizedString("None", comment: "")
            cell.selectionStyle = .none
        case .fallbacks:
            cell.textLabel?.text = NSLocalizedString("Entitlement Fallbacks", comment: "")
            cell.detailTextLabel?.text = lastFallbacks.isEmpty
                ? NSLocalizedString("None", comment: "")
                : lastFallbacks.map(\.localizedDescription).joined(separator: "\n")
            cell.selectionStyle = .none
        case .tryIt:
            break
        case .profiles:
            cell.textLabel?.text = NSLocalizedString("Profiles", comment: "")
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "dashboard.profiles"
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityHint = NSLocalizedString(
                "Opens profile management.",
                comment: "Dashboard Profiles row accessibility hint"
            )
        case .kiosk:
            cell.textLabel?.text = NSLocalizedString("Kiosk Provisioning", comment: "")
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "dashboard.kioskProvisioning"
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityHint = NSLocalizedString(
                "Opens kiosk provisioning settings.",
                comment: "Dashboard Kiosk row accessibility hint"
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(
            at: indexPath,
            animated: !UIAccessibility.isReduceMotionEnabled
        )
        guard indexPath.section == 0, let row = Row(rawValue: indexPath.row) else { return }
        switch row {
        case .profiles:
            show(ProfilesViewController(), sender: self)
        case .kiosk:
            show(KioskProvisioningViewController(), sender: self)
        default:
            break
        }
    }
}

extension ProfileFallback {
    var localizedDescription: String {
        switch self {
        case .heightKioskToTall:
            return NSLocalizedString(
                "Kiosk height is unavailable; using Tall",
                comment: "Profile fallback description"
            )
        case .packLocked(let raw):
            let pack = KeyboardType(rawValue: raw)?.name ?? raw
            return String(
                format: NSLocalizedString(
                    "%@ is locked; using Default",
                    comment: "Profile fallback description"
                ),
                pack
            )
        case .customKeyboardLocked:
            return NSLocalizedString(
                "Custom Keyboard is locked; using the profile’s standard layout",
                comment: "Profile fallback description"
            )
        case .qwertyPageLocked:
            return NSLocalizedString(
                "QWERTY is locked; using the numpad page",
                comment: "Profile fallback description"
            )
        case .themePremiumToWhite(let raw):
            let theme = KeyboardTheme(rawValue: raw)?.name ?? raw
            return String(
                format: NSLocalizedString(
                    "%@ is locked; using White",
                    comment: "Profile fallback description"
                ),
                theme
            )
        }
    }
}
