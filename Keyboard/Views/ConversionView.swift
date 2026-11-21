import UIKit

protocol ConversionViewDelegate: AnyObject {
    func conversionView(_ view: ConversionView, didCompute value: String)
    func conversionViewDidRequestClose(_ view: ConversionView)
    /// The user tried to switch to a category they aren't entitled to. The view has already
    /// reverted its segmented control back to the last entitled category — the delegate should
    /// route to the paywall the same way a locked-key tap does.
    func conversionViewDidSelectLockedCategory(_ view: ConversionView)
}

/// Offline unit-conversion overlay (conversion-overlay feature). Routes numpad taps into its amount
/// field — the same passthrough pattern as TaxTipView — and converts length/mass/temperature via the
/// pure `UnitConverter`. Currency is intentionally absent (it needs live rates).
///
/// Category access is scoped to what the caller actually owns (`entitledCategories`, computed by
/// `Monetization.entitledConversionCategories`): every category is always listed so the user can see
/// what exists, but unentitled ones are shown with a lock glyph and can't be selected — mirroring
/// `PackPickerView`'s lock-chip treatment of locked packs.
class ConversionView: UIView {
    weak var delegate: ConversionViewDelegate?

    private let titleLabel = UILabel()
    private let amountField = UITextField()
    private let categoryControl = UISegmentedControl()
    private let fromControl = UISegmentedControl()
    private let toControl = UISegmentedControl()
    private let applyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    /// From → To indicator. A mirrored-for-RTL symbol rather than a literal "→": the unit row is a
    /// stack view, so in right-to-left layouts From sits on the right and the arrow must point left.
    private let unitArrowView = UIImageView()

    /// Layout metrics for the compact layout (see `init`). Sized so the content fits the 150pt
    /// default-height overlay band: 44 (header) + 6 + ~32 (category) + 6 + ~32 (units) + 2×8 insets.
    private static let verticalInset: CGFloat = 8
    private static let rowSpacing: CGFloat = 6
    private static let columnSpacing: CGFloat = 8

    private let entitledCategories: Set<UnitConverter.Category>
    private var category: UnitConverter.Category

    /// Lock glyph appended to a locked category's segment title. `UISegmentedControl` segments only
    /// support plain-string titles (no mixed image + text like `PackPickerView`'s `lock.fill`
    /// accessory), so a literal glyph character is the closest equivalent here.
    private static let lockGlyph = "🔒"

    /// The category to land on when the overlay opens: the first entitled category in display
    /// order (so a Cooking-only buyer opens on Volume, not a locked Length), falling back to
    /// `.length` if somehow entitled to nothing (defensive — the overlay itself is only reachable
    /// when at least one category is entitled; see `Monetization.isConversionOverlayReachable`).
    private static func defaultCategory(entitled: Set<UnitConverter.Category>) -> UnitConverter.Category {
        UnitConverter.Category.allCases.first { entitled.contains($0) } ?? .length
    }

