//
//  StudioNavigationFactory.swift
//  NumPad
//

import UIKit

enum StudioNavigationFactory {
    static func makePhoneShell() -> StudioTabBarController {
        let keyboard = navigation(
            root: KeyboardStudioViewController(),
            title: NSLocalizedString("Keyboard", comment: "Keyboard Studio tab title"),
            symbol: "keyboard",
            accessibilityIdentifier: "studio.tab.keyboard"
        )
        let features = navigation(
            root: FeaturesStudioViewController(),
            title: NSLocalizedString("Features", comment: "Keyboard Studio tab title"),
            symbol: "square.grid.2x2",
            accessibilityIdentifier: "studio.tab.features"
        )
        let help = navigation(
            root: HelpStudioViewController(),
            title: NSLocalizedString("Help", comment: "Keyboard Studio tab title"),
            symbol: "questionmark.circle",
            accessibilityIdentifier: "studio.tab.help"
        )

        let shell = StudioTabBarController()
        shell.viewControllers = [keyboard, features, help]
        shell.selectedIndex = 0
        return shell
    }

    static func makeAdvancedNavigationController() -> UINavigationController {
        let navigation = UINavigationController(rootViewController: AdvancedStudioViewController())
        navigation.modalPresentationStyle = .pageSheet
        return navigation
    }

    private static func navigation(
        root: UIViewController,
        title: String,
        symbol: String,
        accessibilityIdentifier: String
    ) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: symbol),
            selectedImage: UIImage(systemName: symbol + ".fill")
        )
        navigation.tabBarItem.accessibilityIdentifier = accessibilityIdentifier
        return navigation
    }
}

/// Small common scroll layout for the first Studio surfaces. It deliberately contains no settings
/// state: concrete controllers route to the established feature controllers that own it.
class StudioScreenViewController: UIViewController {
    let palette: StudioPalette
    let scrollView = UIScrollView()
    let contentStack = UIStackView()

    init(palette: StudioPalette = .standard) {
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        palette = .standard
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = palette.surface

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "studio.scroll"
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = StudioMetrics.Spacing.xl
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: StudioMetrics.Spacing.xl,
            leading: StudioMetrics.Spacing.m,
            bottom: StudioMetrics.Spacing.xxl,
            trailing: StudioMetrics.Spacing.m
        )
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    func addSection(title: String, rows: [StudioRowView]) {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.translatesAutoresizingMaskIntoConstraints = false
        section.addArrangedSubview(StudioSectionLabel(text: title, palette: palette))

        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = 0
        for (index, row) in rows.enumerated() {
            card.addArrangedSubview(row)
            if index < rows.count - 1 { card.addArrangedSubview(card.makeDivider()) }
        }
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }

    func removeContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    func studioRow(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> StudioRowView {
        let row = StudioRowView(
            title: title,
            subtitle: subtitle,
            symbolName: symbol,
            accessory: .disclosure,
            palette: palette
        )
        row.onTap = action
        return row
    }
}
