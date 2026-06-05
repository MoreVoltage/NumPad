import UIKit

protocol SnippetsListViewDelegate: AnyObject {
    func snippetsListView(_ view: SnippetsListView, didSelectText text: String)
    func snippetsListViewDidRequestClose(_ view: SnippetsListView)
}

class SnippetsListView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: SnippetsListViewDelegate?

    private let tableView = UITableView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private var items: [Snippet] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("Snippets", comment: "Snippets overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .footnote)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.text = NSLocalizedString("No snippets yet. Add snippets in the NumPad app.", comment: "")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundView = emptyLabel
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            // ≥44pt tap target (Apple's HIG minimum) for the tight overlay header.
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        // Keep Close on top so its enlarged tap area wins over the table view in any overlap.
        bringSubviewToFront(closeButton)

        reloadData()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reloadData() {
        items = SnippetsManager.shared.snippets
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        delegate?.snippetsListViewDidRequestClose(self)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].title
        cell.textLabel?.textColor = .label
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        delegate?.snippetsListView(self, didSelectText: items[indexPath.row].text)
    }
}
