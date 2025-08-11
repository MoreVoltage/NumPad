//
//  SnippetsViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class SnippetsViewController: TableViewController, UITextFieldDelegate, UITextViewDelegate {
    private var isAddingInline: Bool = false
    private var newTitle: String = ""
    private var newText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = "Snippets"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(startInlineAdd))
    }

    @objc private func startInlineAdd() {
        guard !isAddingInline else { return }
        isAddingInline = true
        newTitle = ""
        newText = ""
        tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        tableView.endUpdates()
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SnippetComposerCell else { return }
            cell.titleField.becomeFirstResponder()
        }
    }
}

extension SnippetsViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let base = SnippetsManager.shared.snippets.count
        return isAddingInline ? base + 1 : base
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isAddingInline && indexPath.row == 0 {
            let reuseIdentifier = String(describing: SnippetComposerCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SnippetComposerCell ?? SnippetComposerCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.configure(title: newTitle, text: newText, target: self)
            return cell
        } else {
            let reuseIdentifier = String(describing: Cell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            let index = isAddingInline ? indexPath.row - 1 : indexPath.row
            let snippet = SnippetsManager.shared.snippets[index]
            cell.textLabel?.text = snippet.title
            cell.detailTextLabel?.text = snippet.text
            cell.accessoryType = .none
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let index = isAddingInline ? indexPath.row - 1 : indexPath.row
            guard index >= 0 else { return }
            SnippetsManager.shared.remove(at: index)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - Inline composer cell
private final class SnippetComposerCell: UITableViewCell {
    let titleField = UITextField()
    let textView = UITextView()
    let saveButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        titleField.placeholder = "Title"
        titleField.borderStyle = .roundedRect
        titleField.returnKeyType = .next

        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.cornerRadius = 6
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = false
        textView.text = ""

        // Do not force any system keyboard page; let the user's last third‑party or system keyboard remain active
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        if #available(iOS 11.0, *) {
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
            textView.smartInsertDeleteType = .no
        }

        saveButton.setTitle("Save", for: .normal)
        cancelButton.setTitle("Cancel", for: .normal)

        let buttons = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleField, textView, buttons])
        stack.axis = .vertical
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, text: String, target: SnippetsViewController) {
        titleField.text = title
        textView.text = text
        titleField.delegate = target
        textView.delegate = target
        cancelButton.addTarget(target, action: #selector(SnippetsViewController.cancelInlineAdd), for: .touchUpInside)
        saveButton.addTarget(target, action: #selector(SnippetsViewController.saveInlineAdd), for: .touchUpInside)
    }
}

// MARK: - Inline composer actions & delegates
extension SnippetsViewController {
    @objc fileprivate func cancelInlineAdd() {
        guard isAddingInline else { return }
        isAddingInline = false
        tableView.beginUpdates()
        tableView.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        tableView.endUpdates()
    }

    @objc fileprivate func saveInlineAdd() {
        guard isAddingInline else { return }
        let indexPath = IndexPath(row: 0, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? SnippetComposerCell else { return }
        let title = (cell.titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = cell.textView.text ?? ""
        guard !title.isEmpty, !text.isEmpty else { return }
        SnippetsManager.shared.add(Snippet(title: title, text: text))
        isAddingInline = false
        tableView.reloadData()
    }
}


