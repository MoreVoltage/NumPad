import UIKit

protocol QwertyKeyboardViewDelegate: AnyObject {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey)
    /// Called once per button as rows are (re)built, so the controller can attach
    /// gesture-level behavior (globe input-mode list, backspace autorepeat).
    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didCreate button: QwertyKeyButton,
                            for key: QwertyKey)
}

/// Renders the QWERTY grid with manual frame layout so key geometry comes *exactly* from
/// `QwertyLayout`'s unit widths — the pure model stays the single source of truth for the
/// parity spec (plan §0.1), and there is no Auto Layout drift to chase.
final class QwertyKeyboardView: UIView {

    private enum Metrics {
        static let edgeInset: CGFloat = 3
        static let keyGap: CGFloat = 6
        static let rowGap: CGFloat = 11
        static let topInset: CGFloat = 6
        static let bottomInset: CGFloat = 4
    }

    weak var delegate: QwertyKeyboardViewDelegate?

    /// Label for the return key, mapped from the host field's `returnKeyType`.
    var returnKeyLabel = "return"

    private var rowLayouts: [QwertyRow] = []
    private var rowButtons: [[QwertyKeyButton]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Configuration

    /// Rebuilds the grid: the swappable top strip (number row / pack row) plus the current
    /// layer's rows.
    func configure(rows: [QwertyRow], topStrip: [QwertyKey]) {
        rowButtons.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rowLayouts = [QwertyRow(keys: topStrip)] + rows
        rowButtons = rowLayouts.map { row in
            row.keys.map { key in
                let button = QwertyKeyButton(key: key)
                button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
                addSubview(button)
                decorate(button, for: key)
                delegate?.qwertyKeyboardView(self, didCreate: button, for: key)
                return button
            }
        }
        setNeedsLayout()
    }

    /// Relabels cased keys and the shift key for the current shift state without rebuilding.
    func update(shiftState: QwertyShiftMachine.State) {
        for button in rowButtons.flatMap({ $0 }) {
            switch button.key.kind {
            case .character(let base, let shifted):
                if shifted != base {
                    button.setLabel(shiftState == .lowercase ? base : shifted)
                }
            case .shift:
                switch shiftState {
                case .lowercase:
                    button.setGlyph("shift")
                    button.showsEngaged = false
                case .shifted:
                    button.setGlyph("shift.fill")
                    button.showsEngaged = true
                case .capsLock:
                    button.setGlyph("capslock.fill")
                    button.showsEngaged = true
                }
            default:
                break
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rowLayouts.isEmpty else { return }

        let usableHeight = bounds.height - Metrics.topInset - Metrics.bottomInset
        let rowSlotHeight = usableHeight / CGFloat(rowLayouts.count)
        let unitWidth = (bounds.width - 2 * Metrics.edgeInset) / CGFloat(QwertyLayout.rowUnitWidth)

        for (rowIndex, row) in rowLayouts.enumerated() {
            let y = Metrics.topInset + CGFloat(rowIndex) * rowSlotHeight + Metrics.rowGap / 2
            let keyHeight = rowSlotHeight - Metrics.rowGap
            var cursorUnits = row.leadingMargin
            for (keyIndex, key) in row.keys.enumerated() {
                let slotX = Metrics.edgeInset + CGFloat(cursorUnits) * unitWidth
                let slotWidth = CGFloat(key.width) * unitWidth
                rowButtons[rowIndex][keyIndex].frame = CGRect(x: slotX + Metrics.keyGap / 2,
                                                              y: y,
                                                              width: slotWidth - Metrics.keyGap,
                                                              height: keyHeight)
                cursorUnits += key.width
            }
        }
    }

    // MARK: - Private

    @objc private func keyTapped(_ button: QwertyKeyButton) {
        delegate?.qwertyKeyboardView(self, didTap: button.key)
    }

    private func decorate(_ button: QwertyKeyButton, for key: QwertyKey) {
        switch key.kind {
        case .character(let base, _):
            button.setLabel(base)
        case .shift:
            button.setGlyph("shift")
        case .backspace:
            button.setGlyph("delete.left")
        case .space:
            button.setLabel(NSLocalizedString("space", comment: "space bar label"), pointSize: 16)
        case .ret:
            button.setLabel(returnKeyLabel, pointSize: 16)
        case .globe:
            button.setGlyph("globe")
        case .layerSwitch(let layer):
            switch layer {
            case .letters: button.setLabel("ABC", pointSize: 16)
            case .symbols: button.setLabel("123", pointSize: 16)
            case .extendedSymbols: button.setLabel("#+=", pointSize: 16)
            }
        case .numpadFlip:
            // Deliberately distinct from both the globe and the "123" layer key — this flips
            // the whole canvas to the full NumPad (plan §2's differentiator).
            button.setGlyph("circle.grid.3x3")
        }
    }
}
