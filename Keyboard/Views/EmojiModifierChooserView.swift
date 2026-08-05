import UIKit

/// Exact, catalog-provided emoji variant. Sequences are never synthesized at runtime.
struct EmojiKeyboardVariant: Equatable {
    let sequence: String
    let accessibilityLabel: String
}

/// In-bounds skin-tone chooser. Buttons intentionally use the chooser's coordinate space so
/// both geometry tests and hit testing can prove the entire interaction stays inside the
/// keyboard extension rather than escaping into a host-window popover.
final class EmojiModifierChooserView: UIView {
    private enum Metrics {
        static let target: CGFloat = 44
        static let gap: CGFloat = 4
        static let padding: CGFloat = 6
        static let edge: CGFloat = 4
        static let sourceGap: CGFloat = 4
        static let maxColumns = 6
    }

    let usesGrid: Bool
    private(set) var variantButtons: [UIButton] = []
    private(set) var panelFrame: CGRect = .zero
    var onSelect: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let variants: [EmojiKeyboardVariant]
    private let panelView = UIView()

    init(variants: [EmojiKeyboardVariant], sourceFrame: CGRect, availableBounds: CGRect) {
        self.variants = variants

        let safeBounds = availableBounds.insetBy(dx: Metrics.edge, dy: Metrics.edge)
        let horizontalWidth = CGFloat(variants.count) * Metrics.target
            + CGFloat(max(variants.count - 1, 0)) * Metrics.gap
            + 2 * Metrics.padding
        usesGrid = variants.count > Metrics.maxColumns || horizontalWidth > safeBounds.width

        super.init(frame: availableBounds)
        clipsToBounds = true
        isAccessibilityElement = false

        let columnLimit = max(1, Int((safeBounds.width - 2 * Metrics.padding + Metrics.gap)
            / (Metrics.target + Metrics.gap)))
        let columns = usesGrid
            ? min(max(1, min(Metrics.maxColumns, columnLimit)), max(variants.count, 1))
            : max(variants.count, 1)
        let rows = max(1, Int(ceil(Double(max(variants.count, 1)) / Double(columns))))
        let panelWidth = min(
            safeBounds.width,
            CGFloat(columns) * Metrics.target + CGFloat(max(columns - 1, 0)) * Metrics.gap
                + 2 * Metrics.padding
        )
        let panelHeight = min(
            safeBounds.height,
            CGFloat(rows) * Metrics.target + CGFloat(max(rows - 1, 0)) * Metrics.gap
                + 2 * Metrics.padding
        )

        var originX = sourceFrame.midX - panelWidth / 2
        originX = min(max(originX, safeBounds.minX), safeBounds.maxX - panelWidth)
        var originY = sourceFrame.minY - Metrics.sourceGap - panelHeight
        if originY < safeBounds.minY {
            originY = sourceFrame.maxY + Metrics.sourceGap
        }
        originY = min(max(originY, safeBounds.minY), safeBounds.maxY - panelHeight)
        panelFrame = CGRect(x: originX, y: originY, width: panelWidth, height: panelHeight)

        panelView.frame = panelFrame
        panelView.layer.cornerRadius = 10
        panelView.layer.masksToBounds = true
        addSubview(panelView)

        for (index, variant) in variants.enumerated() {
            let column = index % columns
            let row = index / columns
            let button = UIButton(type: .system)
            button.frame = CGRect(
                x: panelFrame.minX + Metrics.padding + CGFloat(column) * (Metrics.target + Metrics.gap),
                y: panelFrame.minY + Metrics.padding + CGFloat(row) * (Metrics.target + Metrics.gap),
                width: Metrics.target,
                height: Metrics.target
            )
            button.setTitle(variant.sequence, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 27)
            button.accessibilityLabel = variant.accessibilityLabel
            button.accessibilityTraits = .button
            button.tag = index
            button.addTarget(self, action: #selector(selectedVariant(_:)), for: .touchUpInside)
            addSubview(button)
            variantButtons.append(button)
        }

        let outsideTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        outsideTap.cancelsTouchesInView = false
        addGestureRecognizer(outsideTap)
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @discardableResult
    func dismissIfOutside(point: CGPoint) -> Bool {
        guard !panelFrame.contains(point) else { return false }
        onDismiss?()
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    @objc private func selectedVariant(_ button: UIButton) {
        guard variants.indices.contains(button.tag) else { return }
        onSelect?(variants[button.tag].sequence)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        _ = dismissIfOutside(point: recognizer.location(in: self))
    }

    private func applyTheme() {
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        backgroundColor = UIColor.black.withAlphaComponent(0.12)
        panelView.backgroundColor = palette.background
        for button in variantButtons {
            button.backgroundColor = palette.plainFill
            button.setTitleColor(palette.text, for: .normal)
            button.layer.cornerRadius = 7
        }
    }
}
