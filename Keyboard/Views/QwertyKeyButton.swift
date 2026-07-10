import UIKit

/// One QWERTY key. Styling approximates the system keyboard's light/dark key colors — the
/// exact values are re-measured against the native keyboard in the Phase-3 screenshot-diff
/// parity gate (plan §0.1) — and otherwise follows the numpad's own key language (`Cell`/
/// `Button`): flat theme-colored fills, a `Keyboard.hasRoundedCorners`-gated corner radius and
/// edge line (never an Android-style floating drop shadow), Dynamic-Type/iPad-scaled labels,
/// and the same press micro-interaction.
final class QwertyKeyButton: UIButton {

    let key: QwertyKey

    /// Special keys (shift, backspace, layer switches, globe, return) use the darker
    /// system-special-key fill; character keys and space use the plain key fill.
    private var isSpecialKey: Bool {
        switch key.kind {
        case .character, .space, .dateTimeToken, .snippet:
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
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet {
            applyColors()
            guard oldValue != isHighlighted else { return }
            applyKeyPressAnimation(pressed: isHighlighted)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    func setGlyph(_ systemName: String, pointSize: CGFloat = 18) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize * KeyMetrics.keyLabelFontScale, weight: .regular)
        setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        setTitle(nil, for: .normal)
    }

    func setLabel(_ text: String, pointSize: CGFloat = 22) {
        setImage(nil, for: .normal)
        setTitle(text, for: .normal)
        titleLabel?.font = Self.scaledFont(size: pointSize)
        titleLabel?.adjustsFontForContentSizeCategory = true
    }

    /// Dynamic-Type-scaled, iPad-enlarged system font — the same treatment `Cell` gives every
    /// numpad key label (`KeyMetrics.scaledFont` + `adjustsFontForContentSizeCategory`), so key
    /// caps grow with the user's text size and idiom exactly like the numpad's do.
    private static func scaledFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        return KeyMetrics.scaledFont(UIFontMetrics(forTextStyle: .callout).scaledFont(for: base))
    }

    /// Theme-aware colors: white/black resolve to the system-parity palettes (§0.1); other
    /// themes tint keys with their color, matching the numpad's explicit-theme semantics
    /// (`selectedOrAutomatic` handles the automatic-dark-mode mapping — hence the
    /// `traitCollectionDidChange` re-apply above). Corner radius and the subtle edge line are
    /// gated on `Keyboard.hasRoundedCorners` exactly as `Cell.configure` gates them: flat,
    /// square keys by default, or a rounded keycap with a thin theme-tinted bottom edge (never
    /// an opaque black drop shadow) when the user opts in.
    private func applyColors() {
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        layer.cornerRadius = Keyboard.hasRoundedCorners ? KeyMetrics.cornerRadius : 0
        layer.shadowOpacity = Keyboard.hasRoundedCorners ? 1 : 0
        layer.shadowColor = palette.background.withAlphaComponent(0.5).cgColor
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

    /// Subtle press-down scale/brightness dip + spring release, ported verbatim from the
    /// numpad's own `Button.applyKeyPressAnimation` so both pages feel identical under a
    /// finger. `transform`/`alpha` only — never touches `frame`/`bounds`. Gated on
    /// `FeatureFlags.isKeyPressAnimationActive` and skipped under Reduce Motion, in which case
    /// the instant highlight-color swap above is the whole effect, exactly like the numpad.
    private func applyKeyPressAnimation(pressed: Bool) {
        guard FeatureFlags.isKeyPressAnimationActive, !UIAccessibility.isReduceMotionEnabled else {
            transform = .identity
            alpha = 1
            return
        }
        if pressed {
            UIView.animate(withDuration: 0.05, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: {
                self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
                self.alpha = 0.88
            })
        } else {
            UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.6, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.transform = .identity
                self.alpha = 1
            })
        }
    }
}
