import UIKit

final class DashboardViewController: TableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Dashboard", comment: "Dashboard screen title")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Dash")
            ?? Cell(style: .subtitle, reuseIdentifier: "Dash")
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("Keyboard Status", comment: "")
            cell.detailTextLabel?.text = KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)
                ?? NSLocalizedString("Off", comment: "")
        case 1:
            cell.textLabel?.text = NSLocalizedString("Active Profile", comment: "")
            cell.detailTextLabel?.text = KeyboardProfileStore(defaults: .group).activeProfile()?.name
        default:
            cell.textLabel?.text = NSLocalizedString("Profiles", comment: "")
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 2 {
            show(ProfilesViewController(), sender: self)
        }
    }
}
