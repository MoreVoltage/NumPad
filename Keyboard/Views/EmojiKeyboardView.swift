import UIKit

struct EmojiKeyboardItem: Equatable {
    let catalogIndex: Int
    let sequence: String
    let category: EmojiCategory
    let accessibilityLabel: String
    let variants: [EmojiKeyboardVariant]
}

enum EmojiKeyboardCategory: Equatable {
    case recents
    case catalog(EmojiCategory)
    case filtered(query: String)
}

@MainActor
protocol EmojiKeyboardViewDelegate: AnyObject {
    func emojiKeyboardViewDidRequestTyping(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestSearch(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestNextKeyboard(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestDelete(_ view: EmojiKeyboardView)
    func emojiKeyboardView(_ view: EmojiKeyboardView, didSelect sequence: String)
    func emojiKeyboardView(_ view: EmojiKeyboardView, didCreateGlobe button: UIButton)
}

final class EmojiCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "EmojiCollectionViewCell"

    let sequenceLabel = UILabel()
    private var onVariant: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        sequenceLabel.textAlignment = .center
        sequenceLabel.font = .systemFont(ofSize: 29)
        sequenceLabel.adjustsFontSizeToFitWidth = true
        sequenceLabel.minimumScaleFactor = 0.7
        sequenceLabel.isAccessibilityElement = false
        contentView.addSubview(sequenceLabel)
        layer.cornerRadius = 7
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        sequenceLabel.frame = contentView.bounds.insetBy(dx: 2, dy: 2)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sequenceLabel.text = nil
        accessibilityLabel = nil
        accessibilityHint = nil
        accessibilityCustomActions = nil
        onVariant = nil
    }

    func configure(item: EmojiKeyboardItem, palette: QwertyThemePalette,
                   onVariant: @escaping () -> Void) {
        sequenceLabel.text = item.sequence
        sequenceLabel.textColor = palette.text
        backgroundColor = palette.plainFill
        accessibilityLabel = item.accessibilityLabel
        accessibilityTraits = .button
        self.onVariant = item.variants.isEmpty ? nil : onVariant
        if item.variants.isEmpty {
            accessibilityHint = nil
            accessibilityCustomActions = nil
        } else {
            accessibilityHint = NSLocalizedString(
                "Variants available", comment: "emoji skin-tone variant accessibility hint"
            )
            accessibilityCustomActions = [
                UIAccessibilityCustomAction(
                    name: NSLocalizedString(
                        "Choose skin tone", comment: "emoji variant accessibility action"),
                    target: self,
                    selector: #selector(performVariantAccessibilityAction)
                ),
            ]
        }
    }

    @objc @discardableResult
    func performVariantAccessibilityAction() -> Bool {
        guard let onVariant else { return false }
        onVariant()
        return true
    }
}

/// Native, data-driven emoji browser. Catalog/resource loading is deliberately outside this
/// view: Task 6 injects exact RGI sequences, CLDR labels, recents, and ranked catalog indices.
final class EmojiKeyboardView: UIView {
    private enum Metrics {
        static let toolbarHeight: CGFloat = 44
        static let categoryHeight: CGFloat = 44
        static let headingHeight: CGFloat = 34
        static let gap: CGFloat = 4
        static let inset: CGFloat = 4
    }

    weak var delegate: EmojiKeyboardViewDelegate? {
        didSet {
            guard delegate !== oldValue else { return }
            delegate?.emojiKeyboardView(self, didCreateGlobe: globeButton)
        }
    }

    let typingButton = UIButton(type: .system)
    let searchButton = UIButton(type: .system)
    let globeButton = UIButton(type: .system)
    let backspaceButton = UIButton(type: .system)
    let headingLabel = UILabel()
    let emptyStateLabel = UILabel()
    let collectionView: UICollectionView

    private(set) var selectedCategory: EmojiKeyboardCategory
    private(set) var visibleItems: [EmojiKeyboardItem] = []
    private(set) var categorySelections: [EmojiKeyboardCategory]
    private(set) var modifierChooser: EmojiModifierChooserView?
    private(set) var lastAccessibilityFocusTarget: AnyObject?

    private let items: [EmojiKeyboardItem]
    private let recents: [EmojiKeyboardItem]
    private let toolbar = UIView()
    private let categoryScrollView = UIScrollView()
    private var categoryButtons: [UIButton] = []
    private var backspaceTimer: Timer?
    private var backspaceStartedAt: Date?
    private var receivedBackspaceTouchDown = false

