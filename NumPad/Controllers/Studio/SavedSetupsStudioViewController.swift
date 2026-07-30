//
//  SavedSetupsStudioViewController.swift
//  NumPad
//

import UIKit

final class SavedSetupsStudioViewController: StudioScreenViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Saved setups", comment: "Saved setups title")
        view.accessibilityIdentifier = "studio.saved-setups"
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); rebuild() }

    private func rebuild() {
        removeContent()
        let builtIns = StudioSavedSetupPresentation.builtIns(qwertyAvailable: FeatureFlags.isQwertyPageAvailable)
        addSection(title: NSLocalizedString("READY-TO-USE SETUPS", comment: "Built-in saved setups section"), rows: builtIns.map(makeRow))
        let builtInIDs = Set(KeyboardProfileFactory.builtIns().map(\.id))
        let custom = KeyboardProfileStore(defaults: .group).load().profiles.filter { !builtInIDs.contains($0.id) }
        guard !custom.isEmpty else { return }
        addSection(title: NSLocalizedString("YOUR SAVED SETUPS", comment: "Custom saved setups section"), rows: custom.map { makeRow(StudioSavedSetupPresentation.item(for: $0)) })
    }

    private func makeRow(_ item: StudioSavedSetupPresentation.Item) -> StudioRowView {
        let row = studioRow(title: item.name, subtitle: item.detail, symbol: "keyboard", action: { [weak self] in
            self?.navigationController?.pushViewController(SavedSetupDetailViewController(profile: item.profile), animated: true)
        })
        row.accessibilityIdentifier = "studio.saved-setups.\(item.profile.id.uuidString)"
        return row
    }
}
