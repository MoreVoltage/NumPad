//
//  DebugTypingViewController.swift
//  NumPad
//
//  DEBUG-only host screen (`numpad://debug/typing`) for simulator screenshot automation: a single
//  centered text field that becomes first responder on appear, giving `simctl io screenshot` a
//  surface that raises the keyboard extension with no other app chrome in frame.
//

#if DEBUG
import UIKit

final class DebugTypingViewController: UIViewController {
    private let textField = UITextField()

    /// Accessibility identifier for the text field, encoding whether the NumPad keyboard is in the
    /// system Keyboards list (`Keyboard.isKeyboardEnabled`, read from `AppleKeyboards`). Lets a UI
    /// test do a read-only preflight — and skip — without ever opening Settings.app on a shared
    /// simulator. Pure so it's unit-testable.
    static func fieldIdentifier(keyboardEnabled: Bool) -> String {
        "debugTyping.field.numpadEnabled=\(keyboardEnabled ? 1 : 0)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        textField.borderStyle = .roundedRect
        textField.placeholder = "NumPad debug typing surface"
        textField.accessibilityIdentifier = Self.fieldIdentifier(keyboardEnabled: Keyboard.isKeyboardEnabled)
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            textField.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            textField.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }
}
#endif
