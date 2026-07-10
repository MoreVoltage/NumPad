import UIKit

/// One QWERTY key. Styling approximates the system keyboard's light/dark key colors — the
/// exact values are re-measured against the native keyboard in the Phase-3 screenshot-diff
/// parity gate (plan §0.1).
final class QwertyKeyButton: UIButton {

    let key: QwertyKey

    /// Special keys (shift, backspace, layer switches, globe, return) use the darker
    /// system-special-key fill; character keys and space use the plain key fill.
    private var isSpecialKey: Bool {
        switch key.kind {
        case .character, .space, .dateTimeToken:
            return false
        case .shift, .backspace, .globe, .layerSwitch, .ret, .numpadFlip, .packSwitch,
             .dismissKeyboard:
            return true
        }
    }

    /// Highlighted (engaged) rendering for the shift key states.
    var showsEngaged = false {
        didSet { applyColors() }
    }

    init(key: QwertyKey) {
        self.key = key
        super.init(frame: .zero)
        layer.cornerRadius = 5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.30
        layer.shadowRadius = 0
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { applyColors() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    func setGlyph(_ systemName: String, pointSize: CGFloat = 18) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        setTitle(nil, for: .normal)
    }

    func setLabel(_ text: String, pointSize: CGFloat = 22) {
        setImage(nil, for: .normal)
        setTitle(text, for: .normal)
        titleLabel?.font = .systemFont(ofSize: pointSize)
    }

    /// Theme-aware colors: white/black resolve to the system-parity palettes (§0.1); other
    /// themes tint keys with their color, matching the numpad's explicit-theme semantics
    /// (`selectedOrAutomatic` handles the automatic-dark-mode mapping — hence the
    /// `traitCollectionDidChange` re-apply above).
    private func applyColors() {
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        if showsEngaged {
            backgroundColor = .white
            tintColor = .black
            setTitleColor(.black, for: .normal)
        } else {
            var fill = isSpecialKey ? palette.specialFill : palette.plainFill
            if isHighlighted { fill = isSpecialKey ? palette.plainFill : palette.specialFill }
            backgroundColor = fill
            tintColor = palette.text
            setTitleColor(palette.text, for: .normal)
        }
    }
}
