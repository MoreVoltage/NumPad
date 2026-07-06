//
//  CustomKeysViewController.swift
//  NumPad
//

import UIKit
import SwiftUI

/// Hosts the SwiftUI `CustomKeysView` (the right-side keys editor) as a child hosting controller
/// pushed onto the app's existing UIKit navigation stack. The screen keeps its UIKit nav title.
///
/// The editor itself writes through to `CustomKeys.slots` and posts `SettingsSync` so a live
/// keyboard extension picks up slot changes immediately — this controller is just the host.
final class CustomKeysViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Custom Keys", comment: "Custom keys screen navigation title")
        embedCustomKeysView()
    }

    private func embedCustomKeysView() {
        // The Custom-pack section is Pro-gated; when locked it routes to the Store via this closure,
        // matching how PacksViewController / the rest of the app push the paywall onto the UIKit
        // stack. `source = "customize"` keys the funnel + the hero copy to the customization surface.
        let root = CustomKeysView(onRequestPaywall: { [weak self] in
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
