//
//  KioskProvisioningViewController.swift
//  NumPad
//

import UIKit
import LocalAuthentication

final class KioskProvisioningViewController: TableViewController {
    private let tryItField = UITextField()
    private var report = KioskReadiness.evaluate(.init(
        keyboardEnabled: false,
        fullAccessConfirmed: false,
        profileApplies: false,
        usedEntitlementFallback: false,
        tryItConfirmed: false,
        guidedAccessAcknowledged: false
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Kiosk Provisioning", comment: "Kiosk provisioning screen title")
        tryItField.placeholder = NSLocalizedString("Type here to confirm Try It", comment: "Kiosk Try It field")
        tryItField.borderStyle = .roundedRect
        tryItField.accessibilityIdentifier = "kiosk.tryIt"
        tryItField.addTarget(self, action: #selector(tryItChanged), for: .editingChanged)
        refresh()
    }

    private func refresh() {
        let store = KeyboardProfileStore(defaults: .group)
        let active = store.activeProfile()
        var profileApplies = false
        var usedFallback = false
        if let active {
            do {
                let result = try KeyboardProfileApplier(defaults: .group)
                    .probe(active, entitlements: .live())
                profileApplies = true
                usedFallback = !result.fallbacks.isEmpty
                    || (active.configuration.heightRaw == KeyboardHeightPreset.kiosk.rawValue
                        && !Monetization.isKioskHeightEntitled)
            } catch {
                profileApplies = false
            }
        }
        report = KioskReadiness.evaluate(.init(
            keyboardEnabled: Keyboard.isKeyboardEnabled,
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

    @objc private func tryItChanged() {
        guard !(tryItField.text ?? "").isEmpty else { return }
        UserDefaults.group.set(true, forKey: "kioskTryItConfirmed")
        refresh()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 6 : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0
            ? NSLocalizedString("Readiness", comment: "")
            : NSLocalizedString("Try It", comment: "")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return NSLocalizedString(
            "Guided Access / Single App Mode must allow Software Keyboards. MDM cannot enable a third-party keyboard or grant Full Access. Administrator authentication is an administrative guard, not cryptographic lock-down.",
            comment: "Kiosk honest limitations footer"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        cell.detailTextLabel?.numberOfLines = 0
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("Readiness", comment: "")
            let reasons = report.reasons.isEmpty ? "" : " — " + report.reasons.joined(separator: "; ")
            cell.detailTextLabel?.text = String(describing: report.status) + reasons
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = NSLocalizedString("Enable Keyboard", comment: "")
            cell.detailTextLabel?.text = Keyboard.isKeyboardEnabled
                ? NSLocalizedString("On", comment: "")
                : NSLocalizedString("Off — open Settings", comment: "")
        case 2:
            cell.textLabel?.text = NSLocalizedString("Acknowledge Full Access Policy", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(
                "Full Access is set in Settings → Keyboards → NumPad. This tap records acknowledgment only — the app cannot verify the OS switch. MDM cannot grant Full Access.",
                comment: "Honest Full Access ack"
            )
        case 3:
            cell.textLabel?.text = NSLocalizedString("Try It Status", comment: "")
            cell.detailTextLabel?.text = UserDefaults.group.bool(forKey: "kioskTryItConfirmed")
                ? NSLocalizedString("Confirmed by typing below", comment: "")
                : NSLocalizedString("Type in the Try It field below", comment: "")
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 4:
            cell.textLabel?.text = NSLocalizedString("Acknowledge Guided Access", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(
                "Enable Software Keyboards in Guided Access options. Guided Access prevents leaving the host app; it does not configure NumPad by itself.",
                comment: "Guided Access acknowledgment detail"
            )
        default:
            cell.textLabel?.text = NSLocalizedString("Unlock Profile Editing", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Uses device passcode or biometrics", comment: "")
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 1:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case 2:
            UserDefaults.group.set(true, forKey: "kioskFullAccessConfirmed")
        case 4:
            UserDefaults.group.set(true, forKey: "kioskGuidedAccessAcknowledged")
        case 5:
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
            "Authenticate to edit kiosk configuration",
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
                    self.show(ProfilesViewController(), sender: self)
                }
            }
        }
    }
}
