import UIKit
import SwiftUI

/// Drives the customizable-keyboard editor as SwiftUI islands pushed onto the app's existing
/// UIKit navigation stack: **list → grid editor → paywall**. One shared `LayoutEditorModel` is
/// observed by both screens, and the paywall is presented exactly as everywhere else (`show`).
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

    /// Pushes the layouts list and begins the flow.
    func start() {
        let list = LayoutListView(
            model: model,
            onOpenLayout: { [weak self] id in self?.openEditor(id) },
            onRequestPaywall: { [weak self] in self?.presentPaywall() }
        )
        push(UIHostingController(rootView: list))
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
