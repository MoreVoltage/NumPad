//
//  MathPreviewChipView.swift
//  Keyboard
//
//  The floating "= result" capsule for the Live Math Preview feature. It is added to the input
//  view as the very last subview (after the key grid), so it always draws on top without ever
//  participating in StackView's layout — it can never steal keyboard height or shift the grid.
//

import UIKit

protocol MathPreviewChipViewDelegate: AnyObject {
    func mathPreviewChipViewDidTapInsert(_ view: MathPreviewChipView)
}

final class MathPreviewChipView: UIView {
    weak var delegate: MathPreviewChipViewDelegate?
    var onUserActivity: (() -> Void)?

    private let label: UILabel = {
        let label = UILabel()
        label.font = KeyMetrics.scaledFont(.systemFont(ofSize: 15, weight: .semibold))
        label.isAccessibilityElement = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        clipsToBounds = false
        isAccessibilityElement = true
        accessibilityTraits = .button

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = bounds.height / 2
    }

    /// A dedicated layer (rather than `backgroundColor` + `layer.shadow*`) so the capsule can cast
    /// a soft shadow without clipping the corners — `clipsToBounds` stays false for the shadow, and
    /// this sublayer supplies the actual fill.
    private lazy var backgroundLayer: CALayer = {
        let layer = CALayer()
        self.layer.insertSublayer(layer, at: 0)
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.25
        self.layer.shadowRadius = 4
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        return layer
    }()

    /// Colors from the active keyboard theme's "secondary" style — the same accent used by the
    /// return key — so the chip reads as an integrated part of the keyboard on every theme.
    func applyTheme() {
        let scheme = Item.Style.secondary.scheme
        backgroundLayer.backgroundColor = scheme.background.cgColor
        label.textColor = scheme.control
    }

    /// `displayText` is what's shown (may be grouped, e.g. "1,234.5"); VoiceOver announces it too.
    func setResultText(_ displayText: String) {
        label.text = String(format: NSLocalizedString("= %@", comment: "Live Math Preview chip label — %@ is the computed result"), displayText)
        accessibilityLabel = String(format: NSLocalizedString("Insert calculated result, %@", comment: "VoiceOver label for the Live Math Preview chip"), displayText)
    }

    @objc private func tapped() {
        onUserActivity?()
        delegate?.mathPreviewChipViewDidTapInsert(self)
    }
}
