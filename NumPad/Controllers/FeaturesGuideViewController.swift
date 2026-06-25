//
//  FeaturesGuideViewController.swift
//  NumPad
//

import UIKit

/// In-app "Features & Guide" — a static, grouped reference covering setup, packs, overlays and
/// gestures, the customizable keyboard, and Pro. Purely informational (rows have no actions).
final class FeaturesGuideViewController: TableViewController {

    private struct Item { let title: String; let detail: String }
    private struct Section { let header: String; let footer: String?; let items: [Item] }

    private let sections: [Section] = [
        Section(header: NSLocalizedString("Getting Started", comment: "Guide section header"),
                footer: NSLocalizedString("Full Access enables clipboard history, haptics and key sounds. NumPad never logs or transmits what you type.", comment: "Guide section footer"),
                items: [
                    Item(title: NSLocalizedString("Enable the keyboard", comment: "Guide item title"),
                         detail: NSLocalizedString("Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard ▸ NumPad, then turn on Full Access.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Switch to NumPad", comment: "Guide item title"),
                         detail: NSLocalizedString("Tap and hold the 🌐 globe key on any keyboard and choose NumPad.", comment: "Guide item detail")),
                ]),
        Section(header: NSLocalizedString("Packs", comment: "Guide section header"),
                footer: NSLocalizedString("Pick a pack in Keyboard Packs — its extra row appears above the numbers.", comment: "Guide section footer"),
                items: [
                    Item(title: NSLocalizedString("Math", comment: "Guide item title"),
                         detail: NSLocalizedString("Free. One-tap operators for everyday arithmetic.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Symbols & Science", comment: "Guide item title"),
                         detail: NSLocalizedString("Common symbols alongside scientific constants and operators.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Finance", comment: "Guide item title"),
                         detail: NSLocalizedString("Currency symbols and finance keys.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Programmer", comment: "Guide item title"),
                         detail: NSLocalizedString("Bitwise operators and hex and binary prefixes.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Date & Time", comment: "Guide item title"),
                         detail: NSLocalizedString("Insert today's date, the time, and more live values.", comment: "Guide item detail")),
                ]),
        Section(header: NSLocalizedString("Overlays & Gestures", comment: "Guide section header"), footer: nil,
                items: [
                    Item(title: NSLocalizedString("Long-press keys", comment: "Guide item title"),
                         detail: NSLocalizedString("Hold 0 for clipboard history, . for snippets, and % for the tax/tip calculator.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Calculator & result tape", comment: "Guide item title"),
                         detail: NSLocalizedString("Tap = to evaluate the expression you typed; long-press return to reuse a recent result.", comment: "Guide item detail")),
                    Item(title: NSLocalizedString("Move the cursor", comment: "Guide item title"),
                         detail: NSLocalizedString("Drag across the space bar to nudge the caret left or right.", comment: "Guide item detail")),
                ]),
        Section(header: NSLocalizedString("Customizable Keyboard", comment: "Guide section header"), footer: nil,
                items: [
                    Item(title: NSLocalizedString("Design your own keyboard", comment: "Guide item title"),
                         detail: NSLocalizedString("Add a top row and side columns around the number pad, type the keys you want, and choose left- or right-handed. Included with Pro.", comment: "Guide item detail")),
                ]),
        Section(header: NSLocalizedString("NumPad Pro", comment: "Guide section header"),
                footer: NSLocalizedString("One-time purchase — no subscription.", comment: "Guide section footer"),
                items: [
                    Item(title: NSLocalizedString("Everything, forever", comment: "Guide item title"),
                         detail: NSLocalizedString("Unlocks every pack, the customizable keyboard, premium themes, iCloud sync, and all future packs.", comment: "Guide item detail")),
                ]),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Features & Guide", comment: "Features and guide screen navigation title")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "GuideCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let item = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.detail
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
    }
}
