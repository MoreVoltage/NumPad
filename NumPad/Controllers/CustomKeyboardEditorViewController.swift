//
//  CustomKeyboardEditorViewController.swift
//  NumPad
//

import UIKit
import SwiftUI

/// Hosts the SwiftUI `CustomKeyboardEditorView` (the structured custom-keyboard editor) as a child
/// hosting controller pushed onto the app's existing UIKit navigation stack. The screen keeps its
/// UIKit nav title.
///
/// The editor writes through `CustomKeyboardEditorModel` to the shared `CustomKeyboardStore` and
/// posts `SettingsSync`, so a live keyboard extension picks up changes immediately — this controller
/// is just the host, and routes the Pro paywall to the Store screen.
final class CustomKeyboardEditorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Custom Keyboard", comment: "Custom keyboard editor navigation title")
        embedEditor()
    }

    private func embedEditor() {
        let root = CustomKeyboardEditorView(onRequestPaywall: { [weak self] in
            let store = StoreViewController()
            store.source = "customize"
            self?.show(store, sender: self)
        })
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
}
