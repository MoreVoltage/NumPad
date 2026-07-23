import UIKit

protocol QwertySuggestionBarViewDelegate: AnyObject {
    func suggestionBar(_ bar: QwertySuggestionBarView,
                       didSelect suggestion: QwertyAutocorrect.Suggestion)
}

/// The keyboard's own suggestion strip. Always renders three stable slots; empty slots are
/// noninteractive placeholders so widths never jump when suggestions appear or clear.
final class QwertySuggestionBarView: UIView {

    weak var delegate: QwertySuggestionBarViewDelegate?

    private var suggestions: [QwertyAutocorrect.Suggestion] = [.empty, .empty, .empty]
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

    func show(_ suggestions: [QwertyAutocorrect.Suggestion]) {
        var slots = suggestions
        while slots.count < 3 { slots.append(.empty) }
        self.suggestions = Array(slots.prefix(3))
        applyTheme()
        rebuild()
    }

    func clear() {
        show([.empty, .empty, .empty])
    }

    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        separators.forEach { $0.removeFromSuperview() }
        buttons = []
        separators = []

        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        for (index, suggestion) in suggestions.enumerated() {
            let button = UIButton(type: .system)
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
        guard suggestions.indices.contains(button.tag) else { return }
        let suggestion = suggestions[button.tag]
        guard suggestion != .empty else { return }
        delegate?.suggestionBar(self, didSelect: suggestion)
    }
}
