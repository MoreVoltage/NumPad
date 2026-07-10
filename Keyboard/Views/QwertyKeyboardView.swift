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
        static let topInset: CGFloat = 6
        static let bottomInset: CGFloat = 4

        /// Inter-key gap, both axes — identical derivation to the numpad's own
        /// `KeyMetrics.spacing(roundedCorners:grid:)` (`StackView.configure`), so the two
        /// pages' grids read as one design system rather than QWERTY's previous fixed,
        /// system-keyboard-style gap (owner note 3).
        static var keyGap: CGFloat {
            KeyMetrics.spacing(roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid)
        }
        static var rowGap: CGFloat { keyGap }
    }

    weak var delegate: QwertyKeyboardViewDelegate?

    /// Label for the return key, mapped from the host field's `returnKeyType`.
    var returnKeyLabel = "return"

    /// Per-key-index bias for ambiguous gap touches, refreshed by the page host every time
    /// suggestions recompute (`QwertyTouchRouting.bias(forCompletions:currentWord:keyOutputs:)`)
    /// — consumed by `hitTest`. Reset whenever the grid is rebuilt (`configure`/`updateTopStrip`)
    /// since a new key set invalidates old indices; the host repopulates it on the very next
    /// suggestions refresh.
    var touchBias: [Int: CGFloat] = [:]

    private var rowLayouts: [QwertyRow] = []
    private var rowButtons: [[QwertyKeyButton]] = []

    /// The in-bounds magnified-key bubble (KeyboardKit-style). Apple blocks drawing above
    /// the extension's own top edge (technical doc §1), so this stays inside the keyboard
    /// view — and it's iPhone-only, because the native iPad keyboard shows no callouts.
    private let calloutLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        calloutLabel.font = .systemFont(ofSize: 32)
        calloutLabel.textAlignment = .center
        calloutLabel.layer.cornerRadius = 8
        calloutLabel.layer.masksToBounds = true
        calloutLabel.isHidden = true
        addSubview(calloutLabel)
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    /// Canvas color shown in the gaps between keys — the same tone `StackView`'s container
    /// shows behind the numpad's grid (`KeyboardTheme.scheme.border`), so a page switch never
    /// flashes a different backdrop underneath the keys (owner note 3).
    private func applyTheme() {
        backgroundColor = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic).background
    }

    // MARK: - Configuration

    /// Rebuilds the grid: the swappable top strip (number row / pack row) plus the current
    /// layer's rows.
    func configure(rows: [QwertyRow], topStrip: [QwertyKey]) {
        rowButtons.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rowLayouts = [QwertyRow(keys: topStrip)] + rows
        rowButtons = rowLayouts.map { row in
            row.keys.map { makeButton(for: $0) }
        }
        touchBias = [:]
        applyTheme()
        setNeedsLayout()
    }

    /// Swaps only the top strip (pack switch / number-line toggle) without touching the main
    /// key rows — no full-keyboard flash for a strip-only change.
    func updateTopStrip(_ keys: [QwertyKey]) {
        guard !rowLayouts.isEmpty else { return }
        rowButtons[0].forEach { $0.removeFromSuperview() }
        rowLayouts[0] = QwertyRow(keys: keys)
        rowButtons[0] = keys.map { makeButton(for: $0) }
        touchBias = [:]
        setNeedsLayout()
    }

    private func makeButton(for key: QwertyKey) -> QwertyKeyButton {
        let button = QwertyKeyButton(key: key)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        if case .character = key.kind, key.width <= 1.45 {
            // Content keys get the magnified callout; wide keys (space, return) never do.
            button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(keyTouchEnded(_:)),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        addSubview(button)
        decorate(button, for: key)
        delegate?.qwertyKeyboardView(self, didCreate: button, for: key)
        return button
    }

    // MARK: - Zero-dead-zone touch routing (owner note 4)

    /// Routes any touch landing in the visual gap between keys to the nearest key, so there is
    /// no point on the keyboard a press can miss. A direct hit on a button — or on the callout
    /// machinery already wired to it — passes through untouched; only a miss (the container
    /// itself, or `nil` for a touch reported a hair outside `bounds`) gets redirected, and it's
    /// redirected to the actual button object. Because UIKit then delivers the touch to that
    /// real button, every target/gesture already attached to it (long-press repeat on
    /// backspace, the space-bar cursor pan) fires exactly as it would on a direct hit.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        guard result == nil || result === self else { return result }
        let buttons = rowButtons.flatMap { $0 }
        guard !buttons.isEmpty else { return result }
        guard let index = QwertyTouchRouting.keyIndex(at: point,
                                                       keyFrames: buttons.map { $0.frame },
                                                       in: bounds,
                                                       bias: touchBias) else { return result }
        return buttons[index]
    }

    /// Single-character key outputs keyed by the same flattened row/button index `hitTest` and
    /// `touchBias` use. The page host derives `touchBias` from this via
    /// `QwertyTouchRouting.bias(forCompletions:currentWord:keyOutputs:)`; keys whose current
    /// output isn't exactly one character (space, return, multi-character pack keys, …) are
    /// still included here — `bias(forCompletions:...)` itself ignores non-single-character
    /// outputs per its own contract, so no filtering is duplicated here.
    var characterKeyOutputs: [Int: String] {
        var outputs: [Int: String] = [:]
        for (index, button) in rowButtons.flatMap({ $0 }).enumerated() {
            if case .character = button.key.kind, let title = button.title(for: .normal) {
                outputs[index] = title
            }
        }
        return outputs
    }

    // MARK: - Key callout

    @objc private func keyTouchDown(_ button: QwertyKeyButton) {
        // Native iPad keyboards show no key callouts — parity means none here either.
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        calloutLabel.text = button.title(for: .normal)
        calloutLabel.backgroundColor = palette.plainFill
        calloutLabel.textColor = palette.text
        let keyFrame = button.frame
        let size = CGSize(width: max(keyFrame.width * 1.6, 44), height: keyFrame.height * 1.25)
        var frame = CGRect(x: keyFrame.midX - size.width / 2,
                           y: keyFrame.minY - size.height - 4,
                           width: size.width,
                           height: size.height)
        frame.origin.y = max(frame.origin.y, 0)
        frame.origin.x = min(max(frame.origin.x, 2), bounds.width - size.width - 2)
        calloutLabel.frame = frame
        calloutLabel.isHidden = false
        bringSubviewToFront(calloutLabel)
    }

    @objc private func keyTouchEnded(_ button: QwertyKeyButton) {
        calloutLabel.isHidden = true
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
        let keyGap = Metrics.keyGap
        let rowGap = Metrics.rowGap

        for (rowIndex, row) in rowLayouts.enumerated() {
            let y = Metrics.topInset + CGFloat(rowIndex) * rowSlotHeight + rowGap / 2
            let keyHeight = rowSlotHeight - rowGap
            var cursorUnits = row.leadingMargin
            for (keyIndex, key) in row.keys.enumerated() {
                let slotX = Metrics.edgeInset + CGFloat(cursorUnits) * unitWidth
                let slotWidth = CGFloat(key.width) * unitWidth
                rowButtons[rowIndex][keyIndex].frame = CGRect(x: slotX + keyGap / 2,
                                                              y: y,
                                                              width: slotWidth - keyGap,
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
            button.accessibilityLabel = NSLocalizedString("Shift", comment: "shift key")
        case .backspace:
            button.setGlyph("delete.left")
            button.accessibilityLabel = NSLocalizedString("Delete", comment: "backspace key")
        case .space:
            button.setLabel(NSLocalizedString("space", comment: "space bar label"), pointSize: 16)
        case .ret:
            button.setLabel(returnKeyLabel, pointSize: 16)
        case .globe:
            button.setGlyph("globe")
            button.accessibilityLabel = NSLocalizedString("Next keyboard", comment: "globe key")
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
            button.accessibilityLabel = NSLocalizedString("NumPad", comment: "numpad flip key")
        case .packSwitch:
            // The same pack-switch identity the numpad keyboard uses — never a second globe.
            button.setGlyph(KeyGlyph.packSwitch, pointSize: 15)
            button.accessibilityLabel = NSLocalizedString("Switch pack", comment: "pack switch key")
        case .dateTimeToken(let label, _):
            button.setLabel(label, pointSize: 14)
        case .dismissKeyboard:
            button.setGlyph("keyboard.chevron.compact.down")
            button.accessibilityLabel = NSLocalizedString("Hide keyboard", comment: "dismiss keyboard key")
        }
    }
}
