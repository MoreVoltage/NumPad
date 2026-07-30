//
//  MoveSetupsViewController.swift
//  NumPad
//

import UIKit
import UniformTypeIdentifiers

final class MoveSetupsViewController: StudioScreenViewController, UIDocumentPickerDelegate {
    private let store = KeyboardProfileStore(defaults: .group)
    private lazy var coordinator = ProfileImportCoordinator(store: store)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Move setups", comment: "Move setups title")
        view.accessibilityIdentifier = "studio.move-setups"
        let importRow = studioRow(title: NSLocalizedString("Import a setup", comment: "Move setup import title"), subtitle: NSLocalizedString("Choose a NumPad setup file to validate before saving", comment: "Move setup import description"), symbol: "square.and.arrow.down") { [weak self] in self?.importSetup() }
        importRow.accessibilityIdentifier = "studio.move-setups.import"
        let exportRow = studioRow(title: NSLocalizedString("Export a setup", comment: "Move setup export title"), subtitle: NSLocalizedString("Choose a saved setup to share or keep", comment: "Move setup export description"), symbol: "square.and.arrow.up") { [weak self] in self?.chooseExport() }
        exportRow.accessibilityIdentifier = "studio.move-setups.export"
        addSection(title: NSLocalizedString("MOVE SAVED SETUPS", comment: "Move setups section"), rows: [importRow, exportRow])
    }

    private func importSetup() {
        guard !ManagedProfileCoordinator.isEditingLocked() else { return }
        let picker = coordinator.makeImportPicker(); picker.delegate = self; present(picker, animated: true)
    }

    private func chooseExport() {
        let profiles = store.load().profiles
        let sheet = UIAlertController(title: NSLocalizedString("Export a setup", comment: "Export choice title"), message: nil, preferredStyle: .actionSheet)
        profiles.forEach { profile in sheet.addAction(UIAlertAction(title: StudioSavedSetupPresentation.item(for: profile).name, style: .default) { [weak self] _ in self?.export(profile) }) }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = sheet.popoverPresentationController { popover.sourceView = view; popover.sourceRect = view.bounds }
        present(sheet, animated: true)
    }

    private func export(_ profile: KeyboardProfile) {
        do {
            let activity = try coordinator.makeExportActivityController(for: profile)
            if let popover = activity.popoverPresentationController { popover.sourceView = view; popover.sourceRect = view.bounds }
            present(activity, animated: true)
            Analytics.logEvent(name: "saved_setup_exported", attributes: ["source": "studio"])
        } catch { presentError(error) }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !ManagedProfileCoordinator.isEditingLocked(), let url = urls.first else { return }
        do {
            let imported = try coordinator.prepareImport(at: url)
            guard KioskModeAccess.allows(imported, proEntitled: Monetization.isProEntitled) else {
                let store = StoreViewController()
                store.source = "studio_move_setups_kiosk_import"
                show(store, sender: self)
                return
            }
            let alert = UIAlertController(title: NSLocalizedString("Save this setup?", comment: "Move setup import confirmation title"), message: StudioSavedSetupPresentation.item(for: imported).name, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: "Save imported setup"), style: .default) { [weak self] _ in
                do { _ = try self?.coordinator.storePreparedProfile(imported); Analytics.logEvent(name: "saved_setup_imported", attributes: ["source": "studio"]) } catch { self?.presentError(error) }
            })
            present(alert, animated: true)
        } catch { presentError(error) }
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("Couldn’t move setup", comment: "Move setup error title"), message: (error as? LocalizedError)?.errorDescription ?? NSLocalizedString("The setup could not be used.", comment: "Move setup generic error"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)); present(alert, animated: true)
    }
}
