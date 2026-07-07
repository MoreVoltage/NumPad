import UIKit

/// Full-canvas overlay shown when NumPad Type isn't usable: not Pro-entitled (plan §5 — the
/// keyboard is a Pro feature) or remotely killed (plan §4). Always carries its own globe key
/// wired to `handleInputModeList` by the controller — a locked keyboard must never trap the
/// user with no way to switch away.
final class QwertyLockedOverlayView: UIView {

    enum Reason {
        case proRequired
        case remotelyDisabled
    }

    /// The controller wires this to `handleInputModeList(from:with:)`.
    let globeButton = UIButton(type: .system)

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(reason: Reason) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground

        let iconName: String
        switch reason {
        case .proRequired:
            iconName = "lock.fill"
            titleLabel.text = NSLocalizedString("NumPad Type is a Pro feature",
                                                comment: "Locked QWERTY keyboard title")
            subtitleLabel.text = NSLocalizedString("Unlock it with NumPad Pro in the NumPad app.",
                                                   comment: "Locked QWERTY keyboard subtitle")
        case .remotelyDisabled:
            iconName = "wrench.and.screwdriver.fill"
            titleLabel.text = NSLocalizedString("NumPad Type is temporarily unavailable",
                                                comment: "Remotely disabled QWERTY keyboard title")
            subtitleLabel.text = NSLocalizedString("Please use another keyboard for now.",
                                                   comment: "Remotely disabled QWERTY keyboard subtitle")
        }

        iconView.image = UIImage(systemName: iconName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 28))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = .label

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        addSubview(stack)
        addSubview(globeButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            globeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            globeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            globeButton.widthAnchor.constraint(equalToConstant: 44),
            globeButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