    init(frame: CGRect = .zero, entitledCategories: Set<UnitConverter.Category>) {
        self.entitledCategories = entitledCategories
        self.category = ConversionView.defaultCategory(entitled: entitledCategories)
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("Convert", comment: "Conversion overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)

        amountField.placeholder = NSLocalizedString("Amount", comment: "Conversion amount field placeholder")
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect

        rebuildCategoryControl()
        categoryControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        rebuildUnitControls()

        applyButton.setTitle(NSLocalizedString("Insert", comment: ""), for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // Compact layout so the whole converter fits the overlay band at the default keyboard
        // height (50% of 300pt = 150pt on iPhone) without scrolling. The old one-control-per-row
        // stack needed ~290pt, which pushed From/To, Insert and Close below the fold so a
        // conversion couldn't be completed. Rows: [title | amount | Insert | Close], category,
        // then From → To side by side. The scroll view stays as a fallback for shorter bands
        // (e.g. landscape), where everything remains reachable by scrolling.
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        for button in [applyButton, closeButton] {
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        amountField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        amountField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, amountField, applyButton, closeButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = Self.columnSpacing

        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        unitArrowView.image = UIImage(systemName: "arrow.right", withConfiguration: arrowConfig)?
            .imageFlippedForRightToLeftLayoutDirection()
        unitArrowView.tintColor = .secondaryLabel
        unitArrowView.contentMode = .center
        unitArrowView.isAccessibilityElement = false
        unitArrowView.accessibilityIdentifier = "conversion.unitArrow"
        unitArrowView.setContentHuggingPriority(.required, for: .horizontal)
        unitArrowView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // From and To share one row, so each selector gets under half the width (~150pt for six
        // length units on an iPhone SE band or the 360pt iPad panel). Equal-width segments there
        // truncated "cm"/"km" to "…"; sizing segments by their titles lets the short ones (m, in, ft)
        // donate width so every unit name renders in full.
        // Same for the category row: equal quarters (~83pt at 355pt) cut "Temperature" (77pt) and a
        // locked "🔒 Temperature" (~100pt) to "…"; the short titles (Mass, Volume) donate the width.
        for control in [fromControl, toControl, categoryControl] {
            control.apportionsSegmentWidthsByContent = true
        }

        let unitRow = UIStackView(arrangedSubviews: [fromControl, unitArrowView, toControl])
        unitRow.axis = .horizontal
        unitRow.alignment = .center
        unitRow.spacing = Self.columnSpacing

        let stack = UIStackView(arrangedSubviews: [headerRow, categoryControl, unitRow])
        stack.axis = .vertical
        stack.spacing = Self.rowSpacing

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            // The iOS 26+ soft scroll-edge fade otherwise washes out the header row (title,
            // amount, Insert, Close), which now sits flush with the scroll view's top edge.
            scrollView.topEdgeEffect.isHidden = true
            scrollView.bottomEdgeEffect.isHidden = true
        }
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalInset),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalInset),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            // From and To share the unit row equally.
            fromControl.widthAnchor.constraint(equalTo: toControl.widthAnchor),

            // ≥44pt tap targets (Apple's HIG minimum) for the action buttons.
            applyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// (Re)builds the category segments from *every* category, appending a lock glyph to the
    /// title of any the caller isn't entitled to, and selects the current `category`.
    private func rebuildCategoryControl() {
        categoryControl.removeAllSegments()
        for (i, cat) in UnitConverter.Category.allCases.enumerated() {
            let title = entitledCategories.contains(cat) ? cat.displayName : "\(Self.lockGlyph) \(cat.displayName)"
            categoryControl.insertSegment(withTitle: title, at: i, animated: false)
        }
        if let index = UnitConverter.Category.allCases.firstIndex(of: category) {
            categoryControl.selectedSegmentIndex = index
        }
    }

    private func rebuildUnitControls() {
        let units = category.units
        fromControl.removeAllSegments()
        toControl.removeAllSegments()
        for (i, unit) in units.enumerated() {
            fromControl.insertSegment(withTitle: unit, at: i, animated: false)
            toControl.insertSegment(withTitle: unit, at: i, animated: false)
        }
        fromControl.selectedSegmentIndex = 0
        toControl.selectedSegmentIndex = min(1, units.count - 1)
    }

    @objc private func categoryChanged() {
        let selected = UnitConverter.Category.allCases[categoryControl.selectedSegmentIndex]
        guard entitledCategories.contains(selected) else {
            // Never reveal a locked category's conversion UI: snap the segment back to the last
            // entitled category and let the delegate route to the paywall, same as a locked key.
            if let index = UnitConverter.Category.allCases.firstIndex(of: category) {
                categoryControl.selectedSegmentIndex = index
            }
            delegate?.conversionViewDidSelectLockedCategory(self)
            return
        }
        category = selected
        rebuildUnitControls()
    }

    @objc private func applyTapped() {
        let raw = amountField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        let units = category.units
        guard let value = Double(raw),
              units.indices.contains(fromControl.selectedSegmentIndex),
              units.indices.contains(toControl.selectedSegmentIndex),
              let result = UnitConverter.convert(value,
                                                 from: units[fromControl.selectedSegmentIndex],
                                                 to: units[toControl.selectedSegmentIndex]) else {
            signalInvalidInput()
            return
        }
        delegate?.conversionView(self, didCompute: Calculator.format(result))
    }

    @objc private func closeTapped() {
        delegate?.conversionViewDidRequestClose(self)
    }

    private func signalInvalidInput() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.4
        amountField.layer.add(animation, forKey: "shake")
    }
}

// MARK: - Input helpers for routing keyboard taps while the overlay is visible
extension ConversionView {
    func append(_ s: String) {
        let current = amountField.text ?? ""
        if s == "." && current.contains(".") { return }
        amountField.text = current + s
    }
    func deleteBackward() {
        guard var t = amountField.text, !t.isEmpty else { return }
        t.removeLast()
        amountField.text = t
    }
    func apply() { applyTapped() }
}
