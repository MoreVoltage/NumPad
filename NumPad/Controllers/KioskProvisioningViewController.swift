//
//  KioskProvisioningViewController.swift
//  NumPad
//

import UIKit
import LocalAuthentication

final class KioskProvisioningViewController: TableViewController {
    private var report = KioskReadiness.evaluate(.init(
        keyboardEnabled: Keyboard.isKeyboardEnabled,
        fullAccessConfirmed: false,
        profileApplies: true,
        usedEntitlementFallback: false,
        tryItConfirmed: UserDefaults.group.bool(forKey: "kioskTryItConfirmed"),
        guidedAccessAcknowledged: UserDefaults.group.bool(forKey: "kioskGuidedAccessAcknowledged")
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Kiosk Provisioning", comment: "Kiosk provisioning screen title")
        refresh()
    }

    private func refresh() {
        let active = KeyboardProfileStore(defaults: .group).activeProfile()
        let fallback = active?.configuration.heightRaw == KeyboardHeightPreset.kiosk.rawValue
            && !Monetization.isProEntitled
        report = KioskReadiness.evaluate(.init(
            keyboardEnabled: Keyboard.isKeyboardEnabled,
            fullAccessConfirmed: UserDefaults.group.bool(forKey: "kioskFullAccessConfirmed"),
            profileApplies: true,
            usedEntitlementFallback: fallback,
            tryItConfirmed: UserDefaults.group.bool(forKey: "kioskTryItConfirmed"),
            guidedAccessAcknowledged: UserDefaults.group.bool(forKey: "kioskGuidedAccessAcknowledged")
        ))
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        6
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Kiosk")
            ?? Cell(style: .subtitle, reuseIdentifier: "Kiosk")
        cell.accessoryType = .disclosureIndicator
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("Readiness", comment: "")
            cell.detailTextLabel?.text = String(describing: report.status)
        case 1:
            cell.textLabel?.text = NSLocalizedString("Enable Keyboard", comment: "")
            cell.detailTextLabel?.text = Keyboard.isKeyboardEnabled ? "On" : "Off"
        case 2:
            cell.textLabel?.text = NSLocalizedString("Confirm Full Access", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("MDM cannot grant Full Access", comment: "Kiosk MDM limitation")
        case 3:
            cell.textLabel?.text = NSLocalizedString("Confirm Try It", comment: "")
        case 4:
            cell.textLabel?.text = NSLocalizedString("Acknowledge Guided Access", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Enable Software Keyboards in Guided Access", comment: "")
        default:
            cell.textLabel?.text = NSLocalizedString("Unlock Profile Editing", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Uses device passcode or biometrics", comment: "")
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 1:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case 2:
            UserDefaults.group.set(true, forKey: "kioskFullAccessConfirmed")
        case 3:
            UserDefaults.group.set(true, forKey: "kioskTryItConfirmed")
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
