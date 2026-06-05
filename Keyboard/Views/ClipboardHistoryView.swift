import UIKit

protocol ClipboardHistoryViewDelegate: AnyObject {
    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String)
    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView)
}

class ClipboardHistoryView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: ClipboardHistoryViewDelegate?

    /// Set by the presenter. When Full Access is off the keyboard cannot read the pasteboard,
    /// so the empty state explains how to fix it rather than looking broken.
    var hasFullAccess: Bool = true {
        didSet { reloadData() }
    }

    private let tableView = UITableView()
    private let clearAllButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let countLabel = UILabel()
    private let emptyLabel = UILabel()
    private var items: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        countLabel.font = UIFont.boldSystemFont(ofSize: 16)
        countLabel.textAlignment = .center
        countLabel.textColor = .label
        countLabel.text = NSLocalizedString("Clipboard History", comment: "Clipboard overlay title")
        addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        clearAllButton.setTitle(NSLocalizedString("Clear All", comment: ""), for: .normal)
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        addSubview(clearAllButton)
        clearAllButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .footnote)
        emptyLabel.adjustsFontForContentSizeCategory = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundView = emptyLabel
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 30),
            // Center the header buttons on the title and give them a ≥44pt tap target
            // (Apple's HIG minimum) so they're easy to hit in the tight overlay header.
            clearAllButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
            clearAllButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            clearAllButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            clearAllButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            tableView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        reloadData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadData() {
        items = ClipboardHistoryManager.shared.history
        emptyLabel.text = emptyMessage
        emptyLabel.isHidden = !items.isEmpty
        clearAllButton.isHidden = items.isEmpty
        tableView.reloadData()
    }

    private var emptyMessage: String {
        if !UserPrefs.clipboardHistoryEnabled {
            return NSLocalizedString("Clipboard history is turned off. Turn it on in the NumPad app.", comment: "")
        }
        if !hasFullAccess {
            return NSLocalizedString("Enable Full Access in Settings to use clipboard history.", comment: "")
        }
        return NSLocalizedString("No clipboard items yet. Copy something, then long-press 0.", comment: "")
    }

    // MARK: - Actions
    @objc private func clearAllTapped() {
        ClipboardHistoryManager.shared.clear()
        reloadData()
    }

    @objc private func closeTapped() {
        delegate?.clipboardHistoryViewDidRequestClose(self)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        cell.textLabel?.textColor = .label
        cell.textLabel?.numberOfLines = 1
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.row) else { return }
        delegate?.clipboardHistoryView(self, didSelectItem: items[indexPath.row])
    }

    // Swipe to delete
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && items.indices.contains(indexPath.row) {
            ClipboardHistoryManager.shared.remove(at: indexPath.row)
            reloadData()
        }
    }
}
