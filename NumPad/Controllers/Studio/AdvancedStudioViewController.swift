//
//  AdvancedStudioViewController.swift
//  NumPad
//

import UIKit

final class AdvancedStudioViewController: StudioScreenViewController {
    init() { super.init(palette: .advanced); title = NSLocalizedString("Advanced", comment: "Advanced Studio title") }
    required init?(coder: NSCoder) { super.init(coder: coder); title = NSLocalizedString("Advanced", comment: "Advanced Studio title") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "studio.advanced"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "studio.advanced.close"
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); rebuild() }

    private func rebuild() {
        removeContent()
        let setups = row("Saved setups", "Choose, preview, or apply a keyboard setup", "square.stack.3d.up") { [weak self] in self?.navigationController?.pushViewController(SavedSetupsStudioViewController(), animated: true) }
        setups.accessibilityIdentifier = "studio.advanced.saved-setups"
        let kiosk = row("Kiosk mode", "Prepare a shared-use keyboard", "ipad.and.arrow.forward") { [weak self] in self?.openKiosk() }
        kiosk.accessibilityIdentifier = "studio.advanced.kiosk"
        let move = row("Move setups", "Import or export saved setups", "arrow.left.arrow.right") { [weak self] in self?.navigationController?.pushViewController(MoveSetupsViewController(), animated: true) }
        move.accessibilityIdentifier = "studio.advanced.move-setups"
        var rows = [setups, kiosk, move]
        if StudioAdvancedPresentation.showsManagedSettings(hasManagedOwnership: ManagedProfileCoordinator.hasManagedOwnership(defaults: .group)) {
            let managed = row("Managed settings", "Review the keyboard choices provided for this device", "building.2") { [weak self] in self?.navigationController?.pushViewController(SavedSetupsStudioViewController(), animated: true) }
            managed.accessibilityIdentifier = "studio.advanced.managed-settings"
            rows.append(managed)
        }
        addSection(title: NSLocalizedString("ADVANCED", comment: "Advanced Studio section label"), rows: rows)
    }

    private func row(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> StudioRowView {
        studioRow(title: NSLocalizedString(title, comment: "Advanced action"), subtitle: NSLocalizedString(subtitle, comment: "Advanced action description"), symbol: symbol, action: action)
    }

    private func openKiosk() {
        guard Monetization.isProEntitled else { let store = StoreViewController(); store.source = "studio_advanced_kiosk"; show(store, sender: self); return }
        navigationController?.pushViewController(KioskProvisioningViewController(), animated: true)
    }

    @objc private func close() { dismiss(animated: true) }
}
