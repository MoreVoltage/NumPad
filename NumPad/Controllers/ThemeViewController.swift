//
//  ThemeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

/// Theme picker: a grid of circular color swatches with a live keyboard preview underneath.
///
/// The controller stays a `TableViewController` (the storyboard scene instantiates it as a
/// table view controller, and changing the storyboard class is error-prone). The swatch grid
/// lives in the table header, the live preview in the table footer, and the table itself has
/// a single row — the existing Automatic Dark Mode switch.
class ThemeViewController: TableViewController {

    private let items = KeyboardTheme.allCases

    private lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: SwatchCell.diameter, height: SwatchCell.diameter)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SwatchCell.self, forCellWithReuseIdentifier: SwatchCell.reuseIdentifier)
        return collectionView
    }()

    private let previewView = KeyboardPreviewView()
    private let previewLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false

        self.navigationItem.title = .theme

        // Header: swatch grid. Sized properly in viewDidLayoutSubviews once width is known.
        let header = UIView()
        header.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: header.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: header.bottomAnchor)
        ])
        tableView.tableHeaderView = header

        // Footer: "Preview" caption + live keyboard preview.
        let footer = UIView()
        previewLabel.text = NSLocalizedString("Preview", comment: "Caption above the live keyboard preview on the theme screen")
        previewLabel.font = .preferredFont(forTextStyle: .footnote)
        previewLabel.textColor = .secondaryLabel
        footer.addSubview(previewLabel)
        footer.addSubview(previewView)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewLabel.topAnchor.constraint(equalTo: footer.topAnchor, constant: 16),
            previewLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            previewView.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 8),
            previewView.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            previewView.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            previewView.heightAnchor.constraint(equalToConstant: 220)
        ])
        tableView.tableFooterView = footer

        refreshThemeUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderAndFooter()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.collectionViewLayout.invalidateLayout()
            self?.sizeHeaderAndFooter()
        }, completion: nil)
    }

    /// Table header/footer views need explicit frames; size them to fit the grid content
    /// and the fixed-height preview whenever the layout width changes.
    private func sizeHeaderAndFooter() {
        guard let header = tableView.tableHeaderView, let footer = tableView.tableFooterView else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }

        var changed = false

        // Compute the grid height directly from the flow-layout metrics (fixed item size)
        // instead of asking the layout for its content size — avoids a layout feedback loop
        // between the header frame and the collection view's constraints.
        let insets = collectionViewLayout.sectionInset
        let available = width - insets.left - insets.right
        let perRow = max(1, Int((available + collectionViewLayout.minimumInteritemSpacing) / (SwatchCell.diameter + collectionViewLayout.minimumInteritemSpacing)))
        let rowCount = Int(ceil(Double(items.count) / Double(perRow)))
        let gridHeight = insets.top + insets.bottom + CGFloat(rowCount) * SwatchCell.diameter + CGFloat(max(0, rowCount - 1)) * collectionViewLayout.minimumLineSpacing
        if header.frame.size != CGSize(width: width, height: gridHeight) {
            header.frame = CGRect(x: 0, y: 0, width: width, height: gridHeight)
            collectionViewLayout.invalidateLayout()
            changed = true
        }

        // 16 (top gap) + label + 8 + 220 (preview) + 16 (bottom)
        let labelHeight = previewLabel.intrinsicContentSize.height
        let footerHeight = 16 + labelHeight + 8 + 220 + 16
        if footer.frame.size != CGSize(width: width, height: footerHeight) {
            footer.frame = CGRect(x: 0, y: 0, width: width, height: footerHeight)
            changed = true
        }

        if changed {
            // Reassign to force the table to pick up the new header/footer heights.
            tableView.tableHeaderView = header
            tableView.tableFooterView = footer
        }
    }

    /// Reload swatch selection state and re-render the preview with the active theme.
    private func refreshThemeUI() {
        collectionView.alpha = KeyboardTheme.automaticDarkMode ? 0.5 : 1
        collectionView.reloadData()
        previewView.theme = .selectedOrAutomatic
    }

}

