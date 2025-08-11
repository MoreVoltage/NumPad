import UIKit

protocol ClipboardHistoryViewDelegate: AnyObject {
    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String)
    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView)
}

class ClipboardHistoryView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: ClipboardHistoryViewDelegate?
    private let tableView = UITableView()
    private let clearAllButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let countLabel = UILabel()
    private var items: [String] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .red // Set background to red for debugging
        layer.cornerRadius = 12
        clipsToBounds = true
        
        countLabel.font = UIFont.boldSystemFont(ofSize: 16)
        countLabel.textAlignment = .center
        countLabel.backgroundColor = .yellow // Make label visible
        addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        clearAllButton.setTitle("Clear All", for: .normal)
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        addSubview(clearAllButton)
        clearAllButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 30),
            clearAllButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            clearAllButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
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
        countLabel.text = "Clipboard Items: \(items.count)" // Show count for debugging
        tableView.reloadData()
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
        return max(items.count, 1) // Always show at least one row
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if items.isEmpty {
            cell.textLabel?.text = "(No clipboard items)"
            cell.textLabel?.textColor = .gray
        } else {
            cell.textLabel?.text = items[indexPath.row]
            cell.textLabel?.textColor = .black
        }
        cell.textLabel?.numberOfLines = 1
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !items.isEmpty else { return }
        let item = items[indexPath.row]
        delegate?.clipboardHistoryView(self, didSelectItem: item)
    }
    
    // Swipe to delete
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && !items.isEmpty {
            ClipboardHistoryManager.shared.remove(at: indexPath.row)
            reloadData()
        }
    }
}
