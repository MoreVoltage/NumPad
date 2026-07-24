//
//  QwertyPersonalDictionaryViewController.swift
//  NumPad
//
//  List / add / delete UI for the on-device personal dictionary. Never logs word text.
//

import UIKit

final class QwertyPersonalDictionaryViewController: TableViewController {
    private var dictionary = QwertyTouchPersonalizationPersistence
        .loadCurrentSnapshot()
        .dictionary
    private var words: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Personal Dictionary", comment: "Personal dictionary screen title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addWord)
        )
        reload()
    }

    private func reload() {
        words = dictionary.counts.keys.sorted()
        tableView.reloadData()
    }

    private func persist() {
        dictionary = QwertyTouchPersonalizationPersistence
            .replaceDictionary(with: dictionary)
            .dictionary
        SettingsSync.post()
        // Analytics: count-only, never the words themselves.
        Analytics.logEvent(
            name: "personal_dictionary_updated",
            attributes: ["count": dictionary.counts.count]
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(words.count, 1)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        NSLocalizedString(
            "Words stay on this device. They are never uploaded, synced, or included in analytics.",
            comment: "Personal dictionary privacy footer"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Word")
            ?? Cell(style: .value1, reuseIdentifier: "Word")
        if words.isEmpty {
            cell.textLabel?.text = NSLocalizedString("No learned words yet", comment: "")
            cell.detailTextLabel?.text = nil
            cell.selectionStyle = .none
        } else {
            let word = words[indexPath.row]
            cell.textLabel?.text = word
            cell.detailTextLabel?.text = "\(dictionary.boost(for: word))"
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard !words.isEmpty else { return nil }
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { [weak self] _, _, done in
            guard let self else { done(false); return }
            let word = self.words[indexPath.row]
            self.dictionary.remove(word)
            self.persist()
            self.reload()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    @objc private func addWord() {
        let alert = UIAlertController(
            title: NSLocalizedString("Add Word", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.placeholder = NSLocalizedString("word", comment: "")
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = alert.textFields?.first?.text ?? ""
            guard self.dictionary.addExplicit(raw) else {
                let fail = UIAlertController(
                    title: NSLocalizedString("Couldn’t Add Word", comment: ""),
                    message: NSLocalizedString("Use letters (2–24 characters).", comment: ""),
                    preferredStyle: .alert
                )
                fail.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                self.present(fail, animated: true)
                return
            }
            self.persist()
            self.reload()
        })
        present(alert, animated: true)
    }
}
