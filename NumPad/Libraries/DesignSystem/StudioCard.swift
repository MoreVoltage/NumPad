//
//  StudioCard.swift
//  NumPad
//
//  Studio design system — card container.
//
//  Use a card only where grouping or elevation carries meaning. Content is
//  added to a vertical stack, so cards grow naturally with Dynamic Type.
//

import UIKit

final class StudioCard: UIView {

    /// How much the card lifts off the page.
    enum Elevation {
        /// No shadow; a hairline border carries the grouping.
        case flat
        /// Light lift for inline grouping.
        case subtle
        /// Full lift for a primary surface.
        case raised
    }

    /// Which surface token the card paints itself with.
    enum Surface {
        case surface
        case elevated
        case elevatedSecondary
    }

    // MARK: - Configuration

    var palette: StudioPalette {
        didSet { applyPalette() }
    }

    var elevation: Elevation {
        didSet { applyElevation() }
    }

    var surface: Surface {
        didSet { applyPalette() }
    }

    /// Padding between the card edge and its content.
    var contentInsets: NSDirectionalEdgeInsets {
        get { contentStack.directionalLayoutMargins }
        set { contentStack.directionalLayoutMargins = newValue }
    }

    /// Vertical gap between arranged subviews.
    var contentSpacing: CGFloat {
        get { contentStack.spacing }
        set { contentStack.spacing = newValue }
    }

    /// Whether a hairline border is drawn. Defaults to `true`.
    var showsBorder: Bool = true {
        didSet { applyPalette() }
    }

    /// The vertical stack holding card content. Add subviews via
    /// `addArrangedSubview(_:)` rather than `addSubview(_:)`.
    let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = StudioMetrics.Spacing.m
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = StudioMetrics.Layout.cardInsets
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init

    init(
        palette: StudioPalette = .standard,
        surface: Surface = .elevated,
        elevation: Elevation = .subtle,
        contentInsets: NSDirectionalEdgeInsets = StudioMetrics.Layout.cardInsets
    ) {
        self.palette = palette
        self.surface = surface
        self.elevation = elevation
        super.init(frame: .zero)
        setUp(contentInsets: contentInsets)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioCard is programmatic only")
    }

    private func setUp(contentInsets: NSDirectionalEdgeInsets) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = StudioMetrics.Radius.card
        layer.cornerCurve = .continuous
        // The card must not clip its own shadow.
        clipsToBounds = false
        layer.masksToBounds = false

        addSubview(contentStack)
        contentStack.directionalLayoutMargins = contentInsets
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        applyPalette()
        applyElevation()
        observeTraitChanges()
    }

    // MARK: - Content

    func addArrangedSubview(_ view: UIView) {
        contentStack.addArrangedSubview(view)
    }

    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach(contentStack.addArrangedSubview)
    }

    func insertArrangedSubview(_ view: UIView, at index: Int) {
        contentStack.insertArrangedSubview(view, at: index)
    }

    func removeAllArrangedSubviews() {
        for view in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func setCustomSpacing(_ spacing: CGFloat, after view: UIView) {
        contentStack.setCustomSpacing(spacing, after: view)
    }

    /// Convenience divider matching the palette, sized to a hairline.
    func makeDivider() -> UIView {
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = palette.divider
        divider.isAccessibilityElement = false
        divider.heightAnchor.constraint(
            equalToConstant: StudioMetrics.Size.hairline(for: traitCollection)
        ).isActive = true
        return divider
    }

    // MARK: - Appearance

    private func applyPalette() {
        switch surface {
        case .surface: backgroundColor = palette.surface
        case .elevated: backgroundColor = palette.surfaceElevated
        case .elevatedSecondary: backgroundColor = palette.surfaceElevatedSecondary
        }
        layer.borderWidth = showsBorder ? StudioMetrics.Size.border : 0
        layer.borderColor = showsBorder
            ? palette.divider.resolvedColor(with: traitCollection).cgColor
            : UIColor.clear.cgColor
        updateShadowColor()
    }

    private func applyElevation() {
        switch elevation {
        case .flat:
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
        case .subtle:
            layer.shadowOpacity = StudioMetrics.Shadow.subtleOpacity
            layer.shadowRadius = StudioMetrics.Shadow.subtleRadius
            layer.shadowOffset = StudioMetrics.Shadow.subtleOffset
        case .raised:
            layer.shadowOpacity = StudioMetrics.Shadow.opacity
            layer.shadowRadius = StudioMetrics.Shadow.radius
            layer.shadowOffset = StudioMetrics.Shadow.offset
        }
        updateShadowColor()
    }

    private func updateShadowColor() {
        layer.shadowColor = palette.shadow.resolvedColor(with: traitCollection).cgColor
    }

    /// `CGColor` does not resolve traits automatically, so refresh on change.
    private func observeTraitChanges() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]
            ) { (card: StudioCard, _: UITraitCollection) in
                card.applyPalette()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Covers the pre-iOS-17 path (a trait change re-lays out the hierarchy)
        // and keeps the resolved CGColors in sync after any appearance change.
        applyPalette()
    }
}
