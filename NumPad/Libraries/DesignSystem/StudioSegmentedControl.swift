//
//  StudioSegmentedControl.swift
//  NumPad
//
//  Studio design system — segmented choice control.
//
//  Stacks vertically at accessibility content sizes so labels never clip, and
//  marks the selection with the `.selected` trait plus a weight change, never
//  colour alone.
//

import UIKit

final class StudioSegmentedControl: UIControl {

    public var palette: StudioPalette { didSet { rebuild() } }

    public private(set) var titles: [String]

    /// Currently selected index, or `nil` when the control is empty.
    public var selectedIndex: Int? {
        didSet {
            guard oldValue != selectedIndex else { return }
            updateSelection()
            sendActions(for: .valueChanged)
        }
    }

    /// Fires with the newly selected index on user interaction.
    public var onSelectionChange: ((Int) -> Void)?

    /// Optional VoiceOver hint applied to every segment.
    public var segmentHint: String?

    private let track = UIStackView()
    private var buttons: [UIButton] = []

    public init(
        titles: [String],
        selectedIndex: Int? = 0,
        palette: StudioPalette = .standard
    ) {
        self.titles = titles
        self.selectedIndex = Self.clamped(selectedIndex, to: titles)
        self.palette = palette
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioSegmentedControl is programmatic only")
    }

    private func setUp() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = palette.surfaceElevatedSecondary
        layer.cornerRadius = StudioMetrics.Radius.control
        layer.cornerCurve = .continuous
        clipsToBounds = true

        track.axis = .horizontal
        track.distribution = .fillEqually
        track.alignment = .fill
        track.spacing = StudioMetrics.Spacing.xs
        track.translatesAutoresizingMaskIntoConstraints = false
        track.isLayoutMarginsRelativeArrangement = true
        track.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: StudioMetrics.Spacing.xs, leading: StudioMetrics.Spacing.xs,
            bottom: StudioMetrics.Spacing.xs, trailing: StudioMetrics.Spacing.xs
        )
        addSubview(track)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        rebuild()
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification, object: nil
        )
    }

    public func setTitles(_ newTitles: [String], selectedIndex newIndex: Int? = nil) {
        titles = newTitles
        selectedIndex = Self.clamped(newIndex ?? selectedIndex, to: newTitles)
        rebuild()
    }

    // MARK: - Building

    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        track.arrangedSubviews.forEach { track.removeArrangedSubview($0) }
        backgroundColor = palette.surfaceElevatedSecondary

        track.axis = StudioMetrics.prefersVerticalLayout(for: traitCollection) ? .vertical : .horizontal
        track.distribution = track.axis == .vertical ? .fill : .fillEqually

        buttons = titles.enumerated().map { index, title in
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.layer.cornerRadius = StudioMetrics.Radius.inner
            button.layer.cornerCurve = .continuous
            button.tag = index
            button.setTitle(title, for: .normal)
            button.accessibilityHint = segmentHint
            button.addTarget(self, action: #selector(segmentTapped(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(
                greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget
            ).isActive = true
            track.addArrangedSubview(button)
            return button
        }
        updateSelection()
    }

    @objc private func segmentTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        selectedIndex = index
        onSelectionChange?(index)
        UIAccessibility.post(notification: .layoutChanged, argument: buttons[index])
    }

    @objc private func contentSizeCategoryDidChange() {
        rebuild()
    }

    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            button.backgroundColor = isSelected ? palette.accentFilled : .clear
            button.setTitleColor(
                isSelected ? palette.accentFilledForeground : palette.textSecondary,
                for: .normal
            )
            // Weight change means selection survives without colour.
            button.titleLabel?.font = StudioTypography.font(isSelected ? .button : .body)
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private static func clamped(_ index: Int?, to titles: [String]) -> Int? {
        guard !titles.isEmpty, let index else { return titles.isEmpty ? nil : index }
        return min(max(index, 0), titles.count - 1)
    }
}
