//
//  StudioStatusHeroView.swift
//  NumPad
//
//  Studio design system — readiness hero.
//
//  Each state carries a distinct SF Symbol AND caller-supplied text, so the
//  state is never communicated by colour alone.
//

import UIKit

enum StudioStatusLevel {
    case ok
    case warn
    case unavailable

    var symbolName: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.octagon.fill"
        }
    }

    func colors(in palette: StudioPalette) -> StudioPalette.StatusColors {
        switch self {
        case .ok: return palette.statusOK
        case .warn: return palette.statusWarn
        case .unavailable: return palette.statusUnavailable
        }
    }

    var accessibilityState: String {
        switch self {
        case .ok:
            return NSLocalizedString("Ready", comment: "VoiceOver readiness state")
        case .warn:
            return NSLocalizedString("Needs attention", comment: "VoiceOver readiness state")
        case .unavailable:
            return NSLocalizedString("Unavailable", comment: "VoiceOver readiness state")
        }
    }
}

final class StudioStatusHeroView: UIView {

    var palette: StudioPalette { didSet { applyState() } }
    private(set) var level: StudioStatusLevel
    private(set) var title: String
    private(set) var message: String?

    /// Fires when the (optional) action button is tapped.
    var onAction: (() -> Void)?
    /// Stable automation identifier for the optional visible action. The hero deliberately keeps
    /// the button private so callers cannot couple to its implementation details.
    var actionAccessibilityIdentifier: String? {
        didSet { actionButton?.accessibilityIdentifier = actionAccessibilityIdentifier }
    }

    private let symbolWell = UIView()
    private let symbolView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let textStack = UIStackView()
    private let headerStack = UIStackView()
    private let contentStack = UIStackView()
    private var actionButton: StudioButton?

    init(
        level: StudioStatusLevel,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        palette: StudioPalette = .standard
    ) {
        self.level = level
        self.title = title
        self.message = message
        self.palette = palette
        super.init(frame: .zero)
        setUp(actionTitle: actionTitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioStatusHeroView is programmatic only")
    }

    private func setUp(actionTitle: String?) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = StudioMetrics.Radius.card
        layer.cornerCurve = .continuous
        layer.borderWidth = StudioMetrics.Size.border
        clipsToBounds = true

        symbolWell.translatesAutoresizingMaskIntoConstraints = false
        symbolWell.layer.cornerRadius = StudioMetrics.Size.minTouchTarget / 2
        symbolWell.layer.cornerCurve = .continuous
        symbolWell.isAccessibilityElement = false

        symbolView.contentMode = .scaleAspectFit
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.isAccessibilityElement = false
        symbolView.setContentHuggingPriority(.required, for: .horizontal)
        symbolView.setContentCompressionResistancePriority(.required, for: .horizontal)

        symbolWell.addSubview(symbolView)
        NSLayoutConstraint.activate([
            symbolWell.widthAnchor.constraint(equalToConstant: StudioMetrics.Size.minTouchTarget),
            symbolWell.heightAnchor.constraint(equalTo: symbolWell.widthAnchor),
            symbolView.centerXAnchor.constraint(equalTo: symbolWell.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: symbolWell.centerYAnchor)
        ])

        StudioTypography.apply(.sectionHeading, to: titleLabel)
        StudioTypography.apply(.subtitle, to: messageLabel)

        textStack.axis = .vertical
        textStack.spacing = StudioMetrics.Spacing.xs
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(messageLabel)

        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = StudioMetrics.Spacing.m
        headerStack.addArrangedSubview(symbolWell)
        headerStack.addArrangedSubview(textStack)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = StudioMetrics.Spacing.m
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = StudioMetrics.Layout.cardInsets
        contentStack.addArrangedSubview(headerStack)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setActionTitle(actionTitle)
        applyState()

        NotificationCenter.default.addObserver(
            self, selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification, object: nil
        )
    }

    /// Replaces the whole state in one call. Announces the change to VoiceOver.
    func update(
        level: StudioStatusLevel,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        announce: Bool = true
    ) {
        self.level = level
        self.title = title
        self.message = message
        setActionTitle(actionTitle)
        applyState()
        if announce, let label = accessibilityLabel {
            UIAccessibility.post(notification: .announcement, argument: label)
        }
    }

    func setActionTitle(_ actionTitle: String?) {
        actionButton?.removeFromSuperview()
        actionButton = nil
        guard let actionTitle, !actionTitle.isEmpty else {
            actionAccessibilityIdentifier = nil
            return
        }
        let button = StudioButton(title: actionTitle, style: .primary, palette: palette)
        button.accessibilityIdentifier = actionAccessibilityIdentifier
        button.onTap = { [weak self] in self?.onAction?() }
        contentStack.addArrangedSubview(button)
        actionButton = button
    }

    @objc private func contentSizeCategoryDidChange() {
        applyState()
    }

    private func applyState() {
        let colors = level.colors(in: palette)
        backgroundColor = colors.background
        layer.borderColor = colors.border.resolvedColor(with: traitCollection).cgColor
        symbolWell.backgroundColor = colors.foreground.withAlphaComponent(0.12)
        titleLabel.textColor = colors.foreground
        messageLabel.textColor = colors.foreground.withAlphaComponent(0.85)
        symbolView.tintColor = colors.symbolTint

        let pointSize = StudioTypography.scaledValue(
            StudioMetrics.Size.heroSymbol,
            textStyle: StudioTypography.Style.sectionHeading.textStyle
        )
        symbolView.image = UIImage(
            systemName: level.symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        )

        titleLabel.text = title
        messageLabel.text = message
        messageLabel.isHidden = (message?.isEmpty ?? true)

        // Symbol and text stack side by side would clip at accessibility sizes.
        headerStack.axis = StudioMetrics.prefersVerticalLayout(for: traitCollection) ? .vertical : .horizontal
        headerStack.alignment = headerStack.axis == .vertical ? .leading : .top

        actionButton?.palette = palette

        // The text block reads as one coherent element; the action button, when
        // present, stays a separate focusable element after it.
        textStack.isAccessibilityElement = true
        textStack.accessibilityTraits = .staticText
        textStack.accessibilityLabel = [level.accessibilityState, title, message]
            .compactMap { $0 }
            .joined(separator: ", ")
        isAccessibilityElement = false
        accessibilityLabel = textStack.accessibilityLabel
        if let actionButton {
            accessibilityElements = [textStack, actionButton]
        } else {
            accessibilityElements = [textStack]
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = level.colors(in: palette)
            .border.resolvedColor(with: traitCollection).cgColor
    }
}
