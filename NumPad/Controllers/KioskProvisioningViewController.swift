//
//  KioskProvisioningViewController.swift
//  NumPad
//

import UIKit
import LocalAuthentication

final class KioskProvisioningViewController: TableViewController {
    private var isUnlocked: Bool { KioskModeAccess.allows(kind: .kiosk, proEntitled: Monetization.isProEntitled) }
    private let tryItField = UITextField()
    private var report = KioskReadiness.evaluate(.init(
        keyboardEnabled: false,
        activeProfileIsKiosk: false,
        kioskConfigurationIsValid: false,
        fullAccessConfirmed: false,
        profileApplies: false,
        usedEntitlementFallback: false,
        tryItConfirmed: false,
        guidedAccessAcknowledged: false
    ))
    private var activeProfileName = NSLocalizedString("None", comment: "")
    private var fallbackDescriptions: [String] = []
    private var policyDescription = NSLocalizedString(
        "Apply a valid Kiosk setup to configure session reset.",
        comment: "Kiosk policy unavailable description"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Kiosk mode", comment: "Kiosk mode screen title")
        view.accessibilityIdentifier = "studio.kiosk-mode"
        tryItField.placeholder = NSLocalizedString("Type here to confirm Try It", comment: "Kiosk Try It field")
        tryItField.borderStyle = .roundedRect
        tryItField.accessibilityIdentifier = "kiosk.tryIt"
        tryItField.addTarget(self, action: #selector(tryItChanged), for: .editingChanged)
        refresh()
    }

    private func refresh() {
        guard isUnlocked else {
            tableView.reloadData()
            return
        }
        let store = KeyboardProfileStore(defaults: .group)
        let active = store.activeProfile()
        activeProfileName = active?.name ?? NSLocalizedString("None", comment: "")
        let activeProfileIsKiosk = active?.kind == .kiosk
        let kioskConfiguration = KioskSessionPolicy.activeConfiguration(defaults: .group)
        let kioskConfigurationIsValid = activeProfileIsKiosk
            && kioskConfiguration?.activeProfileID == active?.id
        var profileApplies = false
        var usedFallback = false
        fallbackDescriptions = []
        if let active {
            do {
                let result = try KeyboardProfileApplier(defaults: .group)
                    .probe(active, entitlements: .live())
                profileApplies = true
                usedFallback = !result.fallbacks.isEmpty
                    || (active.configuration.heightRaw == KeyboardHeightPreset.kiosk.rawValue
                        && !Monetization.isKioskHeightEntitled)
                fallbackDescriptions = result.fallbacks.map(\.localizedDescription)
            } catch {
                profileApplies = false
            }
        }
        policyDescription = kioskConfiguration.map(Self.policyDescription)
            ?? NSLocalizedString(
                "Apply a valid Kiosk setup to configure session reset.",
                comment: "Kiosk policy unavailable description"
            )
        report = KioskReadiness.evaluate(.init(
            keyboardEnabled: Keyboard.isKeyboardEnabled,
            activeProfileIsKiosk: activeProfileIsKiosk,
            kioskConfigurationIsValid: kioskConfigurationIsValid,
            // Honest: OS Full Access cannot be read reliably from the container app.
            // This flag is an operator acknowledgment, not proof of the system switch.
            fullAccessConfirmed: UserDefaults.group.bool(forKey: "kioskFullAccessConfirmed"),
            profileApplies: profileApplies,
            usedEntitlementFallback: usedFallback,
            tryItConfirmed: UserDefaults.group.bool(forKey: "kioskTryItConfirmed"),
            guidedAccessAcknowledged: UserDefaults.group.bool(forKey: "kioskGuidedAccessAcknowledged")
        ))
        tableView.reloadData()
    }

    private static func policyDescription(_ configuration: KioskSessionConfiguration) -> String {
        let timeout = Int(configuration.policy.inactivityTimeout)
        let timeoutText: String
        if timeout.isMultiple(of: 60) {
            let minutes = timeout / 60
            if minutes == 1 {
                timeoutText = NSLocalizedString(
                    "1 minute",
                    comment: "Kiosk inactivity timeout of one minute"
                )
            } else {
                timeoutText = String(
                    format: NSLocalizedString(
                        "%d minutes",
                        comment: "Kiosk inactivity timeout in whole minutes"
                    ),
                    minutes
                )
            }
        } else {
            timeoutText = String(
                format: NSLocalizedString(
                    "%d seconds",
                    comment: "Kiosk inactivity timeout in seconds"
                ),
                timeout
            )
        }
        let page = configuration.resetPage == "qwerty"
            ? NSLocalizedString("QWERTY", comment: "Kiosk reset page")
            : NSLocalizedString("Numpad", comment: "Kiosk reset page")
        var actions: [String] = []
        if configuration.policy.resetPageAndPack {
            actions.append(String(
                format: NSLocalizedString(
                    "return to %@ · %@",
                    comment: "Kiosk reset page and pack action"
                ),
                page,
                configuration.resetPack.name
            ))
        }
        if configuration.policy.dismissOverlays {
            actions.append(NSLocalizedString("dismiss overlays", comment: "Kiosk reset action"))
        }
        if configuration.policy.clearResultTape {
            actions.append(NSLocalizedString("clear results", comment: "Kiosk reset action"))
        }
        if configuration.policy.clearClipboardHistory {
            actions.append(NSLocalizedString("clear clipboard history", comment: "Kiosk reset action"))
        }
        if actions.isEmpty {
            actions.append(NSLocalizedString(
                "no automatic reset actions",
                comment: "Kiosk policy with no inactivity actions"
            ))
        }
        let inactivitySummary = String(
            format: NSLocalizedString(
                "After %@ of inactivity: %@.",
                comment: "Kiosk policy summary"
            ),
            timeoutText,
            actions.joined(separator: "; ")
        )
        guard configuration.policy.requireAdministratorAuthentication else {
            return inactivitySummary
        }
        return inactivitySummary + " " + NSLocalizedString(
            "Saved setup changes require device authentication.",
            comment: "Kiosk administrator authentication policy"
        )
    }

    @objc private func tryItChanged() {
        guard isUnlocked else { return }
        guard !(tryItField.text ?? "").isEmpty else { return }
        UserDefaults.group.set(true, forKey: "kioskTryItConfirmed")
        refresh()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { isUnlocked ? 2 : 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isUnlocked ? (section == 0 ? 8 : 1) : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard isUnlocked else { return NSLocalizedString("KIOSK MODE", comment: "Kiosk locked section") }
        return section == 0
            ? NSLocalizedString("Readiness", comment: "")
            : NSLocalizedString("Try It", comment: "")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard isUnlocked else { return NSLocalizedString("Kiosk mode is included with NumPad Pro.", comment: "Kiosk mode Pro explanation") }
        guard section == 0 else { return nil }
        return NSLocalizedString(
            "Guided Access or Single App Mode must allow Software Keyboards. Device controls cannot enable a third-party keyboard or grant Full Access. Device authentication helps protect changes, but is not a cryptographic lock.",
            comment: "Kiosk honest limitations footer"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard isUnlocked else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "KioskLocked") ?? Cell(style: .subtitle, reuseIdentifier: "KioskLocked")
            cell.textLabel?.text = NSLocalizedString("Unlock Kiosk mode", comment: "Kiosk locked title")
            cell.detailTextLabel?.text = NSLocalizedString("Prepare a shared-use keyboard with NumPad Pro", comment: "Kiosk locked detail")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.accessibilityIdentifier = "kiosk.unlock"
            return cell
        }
        if indexPath.section == 1 {
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

        let cell = tableView.dequeueReusableCell(withIdentifier: "Kiosk")
            ?? Cell(style: .subtitle, reuseIdentifier: "Kiosk")
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        cell.accessibilityIdentifier = nil
        cell.detailTextLabel?.numberOfLines = 0
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("Readiness", comment: "")
            let reasons = report.reasons.isEmpty ? "" : " — " + report.reasons.joined(separator: "; ")
            let fallbackText = fallbackDescriptions.isEmpty
                ? ""
                : " — " + fallbackDescriptions.joined(separator: "; ")
            cell.detailTextLabel?.text = report.status.localizedTitle + reasons + fallbackText
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessibilityIdentifier = "kiosk.readiness"
        case 1:
            cell.textLabel?.text = NSLocalizedString("Active saved setup", comment: "")
            cell.detailTextLabel?.text = activeProfileName
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 2:
            cell.textLabel?.text = NSLocalizedString("Enable Keyboard", comment: "")
            cell.detailTextLabel?.text = Keyboard.isKeyboardEnabled
                ? NSLocalizedString("On", comment: "")
                : NSLocalizedString("Off — open Settings", comment: "")
        case 3:
            cell.textLabel?.text = NSLocalizedString("Acknowledge Full Access Policy", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(
                "Full Access is set in Settings → Keyboards → NumPad. This tap records acknowledgment only — the app cannot verify the OS switch. Device controls cannot grant Full Access.",
                comment: "Honest Full Access ack"
            )
        case 4:
            cell.textLabel?.text = NSLocalizedString("Try It Status", comment: "")
            cell.detailTextLabel?.text = UserDefaults.group.bool(forKey: "kioskTryItConfirmed")
                ? NSLocalizedString("Confirmed by typing below", comment: "")
                : NSLocalizedString("Type in the Try It field below", comment: "")
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 5:
            cell.textLabel?.text = NSLocalizedString("Acknowledge Guided Access", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(
                "Enable Software Keyboards in Guided Access options. Guided Access prevents leaving the host app; it does not configure NumPad by itself.",
                comment: "Guided Access acknowledgment detail"
            )
        case 6:
            cell.textLabel?.text = NSLocalizedString("Unlock setup editing", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Uses device passcode or biometrics", comment: "")
        default:
            cell.textLabel?.text = NSLocalizedString("Session Policy", comment: "")
            cell.detailTextLabel?.text = policyDescription
            cell.accessibilityIdentifier = "kiosk.policy"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard isUnlocked else {
            let store = StoreViewController()
            store.source = "studio_kiosk_mode"
            show(store, sender: self)
            return
        }
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 2:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case 3:
            UserDefaults.group.set(true, forKey: "kioskFullAccessConfirmed")
        case 5:
            UserDefaults.group.set(true, forKey: "kioskGuidedAccessAcknowledged")
        case 6:
            authenticateAdmin()
            return
        default:
            break
        }
        refresh()
    }

    private func authenticateAdmin() {
        let context = LAContext()
        var error: NSError?
        let reason = NSLocalizedString(
            "Authenticate to edit Kiosk mode",
            comment: "LocalAuthentication reason for kiosk editing"
        )
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let alert = UIAlertController(
                title: NSLocalizedString("Authentication Unavailable", comment: ""),
                message: error?.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.show(SavedSetupsStudioViewController(), sender: self)
                }
            }
        }
    }
}
