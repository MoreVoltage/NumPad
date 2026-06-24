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
        let host = UIHostingController(rootView: CustomKeysView())
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
