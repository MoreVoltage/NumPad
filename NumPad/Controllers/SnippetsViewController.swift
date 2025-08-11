//
//  SnippetsViewController.swift
//  NumPad
//
//  Created by AI Assistant on 2025-08-10.
//

import UIKit

class SnippetsViewController: TableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        interactiveNavigationBarHidden = false
        navigationItem.title = "Snippets"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addSnippet))
    }

    @objc private func addSnippet() {
        let alert = UIAlertController(title: "New Snippet", message: "Enter a title and text", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Title" }
        alert.addTextField { $0.placeholder = "Text" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let text = alert.textFields?.last?.text ?? ""
            guard !title.isEmpty, !text.isEmpty else { return }
            SnippetsManager.shared.add(Snippet(title: title, text: text))
            self.tableView.reloadData()
        }))
        present(alert, animated: true)
    }
}

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
        cell.accessoryType = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            SnippetsManager.shared.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}


