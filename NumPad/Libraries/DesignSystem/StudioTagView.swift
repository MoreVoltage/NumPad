//
//  StudioTagView.swift
//  NumPad
//
//  Studio design system — small pill tag.
//
//  Non-interactive. Text is always supplied by the caller (localisation is the
//  caller's job); an optional SF Symbol carries meaning alongside colour so the
//  tag never communicates state by colour alone.
//

import UIKit

enum StudioTagStyle {
    case neutral
    case good
    case warn
    case pro

    /// Default symbol for the style, so meaning survives without colour.
    /// Callers may override with the `symbolName` initialiser parameter.
    var defaultSymbolName: String? {
        switch self {
        case .neutral: return nil
        case .good: return "checkmark"
        case .warn: return "exclamationmark.triangle.fill"
        case .pro: return "lock.fill"
        }
    }

    func colors(in palette: StudioPalette) -> StudioPalette.TagColors {
        switch self {
        case .neutral: return palette.tagNeutral
        case .good: return palette.tagGood
        case .warn: return palette.tagWarn
        case .pro: return palette.tagPro
        }
    }
}

final class StudioTagView: UIView {

    // MARK: - Configuration

    var palette: StudioPalette {
        didSet { applyStyle() }
    }

    var style: StudioTagStyle {
        didSet { applyStyle() }
    }

    var text: String {
        didSet {
            label.text = text
            updateAccessibility()
        }
    }

    /// SF Symbol name shown before the text. `nil` uses the style default.
    var symbolName: String? {
        didSet { applySymbol() }
    }

    /// Set when the tag is purely decorative next to text that already says the
    /// same thing — keeps VoiceOver from reading it twice.
    var isDecorative: Bool = false {
        didSet { updateAccessibility() }
    }

    // MARK: - Subviews

    private let stack = UIStackView()
    private let iconView = UIImageView()
    private let label = UILabel()

    // MARK: - Init

    init(
        text: String,
        style: StudioTagStyle = .neutral,
        symbolName: String? = nil,
        palette: StudioPalette = .standard
    ) {
        self.text = text
        self.style = style
        self.symbolName = symbolName
        self.palette = palette
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioTagView is programmatic only")
    }

    private func setUp() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = StudioMetrics.Radius.tag
        layer.cornerCurve = .continuous
        clipsToBounds = true

        StudioTypography.apply(.tag, to: label)
        label.text = text
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.isAccessibilityElement = false

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = StudioMetrics.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: StudioMetrics.Spacing.xs,
            leading: StudioMetrics.Spacing.s,
            bottom: StudioMetrics.Spacing.xs,
            trailing: StudioMetrics.Spacing.s
        )
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)

        applyStyle()
        updateAccessibility()
        observeContentSizeChanges()
    }

    // MARK: - Appearance

    private func applyStyle() {
        let colors = style.colors(in: palette)
        backgroundColor = colors.background
        label.textColor = colors.foreground
        iconView.tintColor = colors.foreground
        applySymbol()
    }

    private func applySymbol() {
        let name = symbolName ?? style.defaultSymbolName
        guard let name else {
            iconView.isHidden = true
            iconView.image = nil
            return
        }
        let pointSize = StudioTypography.scaledValue(
            StudioMetrics.Size.iconSmall - 4,
            textStyle: StudioTypography.Style.tag.textStyle
        )
        let configuration = UIImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: UIAccessibility.isBoldTextEnabled ? .bold : .semibold
        )
        iconView.image = UIImage(systemName: name, withConfiguration: configuration)
        iconView.isHidden = iconView.image == nil
    }

    private func updateAccessibility() {
        isAccessibilityElement = !isDecorative
        accessibilityLabel = isDecorative ? nil : text
        accessibilityTraits = .staticText
    }

    // MARK: - Dynamic Type

    private func observeContentSizeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @objc private func contentSizeCategoryDidChange() {
        applySymbol()
    }
}
