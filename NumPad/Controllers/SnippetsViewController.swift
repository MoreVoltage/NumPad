//
//  SnippetsViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

/// Lists the user's snippets. The "+" button presents ``SnippetEditorViewController`` to compose
/// a new snippet; tapping a row presents the same editor pre-filled to edit that snippet.
class SnippetsViewController: TableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("Snippets", comment: "Snippets screen navigation title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(presentNewSnippet)
        )
    }

    // MARK: - Editor presentation

    @objc private func presentNewSnippet() {
        presentEditor(editing: nil, originalIndex: nil)
    }

    /// Presents the snippet editor. When `originalIndex` is non-nil we are editing the snippet at
    /// that row: on save we remove the original first, then add the edited copy, so an edit never
    /// leaves a duplicate (works whether or not the title changed).
    private func presentEditor(editing snippet: Snippet?, originalIndex: Int?) {
        let editor = SnippetEditorViewController(editing: snippet) { [weak self] edited in
            guard let self = self else { return }
            if let index = originalIndex {
                SnippetsManager.shared.remove(at: index)
            }
            SnippetsManager.shared.add(edited)
            self.tableView.reloadData()
        }
        present(editor.wrappedForPresentation(), animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SnippetsViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SnippetsManager.shared.snippets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let snippet = SnippetsManager.shared.snippets[indexPath.row]
        cell.textLabel?.text = snippet.title
        cell.detailTextLabel?.text = snippet.text
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString(
            "Snippets are reusable text you insert from the keyboard — long-press the . key. Tap a token to drop in a live value.",
            comment: "Snippets screen explainer describing what snippets are and how to use them"
        )
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard SnippetsManager.shared.snippets.isEmpty else { return nil }
        return NSLocalizedString(
            "Tap + to create your first snippet.",
            comment: "Snippets screen footer prompting the user to add a snippet when the list is empty"
        )
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        SnippetsManager.shared.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - UITableViewDelegate
extension SnippetsViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snippets = SnippetsManager.shared.snippets
        guard snippets.indices.contains(indexPath.row) else { return }
        presentEditor(editing: snippets[indexPath.row], originalIndex: indexPath.row)
    }
}