    init(items: [EmojiKeyboardItem], recents: [String]) {
        self.items = items
        let bySequence = Dictionary(uniqueKeysWithValues: items.map { ($0.sequence, $0) })
        var seen = Set<String>()
        self.recents = recents.compactMap { sequence in
            guard seen.insert(sequence).inserted else { return nil }
            return bySequence[sequence]
        }
        categorySelections = (self.recents.isEmpty ? [] : [.recents])
            + EmojiCategory.allCases.map(EmojiKeyboardCategory.catalog)
        selectedCategory = self.recents.isEmpty ? .catalog(.smileys) : .recents

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Metrics.gap
        layout.minimumLineSpacing = Metrics.gap
        layout.sectionInset = UIEdgeInsets(
            top: Metrics.inset, left: Metrics.inset,
            bottom: Metrics.inset, right: Metrics.inset
        )
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)

        setupToolbar()
        setupCategories()
        setupContent()
        applyTheme()
        showCategory(selectedCategory, moveAccessibilityFocus: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { backspaceTimer?.invalidate() }

    override func layoutSubviews() {
        super.layoutSubviews()
        toolbar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Metrics.toolbarHeight)
        let toolbarWidth = bounds.width / 4
        for (index, button) in [typingButton, searchButton, globeButton, backspaceButton].enumerated() {
            button.frame = CGRect(x: CGFloat(index) * toolbarWidth, y: 0,
                                  width: toolbarWidth, height: Metrics.toolbarHeight)
        }

        categoryScrollView.frame = CGRect(x: 0, y: toolbar.frame.maxY,
                                          width: bounds.width, height: Metrics.categoryHeight)
        var categoryX: CGFloat = Metrics.inset
        for button in categoryButtons {
            let width = max(44, min(92, button.intrinsicContentSize.width + 18))
            button.frame = CGRect(x: categoryX, y: 0, width: width, height: Metrics.categoryHeight)
            categoryX += width + Metrics.gap
        }
        categoryScrollView.contentSize = CGSize(width: categoryX, height: Metrics.categoryHeight)

        headingLabel.frame = CGRect(x: 8, y: categoryScrollView.frame.maxY,
                                    width: max(0, bounds.width - 16), height: Metrics.headingHeight)
        let contentFrame = CGRect(x: 0, y: headingLabel.frame.maxY, width: bounds.width,
                                  height: max(0, bounds.height - headingLabel.frame.maxY))
        collectionView.frame = contentFrame
        emptyStateLabel.frame = contentFrame.insetBy(dx: 16, dy: 8)

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let available = max(44, bounds.width - 2 * Metrics.inset)
            let columns = max(1, Int((available + Metrics.gap) / (48 + Metrics.gap)))
            let side = max(44, floor((available - CGFloat(columns - 1) * Metrics.gap) / CGFloat(columns)))
            if layout.itemSize != CGSize(width: side, height: side) {
                layout.itemSize = CGSize(width: side, height: side)
                layout.invalidateLayout()
            }
        }
        modifierChooser?.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        collectionView.reloadData()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopBackspaceRepeat() }
    }

    func categoryButton(for category: EmojiKeyboardCategory) -> UIButton? {
        guard let index = categorySelections.firstIndex(of: category),
              categoryButtons.indices.contains(index) else { return nil }
        return categoryButtons[index]
    }

    func showCategory(_ category: EmojiKeyboardCategory, moveAccessibilityFocus: Bool) {
        selectedCategory = category
        switch category {
        case .recents:
            visibleItems = recents
        case .catalog(let catalogCategory):
            visibleItems = items.filter { $0.category == catalogCategory }
        case .filtered:
            break
        }
        reloadContent(moveAccessibilityFocus: moveAccessibilityFocus)
    }

    func showFiltered(catalogIndices: [Int], query: String, moveAccessibilityFocus: Bool) {
        selectedCategory = .filtered(query: query)
        let byIndex = Dictionary(uniqueKeysWithValues: items.map { ($0.catalogIndex, $0) })
        visibleItems = catalogIndices.compactMap { byIndex[$0] }
        reloadContent(moveAccessibilityFocus: moveAccessibilityFocus)
    }

    func dismissModifierChooser() {
        modifierChooser?.removeFromSuperview()
        modifierChooser = nil
    }

    private func setupToolbar() {
        isAccessibilityElement = false
        addSubview(toolbar)
        typingButton.setTitle(NSLocalizedString("ABC", comment: "return to QWERTY typing"), for: .normal)
        typingButton.accessibilityLabel = NSLocalizedString("Letters", comment: "return to QWERTY typing")
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.accessibilityLabel = NSLocalizedString("Search emoji", comment: "emoji search button")
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.accessibilityLabel = NSLocalizedString("Next keyboard", comment: "next keyboard button")
        backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspaceButton.accessibilityLabel = NSLocalizedString("Delete", comment: "backspace key")

        for button in [typingButton, searchButton, globeButton, backspaceButton] {
            button.accessibilityTraits = .button
            toolbar.addSubview(button)
        }
        typingButton.addTarget(self, action: #selector(requestTyping), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(requestSearch), for: .touchUpInside)
        globeButton.addTarget(self, action: #selector(requestNextKeyboard), for: .touchUpInside)
        backspaceButton.addTarget(self, action: #selector(startBackspaceRepeat), for: .touchDown)
        backspaceButton.addTarget(self, action: #selector(releaseBackspaceInside), for: .touchUpInside)
        backspaceButton.addTarget(self, action: #selector(stopBackspaceRepeat),
                                  for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func setupCategories() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        addSubview(categoryScrollView)
        categoryButtons = categorySelections.enumerated().map { index, category in
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(categoryTitle(category), for: .normal)
            button.accessibilityLabel = categoryTitle(category)
            button.accessibilityTraits = .button
            button.layer.cornerRadius = 7
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryScrollView.addSubview(button)
            return button
        }
    }

    private func setupContent() {
        headingLabel.font = .preferredFont(forTextStyle: .headline)
        headingLabel.adjustsFontForContentSizeCategory = true
        headingLabel.accessibilityTraits = .header
        addSubview(headingLabel)

        emptyStateLabel.text = NSLocalizedString("No emoji found", comment: "empty emoji search result")
        emptyStateLabel.accessibilityLabel = emptyStateLabel.text
        emptyStateLabel.isAccessibilityElement = true
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        addSubview(emptyStateLabel)

        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCollectionViewCell.self,
                                forCellWithReuseIdentifier: EmojiCollectionViewCell.reuseIdentifier)
        addSubview(collectionView)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressedEmoji(_:)))
        collectionView.addGestureRecognizer(longPress)
        updateAccessibilityOrder()
    }

    private func reloadContent(moveAccessibilityFocus: Bool) {
        dismissModifierChooser()
        headingLabel.text = headingText(selectedCategory)
        headingLabel.accessibilityLabel = headingLabel.text
        emptyStateLabel.isHidden = !visibleItems.isEmpty
        collectionView.isHidden = visibleItems.isEmpty
        updateCategorySelection()
        collectionView.reloadData()
        updateAccessibilityOrder()
        guard moveAccessibilityFocus else { return }
        let target: AnyObject = visibleItems.isEmpty ? emptyStateLabel : headingLabel
        lastAccessibilityFocusTarget = target
        UIAccessibility.post(notification: .layoutChanged, argument: target)
    }

    private func updateAccessibilityOrder() {
        var elements: [Any] = [typingButton, searchButton, globeButton, backspaceButton]
        elements.append(contentsOf: categoryButtons)
        elements.append(headingLabel)
        elements.append(visibleItems.isEmpty ? emptyStateLabel : collectionView)
        accessibilityElements = elements
    }

    private func updateCategorySelection() {
        for (index, button) in categoryButtons.enumerated() {
            let isSelected = categorySelections[index] == selectedCategory
            if isSelected {
                button.accessibilityTraits.insert(.selected)
            } else {
                button.accessibilityTraits.remove(.selected)
            }
        }
        applyTheme()
    }

    private func showModifierChooser(for item: EmojiKeyboardItem, sourceFrame: CGRect) {
        guard !item.variants.isEmpty else { return }
        dismissModifierChooser()
        let chooser = EmojiModifierChooserView(
            variants: item.variants,
            sourceFrame: sourceFrame,
            availableBounds: bounds
        )
        chooser.onSelect = { [weak self, weak chooser] sequence in
            guard let self else { return }
            self.delegate?.emojiKeyboardView(self, didSelect: sequence)
            chooser?.removeFromSuperview()
            self.modifierChooser = nil
        }
        chooser.onDismiss = { [weak self, weak chooser] in
            chooser?.removeFromSuperview()
            self?.modifierChooser = nil
        }
        addSubview(chooser)
        modifierChooser = chooser
        if let first = chooser.variantButtons.first {
            lastAccessibilityFocusTarget = first
            UIAccessibility.post(notification: .layoutChanged, argument: first)
        }
    }

    private func categoryTitle(_ category: EmojiKeyboardCategory) -> String {
        switch category {
        case .recents:
            return NSLocalizedString("Recent", comment: "recent emoji category")
        case .catalog(let category):
            switch category {
            case .smileys: return NSLocalizedString("Smileys", comment: "emoji category")
            case .people: return NSLocalizedString("People", comment: "emoji category")
            case .animals: return NSLocalizedString("Animals", comment: "emoji category")
            case .food: return NSLocalizedString("Food", comment: "emoji category")
            case .travel: return NSLocalizedString("Travel", comment: "emoji category")
            case .activities: return NSLocalizedString("Activities", comment: "emoji category")
            case .objects: return NSLocalizedString("Objects", comment: "emoji category")
            case .symbols: return NSLocalizedString("Symbols", comment: "emoji category")
            case .flags: return NSLocalizedString("Flags", comment: "emoji category")
            }
        case .filtered:
            return NSLocalizedString("Results", comment: "emoji search results category")
        }
    }

    private func headingText(_ category: EmojiKeyboardCategory) -> String {
        switch category {
        case .filtered(let query):
            return String(
                format: NSLocalizedString("Results for %@", comment: "emoji search results heading"),
                query
            )
        default:
            return categoryTitle(category)
        }
    }

    private func applyTheme() {
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        backgroundColor = palette.background
        toolbar.backgroundColor = palette.background
        categoryScrollView.backgroundColor = palette.background
        headingLabel.textColor = palette.text
        emptyStateLabel.textColor = palette.text
        for button in [typingButton, searchButton, globeButton, backspaceButton] {
            button.backgroundColor = palette.specialFill
            button.tintColor = palette.text
            button.setTitleColor(palette.text, for: .normal)
        }
        for (index, button) in categoryButtons.enumerated() {
            let selected = categorySelections.indices.contains(index)
                && categorySelections[index] == selectedCategory
            button.backgroundColor = selected ? palette.plainFill : palette.specialFill
            button.setTitleColor(palette.text, for: .normal)
        }
    }

    @objc private func requestTyping() { delegate?.emojiKeyboardViewDidRequestTyping(self) }
    @objc private func requestSearch() { delegate?.emojiKeyboardViewDidRequestSearch(self) }
    @objc private func requestNextKeyboard() { delegate?.emojiKeyboardViewDidRequestNextKeyboard(self) }

    @objc private func categoryTapped(_ button: UIButton) {
        guard categorySelections.indices.contains(button.tag) else { return }
        showCategory(categorySelections[button.tag], moveAccessibilityFocus: true)
    }

    @objc private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        receivedBackspaceTouchDown = true
        backspaceStartedAt = Date()
        delegate?.emojiKeyboardViewDidRequestDelete(self)
        scheduleNextBackspace(after: QwertyBackspacePolicy.initialDelay)
    }

    @objc private func releaseBackspaceInside() {
        if !receivedBackspaceTouchDown {
            delegate?.emojiKeyboardViewDidRequestDelete(self)
        }
        stopBackspaceRepeat()
    }

    @objc private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
        backspaceStartedAt = nil
        receivedBackspaceTouchDown = false
    }

    private func scheduleNextBackspace(after interval: TimeInterval) {
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.repeatBackspace() }
        }
        backspaceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func repeatBackspace() {
        guard let started = backspaceStartedAt else { return }
        delegate?.emojiKeyboardViewDidRequestDelete(self)
        let elapsed = Date().timeIntervalSince(started)
        let configuration = QwertyBackspaceInteractionConfiguration(
            wordDeleteEnabled: false,
            initialDelay: QwertyBackspacePolicy.initialDelay,
            repeatInterval: QwertyBackspacePolicy.characterInterval
        )
        scheduleNextBackspace(after: QwertyBackspacePolicy.nextInterval(
            elapsed: elapsed,
            configuration: configuration
        ))
    }

    @objc private func longPressedEmoji(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              visibleItems.indices.contains(indexPath.item),
              !visibleItems[indexPath.item].variants.isEmpty else { return }
        let source = collectionView.convert(
            collectionView.layoutAttributesForItem(at: indexPath)?.frame ?? .zero,
            to: self
        )
        showModifierChooser(for: visibleItems[indexPath.item], sourceFrame: source)
    }
}

extension EmojiKeyboardView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        visibleItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EmojiCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! EmojiCollectionViewCell
        let item = visibleItems[indexPath.item]
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        cell.configure(item: item, palette: palette) { [weak self, weak cell] in
            guard let self else { return }
            let source = cell?.convert(cell?.bounds ?? .zero, to: self)
                ?? CGRect(x: self.bounds.midX - 22, y: self.bounds.midY - 22,
                          width: 44, height: 44)
            self.showModifierChooser(for: item, sourceFrame: source)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard visibleItems.indices.contains(indexPath.item) else { return }
        delegate?.emojiKeyboardView(self, didSelect: visibleItems[indexPath.item].sequence)
    }
}
