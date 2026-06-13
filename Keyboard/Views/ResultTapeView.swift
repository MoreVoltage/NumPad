import UIKit

protocol ResultTapeViewDelegate: AnyObject {
    func resultTapeView(_ view: ResultTapeView, didSelect result: String)
    func resultTapeViewDidRequestClose(_ view: ResultTapeView)
}

/// Lists recent inline-calculator results (last-result-tape feature) so they can be re-inserted.
/// Tap a row to insert it; "Clear All" empties the tape. Mirrors the SnippetsListView layout.
class ResultTapeView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: ResultTapeViewDelegate?

    private let tableView = UITableView()
    private let closeButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private var items: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("Recent Results", comment: "Result tape overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        clearButton.setTitle(NSLocalizedString("Clear All", comment: ""), for: .normal)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        addSubview(clearButton)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .footnote)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.text = NSLocalizedString("No results yet. Tap = to calculate, then your results appear here.", comment: "")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundView = emptyLabel
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            clearButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            clearButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        bringSubviewToFront(closeButton)
        bringSubviewToFront(clearButton)

        reloadData()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reloadData() {
        items = ResultTape.shared.results
        emptyLabel.isHidden = !items.isEmpty
        clearButton.isHidden = items.isEmpty
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        delegate?.resultTapeViewDidRequestClose(self)
    }

    @objc private func clearTapped() {
        ResultTape.shared.clear()
        reloadData()
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        cell.textLabel?.textColor = .label
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        delegate?.resultTapeView(self, didSelect: items[indexPath.row])
    }
}
