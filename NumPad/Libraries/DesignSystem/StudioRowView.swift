//
//  StudioRowView.swift
//  NumPad
//
//  Studio design system — icon + title + subtitle + accessory row.
//

import UIKit

final class StudioRowView: UIControl {

    /// Trailing accessory. Lock state always carries a glyph *and* caller text,
    /// so it never depends on colour alone.
    public enum Accessory {
        case none
        /// Chevron that flips for RTL.
        case disclosure
        case checkmark
        /// Trailing read-only value text.
        case value(String)
        /// Locked state: lock glyph plus the caller's localised text.
        case locked(String)
        /// Switch. `onChange` fires with the new value.
        case toggle(isOn: Bool, onChange: (Bool) -> Void)
        case custom(UIView)
    }

    // MARK: - Configuration

    public var palette: StudioPalette { didSet { applyPalette() } }
    public var title: String { didSet { titleLabel.text = title; updateAccessibility() } }
    public var subtitle: String? { didSet { applySubtitle(); updateAccessibility() } }
    /// Optional VoiceOver hint describing what activating the row does.
    public var hint: String? { didSet { updateAccessibility() } }
    public var onTap: (() -> Void)?

    public private(set) var accessory: Accessory {
        didSet { applyAccessory() }
    }

    // MARK: - Subviews

    private let iconWell = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()
    private let rowStack = UIStackView()
    private let accessoryContainer = UIView()
    private let toggle = UISwitch()
    private var toggleHandler: ((Bool) -> Void)?

    // MARK: - Init

    public init(
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        accessory: Accessory = .disclosure,
        palette: StudioPalette = .standard
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.palette = palette
        super.init(frame: .zero)
        setUp(symbolName: symbolName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioRowView is programmatic only")
    }

    private func setUp(symbolName: String?) {
        translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isAccessibilityElement = false
        iconWell.translatesAutoresizingMaskIntoConstraints = false
        iconWell.layer.cornerRadius = StudioMetrics.Radius.chip
        iconWell.layer.cornerCurve = .continuous
        iconWell.isAccessibilityElement = false
        iconWell.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconWell.widthAnchor.constraint(equalToConstant: StudioMetrics.Size.iconWell),
            iconWell.heightAnchor.constraint(equalTo: iconWell.widthAnchor),
            iconView.centerXAnchor.constraint(equalTo: iconWell.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWell.centerYAnchor)
        ])
        setSymbol(symbolName)

        StudioTypography.apply(.cardTitle, to: titleLabel)
        titleLabel.text = title
        StudioTypography.apply(.subtitle, to: subtitleLabel)

        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = StudioMetrics.Spacing.hair
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        accessoryContainer.translatesAutoresizingMaskIntoConstraints = false
        accessoryContainer.setContentHuggingPriority(.required, for: .horizontal)
        accessoryContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = StudioMetrics.Spacing.m
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.isLayoutMarginsRelativeArrangement = true
        rowStack.directionalLayoutMargins = StudioMetrics.Layout.rowInsets
        rowStack.isUserInteractionEnabled = false
        rowStack.addArrangedSubview(iconWell)
        rowStack.addArrangedSubview(textStack)
        rowStack.addArrangedSubview(accessoryContainer)
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget)
        ])

        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        applySubtitle()
        applyAccessory()
        applyPalette()
        updateAccessibility()

        NotificationCenter.default.addObserver(
            self, selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification, object: nil
        )
    }

    // MARK: - Mutation

    public func setSymbol(_ symbolName: String?) {
        guard let symbolName else {
            iconWell.isHidden = true
            iconView.image = nil
            return
        }
        iconWell.isHidden = false
        let pointSize = StudioTypography.scaledValue(StudioMetrics.Size.icon)
        iconView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        )
    }

    public func setAccessory(_ accessory: Accessory) {
        self.accessory = accessory
        updateAccessibility()
    }

    @objc private func handleTap() {
        if case .toggle = accessory {
            toggle.setOn(!toggle.isOn, animated: !StudioMotion.isReduced)
            toggleChanged()
            return
        }
        onTap?()
    }

    @objc private func toggleChanged() {
        toggleHandler?(toggle.isOn)
    }

    @objc private func contentSizeCategoryDidChange() {
        applyAccessory()
    }

    // MARK: - Appearance

    private func applySubtitle() {
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle?.isEmpty ?? true)
    }

    private func applyPalette() {
        titleLabel.textColor = palette.textPrimary
        subtitleLabel.textColor = palette.textSecondary
        iconWell.backgroundColor = palette.surfaceElevatedSecondary
        iconView.tintColor = palette.accent
        toggle.onTintColor = palette.accentFilled
    }

    private func applyAccessory() {
        accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
        toggleHandler = nil

        let view: UIView?
        switch accessory {
        case .none:
            view = nil
        case .disclosure:
            view = makeSymbolView("chevron.forward", tint: palette.textSecondary)
        case .checkmark:
            view = makeSymbolView("checkmark", tint: palette.accent)
        case .value(let text):
            view = makeTrailingLabel(text, color: palette.textSecondary)
        case .locked(let text):
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = StudioMetrics.Spacing.xs
            stack.translatesAutoresizingMaskIntoConstraints = false
            if let glyph = makeSymbolView("lock.fill", tint: palette.textSecondary) {
                stack.addArrangedSubview(glyph)
            }
            stack.addArrangedSubview(makeTrailingLabel(text, color: palette.textSecondary))
            view = stack
        case .toggle(let isOn, let onChange):
            toggle.isOn = isOn
            toggleHandler = onChange
            view = toggle
        case .custom(let custom):
            view = custom
        }

        guard let view else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        accessoryContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
            view.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor)
        ])
    }

    private func makeSymbolView(_ name: String, tint: UIColor) -> UIView? {
        let pointSize = StudioTypography.scaledValue(StudioMetrics.Size.iconSmall)
        guard let image = UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        ) else { return nil }
        let view = UIImageView(image: image)
        view.tintColor = tint
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }

    private func makeTrailingLabel(_ text: String, color: UIColor) -> UILabel {
        let label = StudioTypography.makeLabel(.subtitle, color: color, text: text)
        label.isAccessibilityElement = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }

    // MARK: - Accessibility

    private func updateAccessibility() {
        var value: String?
        var traits: UIAccessibilityTraits = .button

        switch accessory {
        case .toggle:
            // Let the switch be the element so VoiceOver speaks system on/off.
            isAccessibilityElement = false
            accessibilityElements = [toggle]
            toggle.isAccessibilityElement = true
            toggle.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
            toggle.accessibilityHint = hint
            return
        case .value(let text):
            value = text
        case .locked(let text):
            value = text
        case .checkmark:
            traits.insert(.selected)
        case .none, .disclosure, .custom:
            break
        }

        accessibilityElements = nil
        isAccessibilityElement = true
        accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = value
        accessibilityHint = hint ?? (isLocked ? NSLocalizedString(
            "Unlock with NumPad Pro",
            comment: "VoiceOver hint for a locked Studio control that opens the Pro purchase sheet"
        ) : nil)
        accessibilityTraits = traits
    }

    public override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? palette.accentSubtle : .clear
        }
    }

    private var isLocked: Bool {
        if case .locked = accessory { return true }
        return false
    }
}
