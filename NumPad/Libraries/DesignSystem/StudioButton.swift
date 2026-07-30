//
//  StudioButton.swift
//  NumPad
//
//  Studio design system — primary / secondary / text buttons.
//

import UIKit

enum StudioButtonStyle {
    /// Filled mint action. One per screen.
    case primary
    /// Outlined action on a surface.
    case secondary
    /// Bare accent-coloured text action.
    case text
    /// Destructive text action.
    case destructive
}

final class StudioButton: UIButton {

    public var palette: StudioPalette {
        didSet { applyStyle() }
    }

    public var style: StudioButtonStyle {
        didSet { applyStyle() }
    }

    /// Named `titleText` rather than `title` because `UIButton` already declares
    /// a mutable optional `title`, which a non-optional override cannot satisfy.
    public var titleText: String {
        didSet {
            applyStyle()
            updateAccessibility()
        }
    }

    /// SF Symbol shown before the title.
    public var symbolName: String? {
        didSet { applyStyle() }
    }

    /// Extra VoiceOver hint. `nil` means no hint.
    public var hint: String? {
        didSet { updateAccessibility() }
    }

    /// Invoked on `.touchUpInside`.
    public var onTap: (() -> Void)?

    public init(
        title: String,
        style: StudioButtonStyle = .primary,
        symbolName: String? = nil,
        palette: StudioPalette = .standard
    ) {
        self.titleText = title
        self.style = style
        self.symbolName = symbolName
        self.palette = palette
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioButton is programmatic only")
    }

    private func setUp() {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.numberOfLines = 0
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontForContentSizeCategory = true
        heightAnchor.constraint(
            greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget
        ).isActive = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applyStyle()
        updateAccessibility()
    }

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Appearance

    private func applyStyle() {
        var configuration: UIButton.Configuration
        switch style {
        case .primary:
            configuration = .filled()
            configuration.baseBackgroundColor = palette.accentFilled
            configuration.baseForegroundColor = palette.accentFilledForeground
        case .secondary:
            configuration = .plain()
            configuration.background.backgroundColor = palette.accentSubtle
            configuration.background.strokeColor = palette.accent
            configuration.background.strokeWidth = StudioMetrics.Size.border
            configuration.baseForegroundColor = palette.accent
        case .text:
            configuration = .plain()
            configuration.background.backgroundColor = .clear
            configuration.baseForegroundColor = palette.accent
        case .destructive:
            configuration = .plain()
            configuration.background.backgroundColor = .clear
            configuration.baseForegroundColor = palette.destructive
        }

        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = StudioMetrics.Radius.control
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: StudioMetrics.Spacing.m,
            leading: StudioMetrics.Spacing.xl,
            bottom: StudioMetrics.Spacing.m,
            trailing: StudioMetrics.Spacing.xl
        )
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.imagePadding = StudioMetrics.Spacing.s
        configuration.image = symbolName.flatMap { name in
            UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(
                pointSize: StudioTypography.scaledValue(
                    StudioMetrics.Size.icon,
                    textStyle: StudioTypography.Style.button.textStyle
                ),
                weight: .semibold
            ))
        }

        var container = AttributeContainer()
        container.font = StudioTypography.font(.button)
        configuration.attributedTitle = AttributedString(titleText, attributes: container)

        self.configuration = configuration
        configurationUpdateHandler = { button in
            let dimmed = button.state.contains(.highlighted) || !button.isEnabled
            button.alpha = dimmed ? 0.6 : 1
            button.transform = button.state.contains(.highlighted)
                ? StudioMotion.pressedTransform()
                : .identity
        }
    }

    private func updateAccessibility() {
        accessibilityLabel = titleText
        accessibilityHint = hint
        accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
    }

    public override var isEnabled: Bool {
        didSet { updateAccessibility() }
    }
}
