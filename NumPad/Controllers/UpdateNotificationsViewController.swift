import UIKit
import UserNotifications

final class UpdateNotificationsViewController: TableViewController {
    private var observer: NSObjectProtocol?
    private var requesting = false

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        title = NSLocalizedString("Update Notifications", comment: "Update notification settings")
        observer = NotificationCenter.default.addObserver(forName: UpdateNotifications.changed,
            object: nil, queue: .main) { [weak self] _ in self?.tableView.reloadData() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UpdateNotifications.shared.refresh()
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        FeatureFlags.experimentalUIVisible ? 3 : 2
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        NSLocalizedString("Occasional alerts about new features and app updates. Your keyboard keeps working with notifications off. You can change this choice at any time.", comment: "Update notification explanation")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        if indexPath.row == 0 {
            cell.textLabel?.text = NSLocalizedString("App updates", comment: "Update notification switch")
            let control = UISwitch()
            control.isOn = UpdateNotifications.isEnabled
            control.isEnabled = !requesting
            control.accessibilityIdentifier = "notifications.updates.enabled"
            control.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)
            cell.accessoryView = control
            cell.selectionStyle = .none
            let service = UpdateNotifications.shared
            if !UpdateNotifications.isEnabled {
                cell.detailTextLabel?.text = NSLocalizedString("Off", comment: "Notifications disabled")
            } else if service.authorization == .denied {
                cell.detailTextLabel?.text = NSLocalizedString("Blocked in iPhone Settings", comment: "Notification permission blocked")
            } else if service.hasConnectionError {
                cell.detailTextLabel?.text = NSLocalizedString("Connection pending. We’ll retry when you open the app.", comment: "Push registration needs retry")
            } else if service.isReady {
                cell.detailTextLabel?.text = NSLocalizedString("On", comment: "Notifications enabled")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("Connecting…", comment: "Push registration in progress")
            }
        } else if indexPath.row == 1 {
            cell.textLabel?.text = NSLocalizedString("Notification settings", comment: "Open system notification settings")
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = NSLocalizedString("Copy notification test code", comment: "Beta push delivery testing")
            cell.detailTextLabel?.text = NSLocalizedString("For testing on this device only", comment: "Beta push delivery testing detail")
            cell.accessibilityIdentifier = "notifications.testCode"
        }
        return cell
    }

    @objc private func changed(_ control: UISwitch) {
        if !control.isOn { UpdateNotifications.shared.disable(); return }
        requesting = true
        tableView.reloadData()
        UpdateNotifications.shared.requestEnable { [weak self] result in
            guard let self else { return }
            self.requesting = false
            self.tableView.reloadData()
            if result == .denied {
                Self.showPermissionHelp(from: self)
            } else if result == .failed {
                let alert = UIAlertController(title: NSLocalizedString("Couldn’t enable notifications", comment: "Notification permission error"),
                    message: NSLocalizedString("Please try again.", comment: "Notification permission retry"), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Dismiss"), style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 1 { Self.openSettings() }
        if indexPath.row == 2, let token = UpdateNotifications.shared.testToken {
            UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: token]],
                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(300)])
            UIAccessibility.post(notification: .announcement,
                argument: NSLocalizedString("Test code copied", comment: "Beta push token copied"))
        }
    }

    static func showPermissionHelp(from presenter: UIViewController) {
        guard presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return }
        let alert = UIAlertController(title: NSLocalizedString("Notifications are off", comment: "Notification permission denied"),
            message: NSLocalizedString("Allow notifications in iPhone Settings, then turn on App updates here.", comment: "Notification permission recovery"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Not now", comment: "Decline permission help"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: "Open notification settings"), style: .default) { _ in openSettings() })
        presenter.present(alert, animated: true)
    }

    private static func openSettings() {
        let path: String
        if #available(iOS 15.4, *) { path = UIApplication.openNotificationSettingsURLString }
        else { path = UIApplication.openSettingsURLString }
        if let url = URL(string: path) { UIApplication.shared.open(url) }
    }
}
