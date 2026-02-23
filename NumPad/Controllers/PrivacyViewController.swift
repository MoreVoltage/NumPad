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
        navigationItem.title = "Privacy & Full Access"
    }
}

extension PrivacyViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        cell.selectionStyle = .none
        switch Row(rawValue: indexPath.row)! {
        case .summary:
            cell.imageView?.image = UIImage(named: "darkmode")
            cell.textLabel?.text = "We do not log keystrokes"
            cell.detailTextLabel?.text = "NumPad never stores what you type."
        case .data:
            cell.imageView?.image = UIImage(named: "grid")
            cell.textLabel?.text = "What Full Access enables"
            cell.detailTextLabel?.text = "Haptics, key click sound, analytics, and optional cloud features."
        case .access:
            cell.imageView?.image = UIImage(named: "switch")
            cell.textLabel?.text = "Why iOS shows a warning"
            cell.detailTextLabel?.text = "iOS shows a generic message for all third‑party keyboards."
        case .links:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = "Privacy Policy and Support"
            cell.detailTextLabel?.text = "Open our policy and contact support in Safari."
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Row(rawValue: indexPath.row) == .links else { return }
        if let policy = URL(string: "https://morevoltage.com/numpad/privacy"), let support = URL(string: "https://morevoltage.com/numpad/support") {
            let alert = UIAlertController(title: "Open Link", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Privacy Policy", style: .default, handler: { _ in UIApplication.shared.open(policy) }))
            alert.addAction(UIAlertAction(title: "Support", style: .default, handler: { _ in UIApplication.shared.open(support) }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
}


