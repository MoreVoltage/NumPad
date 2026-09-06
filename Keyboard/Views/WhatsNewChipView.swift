//
//  WhatsNewChipView.swift
//  Keyboard
//
//  Small top-of-keyboard chip that opens the 2.0.3 What's New recap in the container app.
//  Separate from MathPreviewChipView. Hidden once the container marks the recap seen.
//

import UIKit

protocol WhatsNewChipViewDelegate: AnyObject {
    func whatsNewChipViewDidTap(_ view: WhatsNewChipView)
}

final class WhatsNewChipView: UIView {
    weak var delegate: WhatsNewChipViewDelegate?

    private let label: UILabel = {
        let label = UILabel()
        label.font = KeyMetrics.scaledFont(.systemFont(ofSize: 13, weight: .semibold))
        label.text = NSLocalizedString("What's New", comment: "Keyboard 2.0.3 What's New chip label")
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
        accessibilityLabel = NSLocalizedString(
            "What's New. Opens NumPad to see this update and turn on a reminder.",
            comment: "VoiceOver label for the 2.0.3 What's New keyboard chip"
        )

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

    private lazy var backgroundLayer: CALayer = {
        let layer = CALayer()
        self.layer.insertSublayer(layer, at: 0)
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.25
        self.layer.shadowRadius = 4
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        return layer
    }()

    func applyTheme() {
        let scheme = Item.Style.secondary.scheme
        backgroundLayer.backgroundColor = scheme.background.cgColor
        label.textColor = scheme.control
    }

    @objc private func tapped() {
        delegate?.whatsNewChipViewDidTap(self)
    }
}
