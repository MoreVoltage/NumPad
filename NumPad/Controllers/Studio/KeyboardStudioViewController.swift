//
//  KeyboardStudioViewController.swift
//  NumPad
//

import UIKit

final class KeyboardStudioViewController: StudioScreenViewController {
    private let keyboardReady: () -> Bool
    private let onAdvancedRequested: (() -> Void)?
    private let previewModel: (UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel
    private let lettersAvailable: () -> Bool
    private var didLogOpen = false
    private var statusHero: StudioStatusHeroView?
    private(set) var preview: StudioKeyboardPreviewView?
    private var quickChangesCard: StudioCard?
    private var lettersQuickChangeVisible: Bool?
    private var isObservingSettings = false
    private var entitlementObserver: NSObjectProtocol?

    init(
        keyboardReady: @escaping () -> Bool = { Keyboard.isKeyboardEnabled },
        onAdvancedRequested: (() -> Void)? = nil,
        previewModel: @escaping (UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel = { .current(idiom: $0) },
        lettersAvailable: @escaping () -> Bool = { FeatureFlags.isQwertyPageAvailable }
    ) {
        self.keyboardReady = keyboardReady
        self.onAdvancedRequested = onAdvancedRequested
        self.previewModel = previewModel
        self.lettersAvailable = lettersAvailable
        super.init()
    }

    required init?(coder: NSCoder) {
        keyboardReady = { Keyboard.isKeyboardEnabled }
        onAdvancedRequested = nil
        previewModel = { .current(idiom: $0) }
        lettersAvailable = { FeatureFlags.isQwertyPageAvailable }
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Keyboard", comment: "Keyboard Studio title")
        view.accessibilityIdentifier = "studio.keyboard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openAdvanced)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "studio.keyboard.advanced"

        let hero = StudioStatusHeroView(level: .warn, title: "", palette: palette)
        hero.accessibilityIdentifier = "studio.keyboard.status"
        hero.onAction = { [weak self] in
            self?.navigationController?.pushViewController(InstructionsViewController.instantiate(), animated: true)
        }
        contentStack.addArrangedSubview(hero)
        statusHero = hero
        refreshReadiness(announce: false)

        let preview = StudioKeyboardPreviewView(
            model: previewModel(traitCollection.userInterfaceIdiom),
            palette: palette
        )
        preview.setCaption(
            leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"),
            trailing: nil
        )
        preview.accessibilityIdentifier = "studio.keyboard.preview"
        contentStack.addArrangedSubview(preview)
        self.preview = preview

        let tryIt = UITextField()
        tryIt.translatesAutoresizingMaskIntoConstraints = false
        tryIt.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Keyboard Studio Try It placeholder")
        tryIt.borderStyle = .roundedRect
        tryIt.backgroundColor = palette.surfaceElevated
        tryIt.accessibilityIdentifier = "studio.keyboard.try-it"
        tryIt.heightAnchor.constraint(greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget).isActive = true
        contentStack.addArrangedSubview(tryIt)

        buildQuickChangesSection()
        entitlementObserver = NotificationCenter.default.addObserver(
            forName: StoreManager.entitlementsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPresentation()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if traitCollection.userInterfaceIdiom == .pad { StudioPreviewContext.request(.lastUsedPage) }
        observeSettingsIfNeeded()
        refreshPresentation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if view.window == nil { stopObservingSettings() }
    }

    deinit {
        stopObservingSettings()
        if let entitlementObserver { NotificationCenter.default.removeObserver(entitlementObserver) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didLogOpen else { return }
        didLogOpen = true
        Analytics.logEvent(name: "studio_opened", attributes: ["surface": "keyboard"])
    }

    @objc private func openAdvanced() {
        if let onAdvancedRequested {
            onAdvancedRequested()
            return
        }
        Analytics.logEvent(name: "advanced_opened", attributes: ["source": "keyboard_gear"])
        present(StudioNavigationFactory.makeAdvancedNavigationController(), animated: true)
    }

    private func openQuickChange(_ controller: UIViewController, destination: String) {
        Analytics.logEvent(name: "quick_change_opened", attributes: ["source": "keyboard_studio", "state": destination])
        navigationController?.pushViewController(controller, animated: true)
    }

    private func refreshReadiness(announce: Bool = true) {
        let ready = presentationKeyboardReady
        statusHero?.actionAccessibilityIdentifier = ready ? nil : "studio.keyboard.openSetup"
        statusHero?.update(
            level: ready ? .ok : .warn,
            title: ready
                ? NSLocalizedString("Your keyboard is ready", comment: "Keyboard Studio ready title")
                : NSLocalizedString("Finish setting up NumPad", comment: "Keyboard Studio repair title"),
            message: ready
                ? NSLocalizedString("Choose an option below whenever you want a change.", comment: "Keyboard Studio ready message")
                : NSLocalizedString("Add NumPad in Settings before you use it in other apps.", comment: "Keyboard Studio repair message"),
            actionTitle: ready ? nil : NSLocalizedString("Open setup", comment: "Keyboard Studio repair action"),
            announce: announce
        )
    }

    private func refreshPresentation() {
        refreshReadiness()
        preview?.model = previewModel(traitCollection.userInterfaceIdiom)
        refreshQuickChangesIfNeeded()
    }

    private func buildQuickChangesSection() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.translatesAutoresizingMaskIntoConstraints = false
        section.addArrangedSubview(StudioSectionLabel(
            text: NSLocalizedString("QUICK CHANGES", comment: "Keyboard Studio section label"),
            palette: palette
        ))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = 0
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
        quickChangesCard = card
        refreshQuickChangesIfNeeded(force: true)
    }

    private func refreshQuickChangesIfNeeded(force: Bool = false) {
        let shouldShowLetters = lettersAvailable()
        guard force || lettersQuickChangeVisible != shouldShowLetters, let quickChangesCard else { return }
        lettersQuickChangeVisible = shouldShowLetters
        quickChangesCard.removeAllArrangedSubviews()
        var rows = [quickChangeRow(
            title: NSLocalizedString("Appearance", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Theme, dark appearance, key shape, and grid", comment: "Keyboard Studio quick change description"),
            symbol: "paintpalette",
            destination: "appearance",
            controller: AppearanceStudioViewController()
        ), quickChangeRow(
            title: NSLocalizedString("Choose keys", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Numbers, calculations, prices, and more", comment: "Keyboard Studio quick change description"),
            symbol: "plus.rectangle.on.rectangle",
            destination: "choose_keys",
            controller: KeySetStudioViewController()
        ), quickChangeRow(
            title: NSLocalizedString("Size & feel", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Height, number order, sound, and vibration", comment: "Keyboard Studio quick change description"),
            symbol: "hand.tap",
            destination: "size_feel",
            controller: SizeAndFeelStudioViewController()
        )]
        rows[0].accessibilityIdentifier = "studio.keyboard.appearance"
        rows[1].accessibilityIdentifier = "studio.keyboard.choose-keys"
        rows[2].accessibilityIdentifier = "studio.keyboard.size-feel"
        if shouldShowLetters {
            let letters = quickChangeRow(
                title: NSLocalizedString("Letters", comment: "Keyboard Studio quick change action"),
                subtitle: NSLocalizedString("Set up the letters page", comment: "Keyboard Studio quick change description"),
                symbol: "textformat",
                destination: "letters",
                controller: LettersStudioViewController()
            )
            letters.accessibilityIdentifier = "studio.keyboard.letters"
            rows.append(letters)
        }
        for (index, row) in rows.enumerated() {
            quickChangesCard.addArrangedSubview(row)
            if index < rows.count - 1 { quickChangesCard.addArrangedSubview(quickChangesCard.makeDivider()) }
        }
    }

    private func quickChangeRow(
        title: String,
        subtitle: String,
        symbol: String,
        destination: String,
        controller: UIViewController
    ) -> StudioRowView {
        studioRow(title: title, subtitle: subtitle, symbol: symbol) { [weak self] in
            self?.openQuickChange(controller, destination: destination)
        }
    }

    private func observeSettingsIfNeeded() {
        guard !isObservingSettings else { return }
        isObservingSettings = true
        SettingsSync.observe(self) { [weak self] in self?.refreshPresentation() }
    }

    private func stopObservingSettings() {
        guard isObservingSettings else { return }
        SettingsSync.remove(self)
        isObservingSettings = false
    }

    private var presentationKeyboardReady: Bool {
#if DEBUG
        if let override = debugKeyboardReadyOverride {
            return override
        }
#endif
        return keyboardReady()
    }

#if DEBUG
    /// UI-test-only presentation override. It never writes settings and is compiled out of release.
    private var debugKeyboardReadyOverride: Bool? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-debugStudioKeyboardReady"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        switch arguments[index + 1] {
        case "1": return true
        case "0": return false
        default: return nil
        }
    }
#endif
}
