import UIKit

/// The optional iPad-only first-install choice. The surrounding onboarding controller owns flow
/// progression and Store presentation so this view remains a focused, testable selection surface.
final class OnboardingHeightViewController: UIViewController {
    var onSelected: ((KeyboardHeightPreset) -> Void)?
    var onProRequested: (() -> Void)?

    private let selection: OnboardingHeightSelection
    private var choiceButtons: [KeyboardHeightPreset: UIButton] = [:]

    init(selection: OnboardingHeightSelection = OnboardingHeightSelection()) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        selection = OnboardingHeightSelection()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let heading = UILabel()
        heading.text = NSLocalizedString("How tall should your NumPad be?", comment: "iPad onboarding keyboard height heading")
        heading.font = .preferredFont(for: .title1, weight: .bold)
        heading.textAlignment = .center
        heading.numberOfLines = 0
        heading.adjustsFontForContentSizeCategory = true

        let body = UILabel()
        body.text = NSLocalizedString("Choose a visual size now. You can change it later in Size & feel.", comment: "iPad onboarding keyboard height explanation")
        body.font = .preferredFont(forTextStyle: .body)
        body.textColor = .secondaryLabel
        body.textAlignment = .center
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let choices = UIStackView()
        choices.axis = .vertical
        choices.spacing = 12
        for preset in [KeyboardHeightPreset.small, .regular, .tall, .kiosk] {
            choices.addArrangedSubview(makeChoice(for: preset))
        }

        let stack = UIStackView(arrangedSubviews: [heading, body, choices])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 84),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -64)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshChoices()
    }

    func skip() { selection.skip() }

    private func makeChoice(for preset: KeyboardHeightPreset) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title(for: preset)
        configuration.subtitle = subtitle(for: preset)
        configuration.image = sampleImage(for: preset)
        configuration.imagePlacement = .leading
        configuration.imagePadding = 14
        configuration.titleAlignment = .leading
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 14, leading: 18, bottom: 14, trailing: 18)

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .preferredFont(for: .headline, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityIdentifier = "onboarding.height.\(preset.rawValue)"
        button.accessibilityLabel = preset == .kiosk
            ? NSLocalizedString("Kiosk, Pro", comment: "iPad onboarding locked Kiosk height")
            : title(for: preset)
        button.accessibilityHint = subtitle(for: preset)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.select(preset) }, for: .touchUpInside)
        choiceButtons[preset] = button
        return button
    }

    private func select(_ preset: KeyboardHeightPreset) {
        switch selection.select(preset) {
        case .selected:
            onSelected?(preset)
        case .requiresPro:
            onProRequested?()
        }
    }

    private func refreshChoices() {
        for (preset, button) in choiceButtons {
            var configuration = button.configuration
            configuration?.showsActivityIndicator = false
            configuration?.image = sampleImage(for: preset)
            button.configuration = configuration
            // A locked Kiosk choice remains actionable: it opens the Pro surface rather than
            // behaving as a disabled control to VoiceOver users.
            button.accessibilityTraits = .button
        }
    }

    /// A deliberately labelled miniature keyboard sample. Only this chooser is allowed to show a
    /// keyboard-shaped sample away from the permanent Studio dock.
    private func sampleImage(for preset: KeyboardHeightPreset) -> UIImage {
        let keyHeight: CGFloat
        switch preset {
        case .small: keyHeight = 9
        case .regular: keyHeight = 13
        case .tall: keyHeight = 17
        case .kiosk: keyHeight = 21
        }
        let size = CGSize(width: 54, height: keyHeight * 2 + 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let spacing: CGFloat = 3
            let keyWidth = (size.width - spacing * 2) / 3
            for row in 0..<2 {
                for column in 0..<3 {
                    let frame = CGRect(
                        x: CGFloat(column) * (keyWidth + spacing),
                        y: CGFloat(row) * (keyHeight + spacing),
                        width: keyWidth,
                        height: keyHeight
                    )
                    UIBezierPath(roundedRect: frame, cornerRadius: 3).fill()
                }
            }
        }
    }

    private func title(for preset: KeyboardHeightPreset) -> String {
        switch preset {
        case .small: return NSLocalizedString("Compact", comment: "iPad onboarding compact keyboard height")
        case .regular: return NSLocalizedString("Regular", comment: "iPad onboarding regular keyboard height")
        case .tall: return NSLocalizedString("Tall", comment: "iPad onboarding tall keyboard height")
        case .kiosk: return NSLocalizedString("Kiosk · Pro", comment: "iPad onboarding Pro Kiosk height")
        }
    }

    private func subtitle(for preset: KeyboardHeightPreset) -> String {
        switch preset {
        case .small: return NSLocalizedString("Compact visual sample — more room above", comment: "iPad onboarding compact height sample")
        case .regular: return NSLocalizedString("Regular visual sample — balanced for daily use", comment: "iPad onboarding regular height sample")
        case .tall: return NSLocalizedString("Tall visual sample — larger keys", comment: "iPad onboarding tall height sample")
        case .kiosk: return NSLocalizedString("Kiosk visual sample — extra tall for shared-use stations", comment: "iPad onboarding Kiosk height sample")
        }
    }
}
