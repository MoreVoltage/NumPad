import UIKit
import SwiftUI

/// Drives the customizable-keyboard editor as SwiftUI islands pushed onto the app's existing
/// UIKit navigation stack: **grid editor → paywall**. The shared `LayoutEditorModel` seeds the
/// one canonical layout on entry, and the paywall is presented exactly as everywhere else (`show`).
///
/// The store's `onChange` posts a `SettingsSync` Darwin notification so a live keyboard extension
/// re-reads the active layout immediately after any edit — the same mechanism `UserPrefs` uses.
final class CustomKeyboardCoordinator {
    private weak var presenter: UIViewController?
    private let model: LayoutEditorModel

    init(presenter: UIViewController) {
        self.presenter = presenter
        self.model = LayoutEditorModel(store: LayoutStore(defaults: .group, onChange: { SettingsSync.post() }))
    }

    /// Seeds (idempotently) the one canonical layout and opens its editor directly, skipping the
    /// multi-layout list. `LayoutListView` is retained in the codebase but no longer surfaced.
    func start() {
        let id = model.ensurePrimaryLayout()
        openEditor(id)
    }

    private func openEditor(_ id: KeyboardLayout.ID) {
        let editor = LayoutGridEditorView(
            model: model,
            layoutID: id,
            onRequestPaywall: { [weak self] in self?.presentPaywall() },
            onSaved: { [weak self] in self?.pop() }
        )
        push(UIHostingController(rootView: editor))
    }

    private func presentPaywall() {
        let storeVC = StoreViewController()
        storeVC.source = "customize"
        push(storeVC)
    }

    private func push(_ viewController: UIViewController) {
        guard let presenter else { return }
        presenter.show(viewController, sender: presenter)
    }

    private func pop() {
        presenter?.navigationController?.popViewController(animated: true)
    }
}
