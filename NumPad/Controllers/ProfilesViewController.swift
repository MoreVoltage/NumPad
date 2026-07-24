//
//  ProfilesViewController.swift
//  NumPad
//

import LocalAuthentication
import UIKit

final class ProfilesViewController: TableViewController {
    private enum Section: Int, CaseIterable {
        case active, builtIn, mine
    }

    private let store = KeyboardProfileStore(defaults: .group)
    private lazy var documentCoordinator = ProfileImportCoordinator(store: store)
    private var pendingImportURL: URL?
    private var notificationObservers: [NSObjectProtocol] = []
    private var snapshot: ProfileStoreSnapshot = ProfileStoreSnapshot(
        profiles: [], activeProfileID: nil, diagnostic: nil, hadCorruptData: false
    )
    /// Last apply fallbacks for the active profile (surfaced in the Active section).
    private var lastFallbacks: [ProfileFallback] = []

    private var builtIns: [KeyboardProfile] {
        let ids = Set(KeyboardProfileFactory.builtIns().map(\.id))
        return snapshot.profiles.filter { ids.contains($0.id) }
    }

    private var customs: [KeyboardProfile] {
        let ids = Set(KeyboardProfileFactory.builtIns().map(\.id))
        return snapshot.profiles.filter { !ids.contains($0.id) }
    }

