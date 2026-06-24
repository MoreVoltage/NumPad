//
//  SnippetEditorViewController.swift
//  NumPad
//
//  Presented (sheet) editor for creating or editing a snippet. Replaces the old
//  inline `SnippetComposerCell` flow with a title field, a body editor, a row of
//  tappable token chips (from `SnippetTokens.all`) that insert at the cursor, and a
//  live preview bound to `Snippet.expand(body)`.
//

import UIKit

/// A modal editor for a single ``Snippet``. New-snippet mode when `editing == nil`;
/// otherwise it is pre-filled for editing. On a valid Save it calls `onSave` with the
/// composed snippet and dismisses; Cancel dismisses without saving.
final class SnippetEditorViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    private let editingSnippet: Snippet?
    private let onSave: (Snippet) -> Void

    // MARK: Subviews

    private let titleField = UITextField()
    private let bodyView = UITextView()
    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private let previewLabel = UILabel()
    private lazy var saveButton = UIBarButtonItem(
        barButtonSystemItem: .save, target: self, action: #selector(saveTapped)
    )

    // MARK: Init

    /// - Parameters:
    ///   - editing: an existing snippet to edit, or `nil` to compose a new one.
    ///   - onSave: called with the composed snippet when the user taps Save (after validation).
    init(editing: Snippet?, onSave: @escaping (Snippet) -> Void) {
        self.editingSnippet = editing
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Presentation helper

    /// Wraps the editor in a navigation controller configured as a page sheet, ready to present.
    func wrappedForPresentation() -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return nav
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureNavigationItem()
        configureTitleField()
        configureBodyView()
        configureChips()
        configurePreview()
        layout()
        refreshPreview()
        updateSaveEnabled()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Focus the title for a new snippet, the body when editing an existing one.
        if editingSnippet == nil {
            titleField.becomeFirstResponder()
        } else {
            bodyView.becomeFirstResponder()
        }
    }

    // MARK: Configuration

    private func configureNavigationItem() {
        navigationItem.title = editingSnippet == nil
            ? NSLocalizedString("New Snippet", comment: "Navigation title when composing a new snippet")
            : NSLocalizedString("Edit Snippet", comment: "Navigation title when editing an existing snippet")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = saveButton
    }

    private func configureTitleField() {
        titleField.placeholder = NSLocalizedString("Title", comment: "Placeholder for the snippet title text field")
        titleField.borderStyle = .roundedRect
        titleField.font = .preferredFont(forTextStyle: .body)
        titleField.returnKeyType = .next
        titleField.delegate = self
        titleField.text = editingSnippet?.title
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
    }

    private func configureBodyView() {
        bodyView.layer.borderWidth = 1
        bodyView.layer.borderColor = UIColor.separator.cgColor
        bodyView.layer.cornerRadius = 6
        bodyView.font = .preferredFont(forTextStyle: .body)
        bodyView.delegate = self
        bodyView.text = editingSnippet?.text ?? ""
        // Disable system "smart" text behaviors so tokens like {date} aren't mangled
        // (matches the old SnippetComposerCell).
        bodyView.keyboardType = .default
        bodyView.autocorrectionType = .no
        bodyView.autocapitalizationType = .sentences
        bodyView.smartDashesType = .no
        bodyView.smartQuotesType = .no
        bodyView.smartInsertDeleteType = .no
    }

    private func configureChips() {
        chipScrollView.showsHorizontalScrollIndicator = false
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .center
        for entry in SnippetTokens.all {
            chipStack.addArrangedSubview(makeChip(for: entry))
        }
    }

    private func makeChip(for entry: (token: String, label: String)) -> UIButton {
        let chip = UIButton(type: .system)
        chip.setTitle(entry.label, for: .normal)
        chip.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        chip.titleLabel?.adjustsFontForContentSizeCategory = true
        chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        chip.backgroundColor = .secondarySystemBackground
        chip.layer.cornerRadius = 14
        chip.layer.borderWidth = 1
        chip.layer.borderColor = UIColor.separator.cgColor
        chip.accessibilityHint = NSLocalizedString(
            "Inserts this token into the snippet body.",
            comment: "Accessibility hint for a token chip in the snippet editor"
        )
        // Carry the token on the button so the shared handler stays allocation-free.
        chip.accessibilityIdentifier = entry.token
        chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return chip
    }

    private func configurePreview() {
        previewLabel.font = .preferredFont(forTextStyle: .body)
        previewLabel.textColor = .secondaryLabel
        previewLabel.numberOfLines = 0
        previewLabel.adjustsFontForContentSizeCategory = true
    }

    private func makeCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    // MARK: Layout

    private func layout() {
        let tokensCaption = makeCaption(NSLocalizedString(
            "Insert a token", comment: "Caption above the token chip row in the snippet editor"))
        let previewCaption = makeCaption(NSLocalizedString(
            "Preview", comment: "Caption above the live preview in the snippet editor"))

        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.addSubview(chipStack)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScrollView.frameLayoutGuide.heightAnchor)
        ])

        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        chipScrollView.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            titleField, bodyView, tokensCaption, chipScrollView, previewCaption, previewLabel
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(4, after: tokensCaption)
        stack.setCustomSpacing(4, after: previewCaption)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            // Let the stack hug the top; the body grows but doesn't stretch the whole screen.
            stack.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: Actions

    @objc private func chipTapped(_ sender: UIButton) {
        guard let token = sender.accessibilityIdentifier else { return }
        insertIntoBody(token)
    }

    /// Inserts `text` into the body at the current selection (replacing it), leaving the cursor
    /// after the inserted text and keeping the body focused. Refreshes the live preview.
    private func insertIntoBody(_ text: String) {
        if !bodyView.isFirstResponder {
            bodyView.becomeFirstResponder()
        }
        let range = bodyView.selectedTextRange ?? bodyView.textRange(
            from: bodyView.endOfDocument, to: bodyView.endOfDocument
        )
        if let range = range {
            bodyView.replace(range, withText: text)
        } else {
            bodyView.insertText(text)
        }
        // `replace(_:withText:)` does not fire the delegate; refresh manually.
        refreshPreview()
        updateSaveEnabled()
    }

    @objc private func titleChanged() {
        updateSaveEnabled()
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyView.text ?? ""
        guard !title.isEmpty, !body.isEmpty else { return }
        onSave(Snippet(title: title, text: body))
        dismiss(animated: true)
    }

    // MARK: Preview + validation

    private func refreshPreview() {
        let body = bodyView.text ?? ""
        let expanded = Snippet.expand(body)
        previewLabel.text = expanded.isEmpty
            ? NSLocalizedString("Your expanded snippet appears here.",
                                comment: "Placeholder shown in the live preview when the snippet body is empty")
            : expanded
        previewLabel.textColor = expanded.isEmpty ? .tertiaryLabel : .secondaryLabel
    }

    private func updateSaveEnabled() {
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyView.text ?? ""
        saveButton.isEnabled = !title.isEmpty && !body.isEmpty
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        bodyView.becomeFirstResponder()
        return false
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        refreshPreview()
        updateSaveEnabled()
    }
}
