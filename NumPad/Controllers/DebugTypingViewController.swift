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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        textField.borderStyle = .roundedRect
        textField.placeholder = "NumPad debug typing surface"
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
