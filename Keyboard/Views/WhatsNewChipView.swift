import UIKit

protocol WhatsNewChipViewDelegate: AnyObject {
    func whatsNewChipViewDidTap(_ view: WhatsNewChipView)
    func whatsNewChipViewDidDismiss(_ view: WhatsNewChipView)
}

/// Separate controls ensure closing the banner never opens the app or requests permission.
final class WhatsNewChipView: UIView {
    weak var delegate: WhatsNewChipViewDelegate?

    private let openButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        openButton.setTitle(NSLocalizedString("What's New", comment: "Keyboard update banner"), for: .normal)
        openButton.titleLabel?.font = KeyMetrics.scaledFont(.systemFont(ofSize: 13, weight: .semibold))
        openButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 4)
        openButton.accessibilityIdentifier = "whatsnew.banner.open"
        openButton.accessibilityHint = NSLocalizedString(
            "Opens NumPad to see this update and choose notification permission.",
            comment: "Update banner open action")
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        dismissButton.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        dismissButton.accessibilityIdentifier = "whatsnew.banner.dismiss"
        dismissButton.accessibilityLabel = NSLocalizedString("Dismiss What's New banner",
            comment: "Update banner dismiss action")
        dismissButton.accessibilityHint = NSLocalizedString("Removes this banner from the keyboard.",
            comment: "Update banner dismiss hint")
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [openButton, dismissButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            openButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            dismissButton.widthAnchor.constraint(equalToConstant: 44)
        ])
        accessibilityElements = [openButton, dismissButton]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func applyTheme() {
        let scheme = Item.Style.secondary.scheme
        backgroundColor = scheme.background
        openButton.setTitleColor(scheme.control, for: .normal)
        dismissButton.tintColor = scheme.control
    }

    @objc private func openTapped() { delegate?.whatsNewChipViewDidTap(self) }
    @objc private func dismissTapped() { delegate?.whatsNewChipViewDidDismiss(self) }
}
