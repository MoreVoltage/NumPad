import UIKit

/// Accessible query status shown while the existing QWERTY surface captures emoji search.
final class EmojiSearchHeaderView: UIView {
    let queryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString("Emoji search", comment: "emoji search header")

        queryLabel.font = .preferredFont(forTextStyle: .headline)
        queryLabel.adjustsFontForContentSizeCategory = true
        queryLabel.lineBreakMode = .byTruncatingHead
        queryLabel.textAlignment = .center
        queryLabel.isAccessibilityElement = false
        addSubview(queryLabel)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString("Emoji search", comment: "emoji search header")
        queryLabel.font = .preferredFont(forTextStyle: .headline)
        queryLabel.adjustsFontForContentSizeCategory = true
        queryLabel.lineBreakMode = .byTruncatingHead
        queryLabel.textAlignment = .center
        queryLabel.isAccessibilityElement = false
        addSubview(queryLabel)
        applyTheme()
    }

    func update(query: String) {
        queryLabel.text = query
        accessibilityValue = query
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        queryLabel.frame = bounds.insetBy(dx: 8, dy: 4)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        backgroundColor = palette.background
        queryLabel.textColor = palette.text
    }
}
