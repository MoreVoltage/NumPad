import UIKit

protocol PackPickerViewDelegate: AnyObject {
    func packPickerView(_ view: PackPickerView, didSelect type: KeyboardType)
    func packPickerView(_ view: PackPickerView, didSelectLocked type: KeyboardType)
    func packPickerViewDidRequestClose(_ view: PackPickerView)
}

/// Overlay shown by long-pressing the Next key (when it's repurposed to cycle packs):
/// jump straight to any pack instead of cycling through them one by one.
class PackPickerView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: PackPickerViewDelegate?

    private let tableView = UITableView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let items: [KeyboardType]

    override init(frame: CGRect) {
        // Math and Math2 are the same pack with a toggled row — list it once. An empty Custom
        // pack renders identically to Default, so hide it until the user defines keys.
        items = ([.default] + KeyboardType.packs).filter { type in
            if type == .math2 { return false }
            if type == .custom && CustomPackManager.shared.keys.isEmpty { return false }
            return true
        }
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("Keyboard Packs", comment: "Pack picker overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func closeTapped() {
        delegate?.packPickerViewDidRequestClose(self)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let type = items[indexPath.row]
        cell.textLabel?.text = type.name
        cell.textLabel?.textColor = .label
        // Math2 is the toggled face of the Math pack — show Math as selected for both.
        let selected = KeyboardType.selected == type || (type == .math && KeyboardType.selected == .math2)
        cell.accessoryType = selected ? .checkmark : .none
        if Monetization.isLocked(pack: type) {
            let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
            lock.tintColor = .lightGray
            cell.accessoryView = lock
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        let type = items[indexPath.row]
        if Monetization.isLocked(pack: type) {
            delegate?.packPickerView(self, didSelectLocked: type)
        } else {
            delegate?.packPickerView(self, didSelect: type)
        }
    }
}