// MARK: - Swatch grid
extension ThemeViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SwatchCell.reuseIdentifier, for: indexPath) as! SwatchCell
        let theme = items[indexPath.item]
        cell.configure(theme: theme, isThemeSelected: theme.isSelected && !KeyboardTheme.automaticDarkMode, isLocked: Monetization.isLocked(theme: theme))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !KeyboardTheme.automaticDarkMode else { return }
        let theme = items[indexPath.item]
        if Monetization.isLocked(theme: theme) {
            // Locked theme: nudge to the Store instead of applying
            self.show(StoreViewController(), sender: self)
            return
        }
        KeyboardTheme.selected = theme
        refreshThemeUI()
        SettingsSync.post()
        Analytics.logEvent(name: "keyboard_theme", attributes: [Analytics.ParameterValue: KeyboardTheme.selected.rawValue])
    }

}

// MARK: - UITableViewDataSource (Automatic Dark Mode row)
extension ThemeViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: SwitchCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.imageView?.image = UIImage(named: "darkmode")
        cell.textLabel?.text = .automaticDarkMode
        cell.selectionStyle = .none
        cell.switchView.isOn = KeyboardTheme.automaticDarkMode
        cell.valueChanged = { [weak self] switchView in
            KeyboardTheme.automaticDarkMode = switchView.isOn
            self?.refreshThemeUI()
            Analytics.logEvent(name: "automatic_dark_mode", attributes: [Analytics.ParameterValue: KeyboardTheme.automaticDarkMode])
        }
        return cell
    }

}

// MARK: - Swatch cell

/// Circular theme color swatch with a contrast ring + checkmark when selected and a
/// small lock badge when the theme is premium-locked.
private final class SwatchCell: UICollectionViewCell {
    static let reuseIdentifier = "SwatchCell"
    static let diameter: CGFloat = 52

    private let circleView = UIView()
    private let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark"))
    private let lockBadge = UIImageView(image: UIImage(systemName: "lock.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        circleView.layer.cornerRadius = SwatchCell.diameter / 2
        circleView.layer.borderWidth = 1
        circleView.isUserInteractionEnabled = false
        contentView.addSubview(circleView)
        circleView.translatesAutoresizingMaskIntoConstraints = false

        checkmarkView.contentMode = .center
        checkmarkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        circleView.addSubview(checkmarkView)
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false

        lockBadge.contentMode = .center
        lockBadge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        lockBadge.backgroundColor = .systemBackground
        lockBadge.tintColor = .secondaryLabel
        lockBadge.layer.cornerRadius = 9
        lockBadge.layer.borderWidth = 1
        lockBadge.layer.borderColor = UIColor.separator.cgColor
        lockBadge.clipsToBounds = true
        contentView.addSubview(lockBadge)
        lockBadge.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: SwatchCell.diameter),
            circleView.heightAnchor.constraint(equalToConstant: SwatchCell.diameter),
            checkmarkView.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
            lockBadge.trailingAnchor.constraint(equalTo: circleView.trailingAnchor, constant: 2),
            lockBadge.topAnchor.constraint(equalTo: circleView.topAnchor, constant: -2),
            lockBadge.widthAnchor.constraint(equalToConstant: 18),
            lockBadge.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(theme: KeyboardTheme, isThemeSelected: Bool, isLocked: Bool) {
        circleView.backgroundColor = theme.color
        // Thin border so the white swatch is visible on light backgrounds; a stronger
        // primary-tinted ring marks the selected theme.
        circleView.layer.borderColor = isThemeSelected
            ? UIColor.primary.cgColor
            : UIColor.separator.cgColor
        circleView.layer.borderWidth = isThemeSelected ? 3 : 1

        // Checkmark uses white on dark colors and black on light ones for contrast.
        checkmarkView.isHidden = !isThemeSelected
        checkmarkView.tintColor = theme.isLightSwatch ? .black : .white

        lockBadge.isHidden = !isLocked

        accessibilityLabel = theme.name
        isAccessibilityElement = true
        accessibilityTraits = isThemeSelected ? [.button, .selected] : .button
    }
}

private extension KeyboardTheme {
    /// Light swatch colors need a dark checkmark for contrast.
    var isLightSwatch: Bool {
        switch self {
        case .white, .yellow, .lime, .amber:
            return true
        default:
            return false
        }
    }
}
