//
//  LockedTapHintView.swift
//  Keyboard
//
//  Transient pill shown after a locked tap ("Open the NumPad app to unlock this."). Same look as
//  the What's New / math preview chips. It ignores touches, so the keys under it stay tappable,
//  and it fades out after `LockedTapResponse.hintDisplayDuration`.
//
//  Sizing (`LockedTapHintLayout`): up to two lines, hugging the text, at most 300 pt wide and
//  centered by the controller. The height cap follows the current (Dynamic Type scaled) font, so
//  longer translations and larger text wrap onto a second line instead of truncating.
//

import UIKit

final class LockedTapHintView: UIView {
    /// Upper bound for Dynamic Type so two lines stay a compact strip over the top row.
    private static let maximumPointSize: CGFloat = 19

    private let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = LockedTapHintLayout.maxLines
        label.lineBreakMode = .byTruncatingTail
        // Last resort only, after wrapping to the second line.
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.preferredMaxLayoutWidth = LockedTapHintLayout.maxWidth - 2 * LockedTapHintLayout.horizontalPadding
        return label
    }()

    private let backgroundLayer = CALayer()
    private var heightCap: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Touches pass straight through to whatever is underneath (keys, never a chip: the
        // controller keeps both chips hidden while the hint is up).
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.insertSublayer(backgroundLayer, at: 0)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        let cap = heightAnchor.constraint(lessThanOrEqualToConstant: LockedTapHintLayout.minHeight)
        heightCap = cap
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LockedTapHintLayout.horizontalPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LockedTapHintLayout.horizontalPadding),
            label.topAnchor.constraint(equalTo: topAnchor, constant: LockedTapHintLayout.verticalPadding),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -LockedTapHintLayout.verticalPadding),
            heightAnchor.constraint(greaterThanOrEqualToConstant: LockedTapHintLayout.minHeight),
            cap
        ])
        updateFont()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame = bounds
        // Capsule on one line; a rounded rectangle (not a lozenge) when wrapped to two.
        backgroundLayer.cornerRadius = min(bounds.height, LockedTapHintLayout.minHeight) / 2
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateFont()
        }
    }

    func setMessage(_ message: String) {
        label.text = message
    }

    func applyTheme() {
        let scheme = Item.Style.secondary.scheme
        backgroundLayer.backgroundColor = scheme.background.cgColor
        label.textColor = scheme.control
    }

    /// Scale with Dynamic Type (bounded), then re-derive the two-line height cap from the font.
    private func updateFont() {
        let base = KeyMetrics.scaledFont(.systemFont(ofSize: 13, weight: .semibold))
        let font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: base, maximumPointSize: KeyMetrics.scaledFont(base.withSize(Self.maximumPointSize)).pointSize,
                        compatibleWith: traitCollection)
        label.font = font
        heightCap?.constant = max(LockedTapHintLayout.minHeight,
                                  ceil(LockedTapHintLayout.maxHeight(lineHeight: font.lineHeight)))
    }
}
