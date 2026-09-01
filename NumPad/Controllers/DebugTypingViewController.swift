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
    // UITextView, not UITextField: custom keyboards often get nil
    // `documentContextBeforeInput` from UITextField, which is what Live Math Preview reads.
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        textView.font = .preferredFont(forTextStyle: .body)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1 / UIScreen.main.scale
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.keyboardDismissMode = .none
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            textView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            textView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }
}
#endif
