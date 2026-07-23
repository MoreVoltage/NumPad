import UIKit

/// iPad (and reusable) settings dashboard: keyboard status, active profile + fallbacks,
/// live preview, real Try It field, readiness summary, and profile/kiosk actions.
final class DashboardViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let tryItField = UITextField()
    private var preview: KeyboardPreviewView?
    private var lastFallbacks: [ProfileFallback] = []
    private var readiness = KioskReadiness.evaluate(.init(
        keyboardEnabled: false,
        fullAccessConfirmed: false,
        profileApplies: false,
        usedEntitlementFallback: false,
        tryItConfirmed: false,
        guidedAccessAcknowledged: false
    ))

    private enum Row: Int, CaseIterable {
        case keyboardStatus
        case fullAccess
        case activeProfile
        case fallbacks
        case readiness
        case tryIt
        case profiles
        case kiosk
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Dashboard", comment: "Dashboard screen title")
        view.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tryItField.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Dashboard Try It placeholder")
        tryItField.borderStyle = .roundedRect
        tryItField.accessibilityIdentifier = "dashboard.tryIt"
        tryItField.addTarget(self, action: #selector(tryItChanged), for: .editingChanged)

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
            fullAccessConfirmed: UserDefaults.group.bool(forKey: "kioskFullAccessConfirmed"),
            profileApplies: profileApplies,
            usedEntitlementFallback: usedFallback,
            tryItConfirmed: UserDefaults.group.bool(forKey: "kioskTryItConfirmed"),
            guidedAccessAcknowledged: UserDefaults.group.bool(forKey: "kioskGuidedAccessAcknowledged")
        ))
        tableView.reloadData()
    }

    @objc private func tryItChanged() {
        let text = tryItField.text ?? ""
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
                let view = KeyboardPreviewView(frame: CGRect(x: 0, y: 0, width: 320, height: 160))
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
                preview.theme = KeyboardTheme.selectedOrAutomatic
            }
            return cell
        }

        let row = Row(rawValue: indexPath.row) ?? .keyboardStatus
        if row == .tryIt {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TryIt")
                ?? UITableViewCell(style: .default, reuseIdentifier: "TryIt")
            cell.selectionStyle = .none
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            tryItField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(tryItField)
            NSLayoutConstraint.activate([
                tryItField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                tryItField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                tryItField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                tryItField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                tryItField.heightAnchor.constraint(equalToConstant: 36)
            ])
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "Dash")
            ?? Cell(style: .subtitle, reuseIdentifier: "Dash")
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.detailTextLabel?.numberOfLines = 0
        switch row {
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
                : lastFallbacks.map { String(describing: $0) }.joined(separator: ", ")
            cell.selectionStyle = .none
        case .readiness:
            cell.textLabel?.text = NSLocalizedString("Kiosk Readiness", comment: "")
            let reasons = readiness.reasons.isEmpty ? "" : " — " + readiness.reasons.joined(separator: "; ")
            cell.detailTextLabel?.text = String(describing: readiness.status) + reasons
            cell.selectionStyle = .none
        case .tryIt:
            break
        case .profiles:
            cell.textLabel?.text = NSLocalizedString("Profiles", comment: "")
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "dashboard.profiles"
        case .kiosk:
            cell.textLabel?.text = NSLocalizedString("Kiosk Provisioning", comment: "")
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
