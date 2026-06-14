import UIKit

protocol ClipboardHistoryViewDelegate: AnyObject {
    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String)
    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView)
}

class ClipboardHistoryView: UIView, UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate {
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
    private var items: [(text: String, isPinned: Bool)] = []

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
        // iPad: rows can be dragged straight into the host app's text fields.
        if UIDevice.current.userInterfaceIdiom == .pad {
            tableView.dragDelegate = self
            tableView.dragInteractionEnabled = true
        }
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
        items = ClipboardHistoryManager.shared.items
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
        let item = items[indexPath.row]
        cell.textLabel?.text = item.text
        cell.textLabel?.textColor = .label
        cell.textLabel?.numberOfLines = 1
        cell.selectionStyle = .none
        // Pinned entries are exempt from the 1-hour expiry; show the pin so users know why
        // an old entry is still around.
        if item.isPinned {
            let pin = UIImageView(image: UIImage(systemName: "pin.fill"))
            pin.tintColor = .secondaryLabel
            cell.accessoryView = pin
            cell.accessibilityValue = NSLocalizedString("Pinned", comment: "VoiceOver value for a pinned clipboard entry")
        } else {
            cell.accessoryView = nil
            cell.accessibilityValue = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.row) else { return }
        delegate?.clipboardHistoryView(self, didSelectItem: items[indexPath.row].text)
    }

    // iPad drag & drop: provide the row's text so it can be dropped into any app.
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard items.indices.contains(indexPath.row) else { return [] }
        return [UIDragItem(itemProvider: NSItemProvider(object: items[indexPath.row].text as NSString))]
    }

    // Swipe left: pin/unpin (keeps the entry past the 1-hour expiry) or delete.
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard items.indices.contains(indexPath.row) else { return nil }
        let isPinned = items[indexPath.row].isPinned
        let pinTitle = isPinned
            ? NSLocalizedString("Unpin", comment: "Swipe action to unpin a clipboard entry")
            : NSLocalizedString("Pin", comment: "Swipe action to pin a clipboard entry")
        let pin = UIContextualAction(style: .normal, title: pinTitle) { [weak self] _, _, done in
            ClipboardHistoryManager.shared.togglePin(at: indexPath.row)
            self?.reloadData()
            done(true)
        }
        pin.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "Swipe action to delete a clipboard entry")) { [weak self] _, _, done in
            ClipboardHistoryManager.shared.remove(at: indexPath.row)
            self?.reloadData()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, pin])
    }
}
