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
        case .character, .space:
            return false
        case .shift, .backspace, .globe, .layerSwitch, .ret, .numpadFlip:
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

    private func applyColors() {
        let dark = traitCollection.userInterfaceStyle == .dark
        let plainFill = dark ? UIColor(white: 0.42, alpha: 1) : .white
        let specialFill = dark ? UIColor(white: 0.28, alpha: 1)
                               : UIColor(red: 0.68, green: 0.71, blue: 0.75, alpha: 1)
        let engagedFill = dark ? UIColor.white : UIColor.white
        let text: UIColor = dark ? .white : .black

        if showsEngaged {
            backgroundColor = engagedFill
            tintColor = .black
            setTitleColor(.black, for: .normal)
        } else {
            var fill = isSpecialKey ? specialFill : plainFill
            if isHighlighted { fill = isSpecialKey ? plainFill : specialFill }
            backgroundColor = fill
            tintColor = text
            setTitleColor(text, for: .normal)
        }
    }
}
