//
//  StudioTileView.swift
//  NumPad
//
//  Studio design system — selectable choice tile.
//
//  Selection is signalled by a checkmark badge, a thicker border AND the
//  `.selected` trait. Locked tiles carry a lock glyph plus caller-supplied text.
//

import UIKit

final class StudioTileView: UIControl {

    /// Leading visual: either an SF Symbol or a flat colour swatch.
    enum Leading {
        case none
        case symbol(String)
        case swatch(UIColor)
    }

    var palette: StudioPalette { didSet { applyPalette() } }
    var title: String { didSet { titleLabel.text = title; updateAccessibility() } }
    var subtitle: String? { didSet { applySubtitle(); updateAccessibility() } }
    /// Locked state text; `nil` means unlocked.
    var lockText: String? { didSet { applyLock(); updateAccessibility() } }
    var hint: String? { didSet { updateAccessibility() } }
    var onTap: (() -> Void)?

    override var isSelected: Bool {
        didSet { applySelection() }
    }

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.55
            updateAccessibility()
        }
    }

    private let leadingContainer = UIView()
    private let symbolView = UIImageView()
    private let swatchView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeView = UIImageView()
    private let textStack = UIStackView()
    private let headerStack = UIStackView()
    private let contentStack = UIStackView()
    private var lockTag: StudioTagView?
    private var lockWrapper: UIView?

    init(
        title: String,
        subtitle: String? = nil,
        leading: Leading = .none,
        isSelected: Bool = false,
        lockText: String? = nil,
        palette: StudioPalette = .standard
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lockText = lockText
        self.palette = palette
        super.init(frame: .zero)
        self.isSelected = isSelected
        setUp(leading: leading)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioTileView is programmatic only")
    }

    private func setUp(leading: Leading) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = StudioMetrics.Radius.tile
        layer.cornerCurve = .continuous
        clipsToBounds = true

        symbolView.contentMode = .scaleAspectFit
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        swatchView.layer.cornerRadius = StudioMetrics.Radius.tag
        swatchView.layer.cornerCurve = .continuous
        leadingContainer.translatesAutoresizingMaskIntoConstraints = false
        leadingContainer.isAccessibilityElement = false
        leadingContainer.addSubview(symbolView)
        leadingContainer.addSubview(swatchView)
        NSLayoutConstraint.activate([
            leadingContainer.widthAnchor.constraint(equalToConstant: StudioMetrics.Size.swatch),
            leadingContainer.heightAnchor.constraint(equalTo: leadingContainer.widthAnchor),
            symbolView.centerXAnchor.constraint(equalTo: leadingContainer.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: leadingContainer.centerYAnchor),
            swatchView.topAnchor.constraint(equalTo: leadingContainer.topAnchor),
            swatchView.leadingAnchor.constraint(equalTo: leadingContainer.leadingAnchor),
            swatchView.trailingAnchor.constraint(equalTo: leadingContainer.trailingAnchor),
            swatchView.bottomAnchor.constraint(equalTo: leadingContainer.bottomAnchor)
        ])
        setLeading(leading)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.contentMode = .scaleAspectFit
        badgeView.isAccessibilityElement = false
        badgeView.setContentHuggingPriority(.required, for: .horizontal)
        badgeView.widthAnchor.constraint(
            equalToConstant: StudioMetrics.Size.selectionBadge
        ).isActive = true

        StudioTypography.apply(.cardTitle, to: titleLabel)
        titleLabel.text = title
        StudioTypography.apply(.subtitle, to: subtitleLabel)

        textStack.axis = .vertical
        textStack.spacing = StudioMetrics.Spacing.hair
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = StudioMetrics.Spacing.m
        headerStack.addArrangedSubview(leadingContainer)
        headerStack.addArrangedSubview(textStack)
        headerStack.addArrangedSubview(badgeView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = StudioMetrics.Spacing.s
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = StudioMetrics.Layout.tileInsets
        contentStack.isUserInteractionEnabled = false
        contentStack.addArrangedSubview(headerStack)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applySubtitle()
        applyLock()
        applyPalette()
        updateAccessibility()
    }

    func setLeading(_ leading: Leading) {
        switch leading {
        case .none:
            leadingContainer.isHidden = true
        case .symbol(let name):
            leadingContainer.isHidden = false
            swatchView.isHidden = true
            symbolView.isHidden = false
            let pointSize = StudioTypography.scaledValue(StudioMetrics.Size.iconLarge)
            symbolView.image = UIImage(
                systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            )
        case .swatch(let color):
            leadingContainer.isHidden = false
            symbolView.isHidden = true
            swatchView.isHidden = false
            swatchView.backgroundColor = color
        }
    }

    @objc private func handleTap() {
        onTap?()
    }

    private func applySubtitle() {
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle?.isEmpty ?? true)
    }

    private func applyLock() {
        if let lockWrapper {
            contentStack.removeArrangedSubview(lockWrapper)
            lockWrapper.removeFromSuperview()
        }
        self.lockWrapper = nil
        lockTag = nil
        guard let lockText, !lockText.isEmpty else { return }
        let tag = StudioTagView(text: lockText, style: .pro, palette: palette)
        let wrapper = UIStackView(arrangedSubviews: [tag, UIView()])
        wrapper.axis = .horizontal
        contentStack.addArrangedSubview(wrapper)
        lockTag = tag
        lockWrapper = wrapper
    }

    private func applyPalette() {
        backgroundColor = isSelected ? palette.accentSubtle : palette.surfaceElevated
        titleLabel.textColor = palette.textPrimary
        subtitleLabel.textColor = palette.textSecondary
        symbolView.tintColor = palette.accent
        swatchView.layer.borderWidth = StudioMetrics.Size.border
        swatchView.layer.borderColor = palette.divider.resolvedColor(with: traitCollection).cgColor
        applySelection()
    }

    private func applySelection() {
        layer.borderWidth = isSelected ? StudioMetrics.Size.borderSelected : StudioMetrics.Size.border
        layer.borderColor = (isSelected ? palette.accent : palette.divider)
            .resolvedColor(with: traitCollection).cgColor
        backgroundColor = isSelected ? palette.accentSubtle : palette.surfaceElevated
        let pointSize = StudioTypography.scaledValue(StudioMetrics.Size.iconSmall)
        badgeView.image = isSelected
            ? UIImage(systemName: "checkmark.circle.fill",
                      withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold))
            : nil
        badgeView.tintColor = palette.accent
        badgeView.isHidden = !isSelected
        updateAccessibility()
    }

    private func updateAccessibility() {
        isAccessibilityElement = true
        accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = lockText
        accessibilityHint = hint ?? (lockText?.isEmpty == false ? NSLocalizedString(
            "Unlock with NumPad Pro",
            comment: "VoiceOver hint for a locked Studio control that opens the Pro purchase sheet"
        ) : nil)
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if !isEnabled { traits.insert(.notEnabled) }
        accessibilityTraits = traits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = (isSelected ? palette.accent : palette.divider)
            .resolvedColor(with: traitCollection).cgColor
        swatchView.layer.borderColor = palette.divider.resolvedColor(with: traitCollection).cgColor
    }

    override var isHighlighted: Bool {
        didSet {
            transform = isHighlighted ? StudioMotion.pressedTransform() : .identity
        }
    }
}