    init(importURL: URL? = nil) {
        pendingImportURL = importURL
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Profiles", comment: "Profiles screen title")
        let add = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCustomProfile)
        )
        add.accessibilityIdentifier = "profiles.add"
        let importItem = UIBarButtonItem(
            title: NSLocalizedString("Import", comment: "Import profile document action"),
            style: .plain,
            target: self,
            action: #selector(importProfile)
        )
        importItem.accessibilityIdentifier = "profiles.import"
        navigationItem.rightBarButtonItems = [add, importItem]
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: ManagedProfileCoordinator.stateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reload() })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reload() })
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        beginImport(at: url)
    }

    private func reload() {
        snapshot = store.load()
        navigationItem.rightBarButtonItems?.forEach {
            $0.isEnabled = !ManagedProfileCoordinator.isEditingLocked()
        }
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
        cell.accessibilityIdentifier = nil

        switch Section(rawValue: indexPath.section) {
        case .active:
            let active = snapshot.profiles.first { $0.id == snapshot.activeProfileID }
            cell.textLabel?.text = active?.name
                ?? NSLocalizedString("None", comment: "No active profile")
            var detail = snapshot.diagnostic ?? ""
            if let managedDiagnostic = UserDefaults.group.string(
                forKey: ManagedProfileCoordinator.diagnosticKey
            ) {
                detail = detail.isEmpty ? managedDiagnostic : detail + " — " + managedDiagnostic
            }
            if !lastFallbacks.isEmpty {
                let note = NSLocalizedString("Some settings fell back due to entitlements", comment: "Profile entitlement fallback note")
                detail = detail.isEmpty ? note : detail + " — " + note
            }
            cell.detailTextLabel?.text = detail.isEmpty ? nil : detail
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessibilityIdentifier = "profile.active"
        case .builtIn:
            let profile = builtIns[indexPath.row]
            cell.textLabel?.text = profile.name
            cell.accessoryType = profile.id == snapshot.activeProfileID ? .checkmark : .disclosureIndicator
            cell.accessibilityIdentifier = "profile.builtin.\(profile.kind.rawValue)"
        case .mine:
            if customs.isEmpty {
                cell.textLabel?.text = NSLocalizedString("Duplicate a template to customize", comment: "Empty custom profiles hint")
                cell.accessoryType = .none
                cell.selectionStyle = .none
                cell.accessibilityIdentifier = "profile.mine.empty"
            } else {
                let profile = customs[indexPath.row]
                cell.textLabel?.text = profile.name
                cell.accessoryType = profile.id == snapshot.activeProfileID ? .checkmark : .disclosureIndicator
                cell.accessibilityIdentifier = "profile.mine.\(profile.id.uuidString)"
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
            presentBuiltInActions(builtIns[indexPath.row], sourceIndexPath: indexPath)
        case .mine:
            guard !customs.isEmpty else { return }
            presentCustomActions(customs[indexPath.row], sourceIndexPath: indexPath)
        default:
            break
        }
    }

    // MARK: - Actions (popover-safe on iPad)

    private func presentBuiltInActions(_ profile: KeyboardProfile, sourceIndexPath: IndexPath) {
        let sheet = UIAlertController(title: profile.name, message: nil, preferredStyle: .actionSheet)
        if !ManagedProfileCoordinator.isEditingLocked() {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Activate", comment: "Activate profile action"), style: .default) { [weak self] _ in
                self?.withMutationAuthorization { self?.activate(profile) }
            })
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Duplicate", comment: "Duplicate profile action"), style: .default) { [weak self] _ in
                self?.withMutationAuthorization { self?.duplicate(profile) }
            })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Export", comment: "Export profile action"), style: .default) { [weak self] _ in
            self?.export(profile, sourceIndexPath: sourceIndexPath)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        configurePopover(sheet, sourceIndexPath: sourceIndexPath)
        present(sheet, animated: true)
    }

    private func presentCustomActions(_ profile: KeyboardProfile, sourceIndexPath: IndexPath) {
        let sheet = UIAlertController(title: profile.name, message: nil, preferredStyle: .actionSheet)
        if !ManagedProfileCoordinator.isEditingLocked() {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Activate", comment: "Activate profile action"), style: .default) { [weak self] _ in
                self?.withMutationAuthorization { self?.activate(profile) }
            })
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Edit", comment: "Edit profile action"), style: .default) { [weak self] _ in
                self?.withMutationAuthorization { self?.edit(profile) }
            })
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Duplicate", comment: "Duplicate profile action"), style: .default) { [weak self] _ in
                self?.withMutationAuthorization { self?.duplicate(profile) }
            })
            if profile.id != snapshot.activeProfileID {
                sheet.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete profile action"), style: .destructive) { [weak self] _ in
                    self?.withMutationAuthorization { self?.confirmDelete(profile, sourceIndexPath: sourceIndexPath) }
                })
            }
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Export", comment: "Export profile action"), style: .default) { [weak self] _ in
            self?.export(profile, sourceIndexPath: sourceIndexPath)
        })
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        configurePopover(sheet, sourceIndexPath: sourceIndexPath)
        present(sheet, animated: true)
    }

    private func configurePopover(_ sheet: UIAlertController, sourceIndexPath: IndexPath) {
        if let pop = sheet.popoverPresentationController {
            if let cell = tableView.cellForRow(at: sourceIndexPath) {
                pop.sourceView = cell
                pop.sourceRect = cell.bounds
            } else {
                pop.sourceView = tableView
                pop.sourceRect = tableView.rectForRow(at: sourceIndexPath)
            }
            pop.permittedArrowDirections = [.up, .down]
        }
    }

    private func activate(_ profile: KeyboardProfile) {
        guard mutationAllowed() else { return }
        do {
            let result = try KeyboardProfileApplier(defaults: .group, store: store)
                .apply(profile, entitlements: .live())
            lastFallbacks = result.fallbacks
            reload()
            NotificationCenter.default.post(name: .keyboardProfileDidChange, object: profile)
        } catch {
            presentError(
                title: NSLocalizedString("Couldn’t Apply Profile", comment: "Profile apply failure title"),
                error: error
            )
        }
    }

    private func duplicate(_ profile: KeyboardProfile) {
        guard mutationAllowed() else { return }
        var copy = profile
        copy.id = UUID()
        copy.kind = .custom
        copy.name = profile.name + " " + NSLocalizedString("Copy", comment: "Duplicated profile name suffix")
        var snap = store.load()
        snap.profiles.append(copy)
        do {
            try store.save(snap)
            reload()
            edit(copy)
        } catch {
            presentError(
                title: NSLocalizedString("Couldn’t Duplicate Profile", comment: "Profile duplicate failure title"),
                error: error
            )
        }
    }

    private func confirmDelete(_ profile: KeyboardProfile, sourceIndexPath: IndexPath) {
        guard profile.id != snapshot.activeProfileID else { return }
        let confirm = UIAlertController(
            title: NSLocalizedString("Delete Profile?", comment: "Confirm profile deletion title"),
            message: String(
                format: NSLocalizedString("Delete “%@”? This cannot be undone.", comment: "Confirm profile deletion message"),
                profile.name
            ),
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        confirm.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { [weak self] _ in
            self?.delete(profile)
        })
        present(confirm, animated: true)
    }

    private func delete(_ profile: KeyboardProfile) {
        guard mutationAllowed() else { return }
        guard profile.id != snapshot.activeProfileID else { return }
        let before = store.load()
        var snap = before
        snap.profiles.removeAll { $0.id == profile.id }
        do {
            try store.save(snap)
            reload()
        } catch {
            // Leave both model and UI unchanged on persistence failure.
            snapshot = before
            tableView.reloadData()
            presentError(
                title: NSLocalizedString("Couldn’t Delete Profile", comment: "Profile delete failure title"),
                error: error
            )
        }
    }

    private func edit(_ profile: KeyboardProfile) {
        guard mutationAllowed() else { return }
        let editor = ProfileEditorViewController(profile: profile)
        editor.onSave = { [weak self] updated in
            guard let self else { return .failure(ProfileApplyError.persistence("Profile screen unavailable")) }
            guard !ManagedProfileCoordinator.isEditingLocked() else {
                return .failure(ProfileApplyError.persistence(NSLocalizedString(
                    "Your organization manages keyboard profiles on this device.",
                    comment: "Managed profile editor save rejection"
                )))
            }
            let previous = self.store.load()
            do {
                if previous.activeProfileID == updated.id {
                    let result = try self.store.replaceAndApply(
                        updated,
                        previous: previous,
                        applier: KeyboardProfileApplier(defaults: .group, store: self.store),
                        entitlements: .live()
                    )
                    self.lastFallbacks = result.fallbacks
                    NotificationCenter.default.post(name: .keyboardProfileDidChange, object: updated)
                } else {
                    var proposed = previous
                    if let idx = proposed.profiles.firstIndex(where: { $0.id == updated.id }) {
                        proposed.profiles[idx] = updated
                    } else {
                        proposed.profiles.append(updated)
                    }
                    try self.store.save(proposed)
                }
                self.reload()
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        show(editor, sender: self)
    }

    @objc private func addCustomProfile() {
        withMutationAuthorization { [weak self] in
            self?.duplicate(KeyboardProfileFactory.standard())
        }
    }

    @objc private func importProfile() {
        withMutationAuthorization { [weak self] in
            guard let self else { return }
            let picker = documentCoordinator.makeImportPicker()
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    private func export(_ profile: KeyboardProfile, sourceIndexPath: IndexPath) {
        do {
            let controller = try documentCoordinator.makeExportActivityController(for: profile)
            if let popover = controller.popoverPresentationController {
                if let cell = tableView.cellForRow(at: sourceIndexPath) {
                    popover.sourceView = cell
                    popover.sourceRect = cell.bounds
                } else {
                    popover.sourceView = tableView
                    popover.sourceRect = tableView.rectForRow(at: sourceIndexPath)
                }
            }
            present(controller, animated: true)
        } catch {
            presentError(
                title: NSLocalizedString("Couldn’t Export Profile", comment: ""),
                error: error
            )
        }
    }

    private func presentError(title: String, error: Error) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? NSLocalizedString(
                "The operation could not be completed.",
                comment: "Generic profile operation failure"
            )
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }

    /// When the active kiosk policy requires admin auth, gate profile mutations behind LA.
    private func withMutationAuthorization(_ action: @escaping () -> Void) {
        guard mutationAllowed() else { return }
        let active = snapshot.profiles.first { $0.id == snapshot.activeProfileID }
        guard active?.kioskPolicy?.requireAdministratorAuthentication == true else {
            action()
            return
        }
        let context = LAContext()
        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            presentError(
                title: NSLocalizedString("Authentication Unavailable", comment: "LA unavailable title"),
                error: error ?? ProfileApplyError.persistence("LocalAuthentication unavailable")
            )
            return
        }
        context.evaluatePolicy(
            policy,
            localizedReason: NSLocalizedString(
                "Authenticate to change keyboard profiles.",
                comment: "LA reason for profile edits under kiosk policy"
            )
        ) { [weak self] success, evalError in
            DispatchQueue.main.async {
                if success {
                    action()
                } else if let evalError {
                    self?.presentError(
                        title: NSLocalizedString("Authentication Failed", comment: "LA failed title"),
                        error: evalError
                    )
                }
            }
        }
    }

    @discardableResult
    private func mutationAllowed() -> Bool {
        guard !ManagedProfileCoordinator.isEditingLocked() else {
            let alert = UIAlertController(
                title: NSLocalizedString("Profiles Managed", comment: "Managed profile lock title"),
                message: NSLocalizedString(
                    "Your organization manages keyboard profiles on this device.",
                    comment: "Managed profile lock explanation"
                ),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            if presentedViewController == nil {
                present(alert, animated: true)
            }
            return false
        }
        return true
    }
}

extension ProfilesViewController: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }
        beginImport(at: url)
    }

    private func beginImport(at url: URL) {
        guard mutationAllowed() else { return }
        do {
            let prepared = try documentCoordinator.prepareImport(at: url)
            presentImportConfirmation(prepared)
        } catch {
            presentError(
                title: NSLocalizedString("Couldn’t Import Profile", comment: ""),
                error: error
            )
        }
    }

    private func presentImportConfirmation(_ prepared: KeyboardProfile) {
        let packName = KeyboardType(rawValue: prepared.configuration.keyboardTypeRaw)?.name
            ?? prepared.configuration.keyboardTypeRaw
        let message = String(
            format: NSLocalizedString(
                "Import “%@” with the %@ pack? It will not be activated automatically.",
                comment: "Validated profile import confirmation summary"
            ),
            prepared.name,
            packName
        )
        let alert = UIAlertController(
            title: NSLocalizedString("Import Profile?", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Import", comment: "Confirm profile import"),
            style: .default
        ) { [weak self] _ in
            guard let self, mutationAllowed() else { return }
            do {
                let imported = try documentCoordinator.storePreparedProfile(prepared)
                reload()
                edit(imported)
            } catch {
                presentError(
                    title: NSLocalizedString("Couldn’t Import Profile", comment: ""),
                    error: error
                )
            }
        })
        present(alert, animated: true)
    }
}

extension Notification.Name {
    static let keyboardProfileDidChange = Notification.Name("keyboardProfileDidChange")
}
