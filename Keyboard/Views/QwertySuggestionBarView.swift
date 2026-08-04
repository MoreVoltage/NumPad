import UIKit

@MainActor
protocol QwertySuggestionBarViewDelegate: AnyObject {
    func suggestionBar(_ bar: QwertySuggestionBarView,
                       didSelect content: QwertySuggestionBarView.State.Content)
}

/// The keyboard's own suggestion strip. Always renders three stable slots; empty slots are
/// noninteractive placeholders so widths never jump when suggestions appear or clear.
final class QwertySuggestionBarView: UIView {
    typealias State = QwertySuggestionBarState

    weak var delegate: QwertySuggestionBarViewDelegate?

    private(set) var state: State = .suggestions([.empty, .empty, .empty])
    private var buttons: [UIButton] = []
    private var separators: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyTheme()
        rebuild()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyTheme()
        rebuild()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        rebuild()
    }

    private func applyTheme() {
        backgroundColor = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic).background
    }

    /// Returns true only when visible typed content changed. The host uses this edge to count
    /// one impression rather than one per duplicate UIKit text-change callback.
    @discardableResult
    func show(_ state: State) -> Bool {
        guard state != self.state else { return false }
        self.state = state
        applyTheme()
        rebuild()
        return true
    }

    @discardableResult
    func show(_ suggestions: [QwertyAutocorrect.Suggestion]) -> Bool {
        show(.suggestions(suggestions))
    }

    @discardableResult
    func clear() -> Bool {
        show([.empty, .empty, .empty])
    }

    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        separators.forEach { $0.removeFromSuperview() }
        buttons = []
        separators = []

        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        for (index, content) in state.slots.enumerated() {
            let button = UIButton(type: .system)
            switch content {
            case .suggestion(let suggestion):
                switch suggestion {
                case .literal(let word):
                    button.setTitle("\u{201C}\(word)\u{201D}", for: .normal)
                    button.isEnabled = true
                    button.isAccessibilityElement = true
                case .candidate(let word):
                    button.setTitle(word, for: .normal)
                    button.isEnabled = true
                    button.isAccessibilityElement = true
                case .empty:
                    button.setTitle("", for: .normal)
                    button.isEnabled = false
                    button.isAccessibilityElement = false
                }
            case .corrected(_, let replacement):
                let label = String(
                    format: NSLocalizedString("Corrected to %@", comment: "Autocorrect marker"),
                    replacement)
                button.setTitle(label, for: .normal)
                button.accessibilityLabel = label
                button.isEnabled = false
                button.isAccessibilityElement = true
            case .undoLiteral(let word):
                let label = String(
                    format: NSLocalizedString("Undo \u{201C}%@\u{201D}", comment: "Autocorrect undo chip"),
                    word)
                button.setTitle(label, for: .normal)
                button.accessibilityLabel = label
                button.accessibilityHint = NSLocalizedString(
                    "Restores the word as typed", comment: "Autocorrect undo hint")
                button.isEnabled = true
                button.isAccessibilityElement = true
            case .empty:
                button.setTitle("", for: .normal)
                button.isEnabled = false
                button.isAccessibilityElement = false
            }
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.6
            button.setTitleColor(palette.text, for: .normal)
            button.tintColor = palette.text
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(button)
            buttons.append(button)

            if index < 2 {
                let separator = UIView()
                separator.backgroundColor = palette.text.withAlphaComponent(0.25)
                addSubview(separator)
                separators.append(separator)
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard buttons.count == 3 else { return }
        let slotWidth = bounds.width / 3
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * slotWidth, y: 0,
                                  width: slotWidth, height: bounds.height)
        }
        for (index, separator) in separators.enumerated() {
            separator.frame = CGRect(x: CGFloat(index + 1) * slotWidth - 0.5,
                                     y: bounds.height * 0.22,
                                     width: 1,
                                     height: bounds.height * 0.56)
        }
    }

    @objc private func tapped(_ button: UIButton) {
        let slots = state.slots
        guard slots.indices.contains(button.tag) else { return }
        let content = slots[button.tag]
        guard content != .empty else { return }
        delegate?.suggestionBar(self, didSelect: content)
    }
}
