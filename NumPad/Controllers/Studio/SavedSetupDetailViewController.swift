//
//  SavedSetupDetailViewController.swift
//  NumPad
//

import UIKit

final class SavedSetupDetailViewController: StudioScreenViewController {
    private let profile: KeyboardProfile
    private let applier: KeyboardProfileApplier
    private let mutationAuthorizer: KioskMutationAuthorizer
    private let isEditingLocked: () -> Bool
    private let isProEntitled: () -> Bool

    init(
        profile: KeyboardProfile,
        applier: KeyboardProfileApplier = KeyboardProfileApplier(defaults: .group),
        mutationAuthorizer: KioskMutationAuthorizer = KioskMutationAuthorizer(),
        isEditingLocked: @escaping () -> Bool = { ManagedProfileCoordinator.isEditingLocked() },
        isProEntitled: @escaping () -> Bool = { Monetization.isProEntitled }
    ) {
        self.profile = profile
        self.applier = applier
        self.mutationAuthorizer = mutationAuthorizer
        self.isEditingLocked = isEditingLocked
        self.isProEntitled = isProEntitled
        super.init(palette: .advanced)
    }

    required init?(coder: NSCoder) { fatalError("Saved setup detail is programmatic only") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = StudioSavedSetupPresentation.item(for: profile).name
        view.accessibilityIdentifier = "studio.saved-setup.detail"
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); rebuild() }

    private func rebuild() {
        removeContent()
        do {
            let summary = try StudioSavedSetupPresentation.projectedSummary(for: profile, idiom: traitCollection.userInterfaceIdiom, applier: applier)
            let preview = StudioKeyboardPreviewView(model: summary.preview, palette: palette)
            preview.setCaption(leading: NSLocalizedString("Setup preview", comment: "Saved setup read-only preview"), trailing: nil)
            preview.accessibilityIdentifier = "studio.saved-setup.preview"
            contentStack.addArrangedSubview(preview)
            let changeRows = summary.changes.map { change in
                StudioRowView(title: NSLocalizedString(change.label, comment: "Saved setup change label"), subtitle: NSLocalizedString(change.value, comment: "Saved setup projected value"), symbolName: "checkmark.circle", accessory: .none, palette: palette)
            }
            addSection(title: NSLocalizedString("CHANGES WHEN APPLIED", comment: "Saved setup changes section"), rows: changeRows)
            if !summary.fallbacks.isEmpty {
                let notes = summary.fallbacks.map(\.localizedDescription).joined(separator: " ")
                addSection(title: NSLocalizedString("AVAILABLE ON THIS DEVICE", comment: "Saved setup fallback section"), rows: [StudioRowView(title: NSLocalizedString("Some choices will use available options", comment: "Saved setup fallback title"), subtitle: notes, symbolName: "info.circle", accessory: .none, palette: palette)])
            }
        } catch {
            addSection(title: NSLocalizedString("SETUP", comment: "Saved setup error section"), rows: [StudioRowView(title: NSLocalizedString("This setup is unavailable", comment: "Saved setup error title"), subtitle: NSLocalizedString("It could not be prepared without changing your keyboard.", comment: "Saved setup error detail"), symbolName: "exclamationmark.triangle", accessory: .none, palette: palette)])
        }
        let apply = StudioButton(title: isEditingLocked() ? NSLocalizedString("Editing is managed", comment: "Managed saved setup button") : NSLocalizedString("Apply this setup", comment: "Apply saved setup button"), style: .primary, symbolName: "checkmark", palette: palette)
        apply.accessibilityIdentifier = "studio.saved-setup.apply"
        apply.isEnabled = !isEditingLocked()
        apply.hint = NSLocalizedString("Applies the shown choices to your keyboard.", comment: "Apply saved setup accessibility hint")
        apply.onTap = { [weak self] in self?.apply() }
        contentStack.addArrangedSubview(apply)
        let copy = StudioButton(title: NSLocalizedString("Save a copy", comment: "Copy saved setup button"), style: .secondary, symbolName: "plus", palette: palette)
        copy.accessibilityIdentifier = "studio.saved-setup.copy"
        copy.isEnabled = !isEditingLocked()
        copy.onTap = { [weak self] in self?.copy() }
        contentStack.addArrangedSubview(copy)
    }

    private func apply() {
        guard !isEditingLocked() else { return }
        guard KioskModeAccess.allows(profile, proEntitled: isProEntitled()) else {
            let store = StoreViewController()
            store.source = "studio_saved_setup_kiosk"
            show(store, sender: self)
            return
        }
        authorizeMutation { [weak self] in
            guard let self else { return }
            do {
                _ = try applier.apply(profile, entitlements: .live())
                Analytics.logEvent(name: "saved_setup_applied", attributes: ["source": "studio", "kind": profile.kind.rawValue])
                navigationController?.popViewController(animated: true)
            } catch { presentError(error) }
        }
    }

    private func copy() {
        guard !isEditingLocked() else { return }
        guard KioskModeAccess.allows(profile, proEntitled: isProEntitled()) else {
            let store = StoreViewController()
            store.source = "studio_saved_setup_kiosk_copy"
            show(store, sender: self)
            return
        }
        authorizeMutation { [weak self] in
            guard let self else { return }
            do {
                let store = KeyboardProfileStore(defaults: .group)
                var snapshot = store.load()
                snapshot.profiles.append(ProfileDuplicationPolicy.makeCopy(of: profile))
                try store.save(snapshot)
                Analytics.logEvent(name: "saved_setup_copied", attributes: ["source": "studio", "kind": profile.kind.rawValue])
            } catch { presentError(error) }
        }
    }

    private func authorizeMutation(_ mutation: @escaping () -> Void) {
        mutationAuthorizer.performIfAuthorized(mutation) { [weak self] result in
            guard result == .denied else { return }
            self?.presentAuthenticationFailure()
        }
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("Couldn’t apply setup", comment: "Saved setup apply error title"), message: (error as? LocalizedError)?.errorDescription ?? String(describing: error), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func presentAuthenticationFailure() {
        let alert = UIAlertController(
            title: NSLocalizedString("Authentication Failed", comment: "Kiosk mutation authentication failed title"),
            message: NSLocalizedString("Authenticate to change saved setups.", comment: "Kiosk mutation authentication failed message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
