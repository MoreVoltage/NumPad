//
//  CustomKeyboardEditorViewController.swift
//  NumPad
//

import UIKit
import SwiftUI

/// Hosts the SwiftUI `CustomKeyboardEditorView` (the structured custom-keyboard editor) as a child
/// hosting controller pushed onto the app's existing UIKit navigation stack. The screen keeps its
/// UIKit nav title **and** owns the nav-bar handedness button — SwiftUI `.toolbar` content declared
/// on `host`'s root view never reaches this controller's own `navigationItem`, because `host` is a
/// *child* controller (added via `addChild`), not itself pushed onto the navigation stack; `self` is
/// the one that's pushed, so the bar button lives here in UIKit instead.
///
/// This controller owns the single `CustomKeyboardEditorModel` instance for the screen and injects
/// it into the SwiftUI view, so the nav-bar icon (toggled here) and the live preview + toast (read
/// and shown there) always agree — both act on the same shared model.
///
/// The editor writes through `CustomKeyboardEditorModel` to the shared `CustomKeyboardStore` and
/// posts `SettingsSync`, so a live keyboard extension picks up changes immediately — this controller
/// is just the host, and routes the Pro paywall to the Store screen.
final class CustomKeyboardEditorViewController: UIViewController {
    private let model = CustomKeyboardEditorModel()

    private lazy var handednessButton = UIBarButtonItem(
        image: nil, style: .plain, target: self, action: #selector(toggleHandedness))

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Custom Keyboard", comment: "Custom keyboard editor navigation title")
        embedEditor()
        updateHandednessIcon()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Entitlement (and so the button's visibility — handedness is part of the Pro-gated
        // editor) can change on the pushed Store screen; re-check every time this screen reappears,
        // mirroring the SwiftUI view's own `refreshFlags()` on appear/foreground.
        navigationItem.rightBarButtonItem = Monetization.isCustomKeyboardEntitled ? handednessButton : nil
        updateHandednessIcon()
    }

    private func embedEditor() {
        let root = CustomKeyboardEditorView(model: model, onRequestPaywall: { [weak self] in
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

    // MARK: Handedness (nav bar)

    @objc private func toggleHandedness() {
        model.setHandedness(model.handedness == .right ? .left : .right)
        updateHandednessIcon()
    }

    /// Right-hand mode shows a right-pointing hand (columns sit on the right); left-hand mode shows
    /// its distinct mirrored counterpart. Both are dedicated SF Symbols (not one image manually
    /// flipped), so they render correctly regardless of layout direction.
    private func updateHandednessIcon() {
        let isRight = model.handedness == .right
        handednessButton.image = UIImage(systemName: isRight ? "hand.point.right.fill" : "hand.point.left.fill")
        handednessButton.accessibilityLabel = isRight
            ? NSLocalizedString("Right-hand mode", comment: "Accessibility label for the handedness nav bar button when the custom keyboard's columns sit on the right")
            : NSLocalizedString("Left-hand mode", comment: "Accessibility label for the handedness nav bar button when the custom keyboard's columns sit on the left")
        handednessButton.accessibilityHint = NSLocalizedString("Double-tap to switch which side the custom keyboard's columns sit on.", comment: "Accessibility hint for the handedness nav bar button")
    }
}
