//
//  LockedTapHintView.swift
//  Keyboard
//
//  Transient pill shown after a locked tap ("Open the NumPad app to unlock this."). Same look as
//  the What's New / math preview chips. It ignores touches, so the keys under it stay tappable,
//  and it fades out after `LockedTapResponse.hintDisplayDuration`.
//

import UIKit

final class LockedTapHintView: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.font = KeyMetrics.scaledFont(.systemFont(ofSize: 13, weight: .semibold))
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }()

    private let backgroundLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.insertSublayer(backgroundLayer, at: 0)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = bounds.height / 2
    }

    func setMessage(_ message: String) {
        label.text = message
    }

    func applyTheme() {
        let scheme = Item.Style.secondary.scheme
        backgroundLayer.backgroundColor = scheme.background.cgColor
        label.textColor = scheme.control
    }
}
