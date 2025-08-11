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
    private var items: [Snippet] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = "Snippets"
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        reloadData()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reloadData() {
        items = SnippetsManager.shared.snippets
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        delegate?.snippetsListViewDidRequestClose(self)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(items.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if items.isEmpty {
            cell.textLabel?.text = "(No snippets yet)"
            cell.textLabel?.textColor = .gray
            cell.selectionStyle = .none
        } else {
            let item = items[indexPath.row]
            cell.textLabel?.text = item.title
            cell.textLabel?.textColor = .label
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !items.isEmpty else { return }
        let item = items[indexPath.row]
        delegate?.snippetsListView(self, didSelectText: item.text)
    }
}


