//
//  PrivacyViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class PrivacyViewController: TableViewController {
    private enum Row: Int, CaseIterable { case summary, data, access, links }

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Privacy & Full Access", comment: "Privacy screen title")
    }
}

extension PrivacyViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        cell.selectionStyle = .none
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        switch row {
        case .summary:
            cell.imageView?.image = UIImage(named: "darkmode")
            cell.textLabel?.text = NSLocalizedString("We do not log keystrokes", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("NumPad never records or transmits what you type. Usage analytics are anonymous and never include typed content.", comment: "")
        case .data:
            cell.imageView?.image = UIImage(named: "grid")
            cell.textLabel?.text = NSLocalizedString("What Full Access enables", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Haptics, key click sounds, and on‑device clipboard history. Clipboard history is stored only on this device and is cleared automatically.", comment: "")
        case .access:
            cell.imageView?.image = UIImage(named: "switch")
            cell.textLabel?.text = NSLocalizedString("Why iOS shows a warning", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("iOS shows a generic message for all third‑party keyboards.", comment: "")
        case .links:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = NSLocalizedString("Privacy Policy and Support", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Open our policy and contact support in Safari.", comment: "")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Row(rawValue: indexPath.row) == .links else { return }
        if let policy = URL(string: "https://morevoltage.com/numpad/privacy"), let support = URL(string: "https://morevoltage.com/numpad/support") {
            let alert = UIAlertController(title: NSLocalizedString("Open Link", comment: ""), message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Privacy Policy", comment: ""), style: .default, handler: { _ in UIApplication.shared.open(policy) }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Support", comment: ""), style: .default, handler: { _ in UIApplication.shared.open(support) }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
            present(alert, animated: true)
        }
    }
}


