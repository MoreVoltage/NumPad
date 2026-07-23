//
//  ProfilesViewController.swift
//  NumPad
//

import UIKit

final class ProfilesViewController: TableViewController {
    private enum Section: Int, CaseIterable {
        case active, builtIn, mine
    }

    private let store = KeyboardProfileStore(defaults: .group)
    private var snapshot: ProfileStoreSnapshot = ProfileStoreSnapshot(
        profiles: [], activeProfileID: nil, diagnostic: nil, hadCorruptData: false
    )

    private var builtIns: [KeyboardProfile] {
        snapshot.profiles.filter { $0.kind != .custom }
    }

    private var customs: [KeyboardProfile] {
        snapshot.profiles.filter { $0.kind == .custom }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Profiles", comment: "Profiles screen title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCustomProfile)
        )
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        snapshot = store.load()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .active:
            return NSLocalizedString("Active", comment: "Profiles section for the active profile")
        case .builtIn:
            return NSLocalizedString("Built-in Templates", comment: "Profiles section for built-in templates")
        case .mine:
            return NSLocalizedString("My Profiles", comment: "Profiles section for custom profiles")
        case .none:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .active: return 1
        case .builtIn: return builtIns.count
        case .mine: return max(customs.count, 1)
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell")
            ?? Cell(style: .subtitle, reuseIdentifier: "ProfileCell")
        cell.accessoryType = .disclosureIndicator
        cell.accessoryView = nil
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .default

        switch Section(rawValue: indexPath.section) {
        case .active:
            let active = snapshot.profiles.first { $0.id == snapshot.activeProfileID }
            cell.textLabel?.text = active?.name
                ?? NSLocalizedString("None", comment: "No active profile")
            cell.detailTextLabel?.text = snapshot.diagnostic
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case .builtIn:
            let profile = builtIns[indexPath.row]
            cell.textLabel?.text = profile.name
            cell.accessoryType = profile.id == snapshot.activeProfileID ? .checkmark : .disclosureIndicator
        case .mine:
            if customs.isEmpty {
                cell.textLabel?.text = NSLocalizedString("Duplicate a template to customize", comment: "Empty custom profiles hint")
                cell.accessoryType = .none
                cell.selectionStyle = .none
            } else {
                let profile = customs[indexPath.row]
                cell.textLabel?.text = profile.name
                cell.accessoryType = profile.id == snapshot.activeProfileID ? .checkmark : .disclosureIndicator
            }
        case .none:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .builtIn:
            presentBuiltInActions(builtIns[indexPath.row])
        case .mine:
            guard !customs.isEmpty else { return }
            presentCustomActions(customs[indexPath.row])
        default:
            break
        }
    }

    private func presentBuiltInActions(_ profile: KeyboardProfile) {
        let sheet = UIAlertController(title: profile.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Activate", comment: "Activate profile action"), style: .default) { [weak self] _ in
            self?.activate(profile)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Duplicate", comment: "Duplicate profile action"), style: .default) { [weak self] _ in
            self?.duplicate(profile)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(sheet, animated: true)
    }

    private func presentCustomActions(_ profile: KeyboardProfile) {
        let sheet = UIAlertController(title: profile.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Activate", comment: "Activate profile action"), style: .default) { [weak self] _ in
            self?.activate(profile)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Edit", comment: "Edit profile action"), style: .default) { [weak self] _ in
            self?.edit(profile)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Duplicate", comment: "Duplicate profile action"), style: .default) { [weak self] _ in
            self?.duplicate(profile)
        })
        if profile.id != snapshot.activeProfileID {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete profile action"), style: .destructive) { [weak self] _ in
                self?.delete(profile)
            })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(sheet, animated: true)
    }

    private func activate(_ profile: KeyboardProfile) {
        let entitlements = ProfileEntitlements(
            pro: Monetization.isProEntitled,
            kioskHeight: Monetization.isProEntitled,
            financePack: !Monetization.isLocked(pack: .finance)
        )
        do {
            _ = try KeyboardProfileApplier(defaults: .group).apply(profile, entitlements: entitlements)
            var snap = store.load()
            if !snap.profiles.contains(where: { $0.id == profile.id }) {
                snap.profiles.append(profile)
            }
            snap.activeProfileID = profile.id
            try store.save(snap)
            reload()
            NotificationCenter.default.post(name: .keyboardProfileDidChange, object: profile)
        } catch {
            let alert = UIAlertController(
                title: NSLocalizedString("Couldn’t Apply Profile", comment: "Profile apply failure title"),
                message: String(describing: error),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }

    private func duplicate(_ profile: KeyboardProfile) {
        var copy = profile
        copy.id = UUID()
        copy.kind = .custom
        copy.name = profile.name + " " + NSLocalizedString("Copy", comment: "Duplicated profile name suffix")
        var snap = store.load()
        snap.profiles.append(copy)
        try? store.save(snap)
        reload()
        edit(copy)
    }

    private func delete(_ profile: KeyboardProfile) {
        guard profile.id != snapshot.activeProfileID else { return }
        var snap = store.load()
        snap.profiles.removeAll { $0.id == profile.id }
        try? store.save(snap)
        reload()
    }

    private func edit(_ profile: KeyboardProfile) {
        let editor = ProfileEditorViewController(profile: profile)
        editor.onSave = { [weak self] updated in
            guard let self else { return }
            var snap = self.store.load()
            if let idx = snap.profiles.firstIndex(where: { $0.id == updated.id }) {
                snap.profiles[idx] = updated
            } else {
                snap.profiles.append(updated)
            }
            try? self.store.save(snap)
            self.reload()
        }
        show(editor, sender: self)
    }

    @objc private func addCustomProfile() {
        duplicate(KeyboardProfileFactory.standard())
    }
}

extension Notification.Name {
    static let keyboardProfileDidChange = Notification.Name("keyboardProfileDidChange")
}
