//
//  IPadStudioWorkspaceViewController.swift
//  NumPad
//

import UIKit

/// iPad's Studio presentation.  The destination scroll view is constrained above a separate,
/// safe-area-pinned dock so resizing and destination changes can never turn the keyboard preview
/// into a floating or scroll-away element.
final class IPadStudioWorkspaceViewController: UIViewController {
    enum Destination { case keyboard, features, help, advanced }

    private let palette = StudioPalette.standard
    private let upperContainer = UIView()
    private let navigationRail = UIStackView()
    private let compactDestinationControl = UISegmentedControl(items: [
        NSLocalizedString("Keyboard", comment: "iPad Studio compact destination"),
        NSLocalizedString("Features", comment: "iPad Studio compact destination"),
        NSLocalizedString("Help", comment: "iPad Studio compact destination")
    ])
    private let compactAdvancedButton = UIButton(type: .system)
    private let destinationContainer = UIView()
    private let contentNavigation = UINavigationController()
    let dockView = StudioKeyboardDockView()
    private(set) var upperScrollView: UIScrollView!
    private(set) var settingsObserverRegistrationCount = 0

    private var selectedDestination: Destination = .keyboard
    private var activeDestinationController: StudioScreenViewController?
    private var isObservingSettings = false
    private var entitlementObserver: NSObjectProtocol?
    private var localRefreshObserver: NSObjectProtocol?
    private var previewContextObserver: NSObjectProtocol?
    private var previewContext: StudioPreviewContext = .lastUsedPage
    private var dockHeightConstraint: NSLayoutConstraint!
    private var dockLeadingConstraint: NSLayoutConstraint!
    private var dockTrailingConstraint: NSLayoutConstraint!
    private var upperContainerTopConstraint: NSLayoutConstraint!
    private var destinationLeadingConstraint: NSLayoutConstraint!
    private var destinationTopRegularConstraint: NSLayoutConstraint!
    private var destinationTopCompactConstraint: NSLayoutConstraint!
    private var lastLayout: IPadStudioLayout?
#if DEBUG
    private var debugWorkspaceStackTopConstraint: NSLayoutConstraint?
#endif

    /// Compatibility seam for `DeepLinkRouter`: iPad deep links continue to push into the visible
    /// Studio destination without needing the retired settings split.
    var activeNavigationController: UINavigationController { contentNavigation }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Keyboard", comment: "iPad Studio workspace title")
        view.accessibilityIdentifier = "studio.ipad-workspace"
        view.backgroundColor = palette.surface
        buildChrome()
        select(.keyboard)
        entitlementObserver = NotificationCenter.default.addObserver(
            forName: StoreManager.entitlementsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshWorkspace()
        }
        localRefreshObserver = NotificationCenter.default.addObserver(
            forName: .studioSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshWorkspace()
        }
        previewContextObserver = NotificationCenter.default.addObserver(
            forName: StudioPreviewContext.requestedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let context = notification.object as? StudioPreviewContext else { return }
            self?.previewContext = context
            self?.refreshWorkspace()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observeSettingsIfNeeded()
        refreshWorkspace()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if view.window == nil { stopObservingSettings() }
    }

    deinit {
        stopObservingSettings()
        if let entitlementObserver { NotificationCenter.default.removeObserver(entitlementObserver) }
        if let localRefreshObserver { NotificationCenter.default.removeObserver(localRefreshObserver) }
        if let previewContextObserver { NotificationCenter.default.removeObserver(previewContextObserver) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyResolvedLayoutIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshWorkspace()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass
            || previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
        else { return }
        refreshWorkspace()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.refreshWorkspace() })
    }

    func refreshWorkspace() {
        dockView.refresh(model: studioPreviewModel())
        lastLayout = nil
        activeDestinationController?.view.setNeedsLayout()
        view.setNeedsLayout()
    }

    private func studioPreviewModel() -> StudioKeyboardPreviewModel {
        guard previewContext != .lastUsedPage else { return .current(idiom: .pad) }
        let customKeyboardConfig = Monetization.isCustomKeyboardEntitled
            ? CustomKeyboardStore(defaults: .group).load()
            : nil
        return StudioKeyboardPreviewModel(
            theme: .selectedOrAutomatic,
            pack: .selected,
            heightPreset: KeyboardHeightPreset.effective(
                stored: .selected,
                kioskEntitled: Monetization.isKioskHeightEntitled
            ),
            isReversedMode: Keyboard.isReversedMode,
            hasRoundedCorners: Keyboard.hasRoundedCorners,
            hasGrid: Keyboard.hasGrid,
            qwertyAvailable: FeatureFlags.isQwertyPageAvailable,
            activePage: previewContext == .qwerty ? .qwerty : .numpad,
            idiom: .pad,
            sideKeyCaptions: CustomKeys.slots.map(CustomKeys.displayName),
            customPackKeys: CustomPackManager.shared.keys,
            customKeyboardConfig: customKeyboardConfig,
            handedness: UserPrefs.handedness,
            qwertyPeriodComma: UserPrefs.qwertyPeriodComma
        )
    }

    private func buildChrome() {
        upperContainer.translatesAutoresizingMaskIntoConstraints = false
        destinationContainer.translatesAutoresizingMaskIntoConstraints = false
        navigationRail.translatesAutoresizingMaskIntoConstraints = false
        navigationRail.axis = .vertical
        navigationRail.alignment = .fill
        navigationRail.spacing = StudioMetrics.Spacing.s
        navigationRail.isLayoutMarginsRelativeArrangement = true
        navigationRail.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: StudioMetrics.Spacing.m,
            leading: StudioMetrics.Spacing.m,
            bottom: StudioMetrics.Spacing.m,
            trailing: StudioMetrics.Spacing.m
        )
        navigationRail.backgroundColor = palette.surfaceElevated
        navigationRail.layer.cornerRadius = StudioMetrics.Radius.card
        navigationRail.accessibilityIdentifier = "studio.ipad-navigation"

        navigationRail.addArrangedSubview(makeDestinationButton("Keyboard", symbol: "keyboard", destination: .keyboard))
        navigationRail.addArrangedSubview(makeDestinationButton("Features", symbol: "square.grid.2x2", destination: .features))
        navigationRail.addArrangedSubview(makeDestinationButton("Help", symbol: "questionmark.circle", destination: .help))
        navigationRail.addArrangedSubview(makeAdvancedButton())

        compactDestinationControl.translatesAutoresizingMaskIntoConstraints = false
        compactDestinationControl.accessibilityIdentifier = "studio.ipad.destinations"
        compactDestinationControl.selectedSegmentIndex = 0
        compactDestinationControl.addTarget(self, action: #selector(selectCompactDestination), for: .valueChanged)
        compactAdvancedButton.translatesAutoresizingMaskIntoConstraints = false
        compactAdvancedButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        compactAdvancedButton.accessibilityLabel = NSLocalizedString("Advanced", comment: "iPad Studio compact advanced action")
        compactAdvancedButton.accessibilityIdentifier = "studio.ipad.advanced"
        compactAdvancedButton.addTarget(self, action: #selector(openAdvanced), for: .touchUpInside)

        dockView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(upperContainer)
        view.addSubview(dockView)
        upperContainer.addSubview(navigationRail)
        upperContainer.addSubview(compactDestinationControl)
        upperContainer.addSubview(compactAdvancedButton)
        upperContainer.addSubview(destinationContainer)
        addChild(contentNavigation)
        contentNavigation.view.translatesAutoresizingMaskIntoConstraints = false
        destinationContainer.addSubview(contentNavigation.view)
        contentNavigation.didMove(toParent: self)
        dockHeightConstraint = dockView.heightAnchor.constraint(equalToConstant: 220)
        dockLeadingConstraint = dockView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        dockTrailingConstraint = dockView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        upperContainerTopConstraint = upperContainer.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor
        )
        NSLayoutConstraint.activate([
            upperContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            upperContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            upperContainerTopConstraint,
            upperContainer.bottomAnchor.constraint(equalTo: dockView.topAnchor),
            dockView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            dockHeightConstraint,
            dockLeadingConstraint,
            dockTrailingConstraint,
            navigationRail.leadingAnchor.constraint(equalTo: upperContainer.leadingAnchor, constant: StudioMetrics.Spacing.m),
            navigationRail.topAnchor.constraint(equalTo: upperContainer.topAnchor, constant: StudioMetrics.Spacing.m),
            navigationRail.bottomAnchor.constraint(lessThanOrEqualTo: upperContainer.bottomAnchor, constant: -StudioMetrics.Spacing.m),
            navigationRail.widthAnchor.constraint(equalToConstant: 244),
            destinationContainer.trailingAnchor.constraint(equalTo: upperContainer.trailingAnchor),
            destinationContainer.bottomAnchor.constraint(equalTo: upperContainer.bottomAnchor),
            contentNavigation.view.leadingAnchor.constraint(equalTo: destinationContainer.leadingAnchor),
            contentNavigation.view.trailingAnchor.constraint(equalTo: destinationContainer.trailingAnchor),
            contentNavigation.view.topAnchor.constraint(equalTo: destinationContainer.topAnchor),
            contentNavigation.view.bottomAnchor.constraint(equalTo: destinationContainer.bottomAnchor)
        ])
        destinationLeadingConstraint = destinationContainer.leadingAnchor.constraint(
            equalTo: upperContainer.leadingAnchor
        )
        destinationLeadingConstraint.isActive = true
        destinationTopRegularConstraint = destinationContainer.topAnchor.constraint(
            equalTo: upperContainer.topAnchor
        )
        destinationTopCompactConstraint = destinationContainer.topAnchor.constraint(
            equalTo: compactDestinationControl.bottomAnchor,
            constant: StudioMetrics.Spacing.s
        )
        destinationTopRegularConstraint.isActive = true
        NSLayoutConstraint.activate([
            compactDestinationControl.leadingAnchor.constraint(equalTo: upperContainer.leadingAnchor, constant: StudioMetrics.Spacing.m),
            compactDestinationControl.trailingAnchor.constraint(equalTo: compactAdvancedButton.leadingAnchor, constant: -StudioMetrics.Spacing.s),
            compactDestinationControl.topAnchor.constraint(equalTo: upperContainer.topAnchor, constant: StudioMetrics.Spacing.s),
            compactDestinationControl.heightAnchor.constraint(greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget),
            compactAdvancedButton.trailingAnchor.constraint(equalTo: upperContainer.trailingAnchor, constant: -StudioMetrics.Spacing.m),
            compactAdvancedButton.centerYAnchor.constraint(equalTo: compactDestinationControl.centerYAnchor),
            compactAdvancedButton.widthAnchor.constraint(equalToConstant: StudioMetrics.Size.minTouchTarget),
            compactAdvancedButton.heightAnchor.constraint(equalToConstant: StudioMetrics.Size.minTouchTarget)
        ])
    }

    private func makeDestinationButton(_ title: String, symbol: String, destination: Destination) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = NSLocalizedString(title, comment: "iPad Studio destination")
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "studio.ipad.\(title.lowercased())"
        button.addAction(UIAction { [weak self] _ in self?.select(destination) }, for: .touchUpInside)
        return button
    }

    private func makeAdvancedButton() -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = NSLocalizedString("Advanced", comment: "iPad Studio advanced action")
        configuration.image = UIImage(systemName: "gearshape")
        configuration.imagePadding = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "studio.ipad.rail.advanced"
        button.addTarget(self, action: #selector(openAdvanced), for: .touchUpInside)
        return button
    }

    private func select(_ destination: Destination) {
        guard selectedDestination != destination || activeDestinationController == nil else { return }
        selectedDestination = destination
        let controller: StudioScreenViewController
        switch destination {
        case .keyboard:
            controller = KeyboardStudioViewController(onAdvancedRequested: { [weak self] in
                self?.showAdvanced(source: "keyboard_gear")
            }, showsInlinePreview: false)
        case .features: controller = FeaturesStudioViewController()
        case .help: controller = HelpStudioViewController()
        case .advanced:
            controller = AdvancedStudioViewController(onClose: { [weak self] in self?.select(.keyboard) })
        }
        contentNavigation.setViewControllers([controller], animated: false)
        activeDestinationController = controller
        upperScrollView = controller.scrollView
        // The layout geometry may not change when destinations change, but each destination owns
        // a different scroll view. Reapply its dock-clearance inset rather than leaving the new
        // screen with the previous screen's layout state.
        lastLayout = nil
        refreshWorkspace()
    }

    @objc private func selectCompactDestination() {
        switch compactDestinationControl.selectedSegmentIndex {
        case 1: select(.features)
        case 2: select(.help)
        default: select(.keyboard)
        }
    }

    /// iPad Advanced stays in the upper workspace so its permanent dock remains frontmost and
    /// interactive. Phone Studio continues to present its own page-sheet flow.
    func showAdvanced(source: String = "workspace") {
        Analytics.logEvent(name: "advanced_opened", attributes: ["source": source])
        select(.advanced)
    }

    @objc private func openAdvanced() {
        showAdvanced()
    }

    private func applyResolvedLayoutIfNeeded() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
#if DEBUG
        applyDebugWorkspaceStackConstraintIfNeeded()
#endif
        let layout = IPadStudioLayout.resolve(.init(
            bounds: layoutInputBounds,
            safeAreaInsets: view.safeAreaInsets,
            horizontalSizeClass: traitCollection.horizontalSizeClass,
            numpadWidthSize: usesFullWidthDock ? .full : UserPrefs.numpadWidthSize,
            heightPreset: resolvedHeightPreset
        ))
        guard layout != lastLayout else { return }
        lastLayout = layout
        dockHeightConstraint.constant = layout.dockHeight
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        dockLeadingConstraint.constant = layout.dockFrame.minX - safeFrame.minX
        dockTrailingConstraint.constant = layout.dockFrame.maxX - safeFrame.maxX
        let regularLandscape = layout.upperPresentation == .canvasAndInspector
            && !debugForcesCompactPresentation
        navigationRail.isHidden = !regularLandscape
        compactDestinationControl.isHidden = regularLandscape
        compactAdvancedButton.isHidden = regularLandscape
        destinationLeadingConstraint.constant = regularLandscape
            ? 244 + StudioMetrics.Spacing.m * 2
            : 0
        destinationTopRegularConstraint.isActive = regularLandscape
        destinationTopCompactConstraint.isActive = !regularLandscape
        upperScrollView?.contentInset.bottom = layout.upperContentBottomInset
        upperScrollView?.verticalScrollIndicatorInsets.bottom = layout.upperContentBottomInset
    }

    private var resolvedHeightPreset: KeyboardHeightPreset {
#if DEBUG
        if debugForcesKioskHeight { return .kiosk }
#endif
        return KeyboardHeightPreset.effective(
            stored: .selected,
            kioskEntitled: Monetization.isKioskHeightEntitled
        )
    }

    /// Standard and Full QWERTY are full-width iPad compositions. Numpad editors retain the
    /// selected horizontal width, even when the dock is refreshing in place.
    private var usesFullWidthDock: Bool {
        switch previewContext {
        case .qwerty:
            return true
        case .numpad:
            return false
        case .lastUsedPage:
            return UserPrefs.keyboardPageRaw == "qwerty"
        }
    }

    /// UI tests exercise the compact short-window contract inside a real, safe-area-anchored 320pt
    /// workspace stack. Production continues to use the full safe-area workspace.
    private var layoutInputBounds: CGRect {
#if DEBUG
        if let safeHeight = debugLayoutSafeHeight {
            var bounds = view.bounds
            bounds.size.height = safeHeight + view.safeAreaInsets.top + view.safeAreaInsets.bottom
            return bounds
        }
#endif
        return view.bounds
    }

    private var debugForcesCompactPresentation: Bool {
#if DEBUG
        debugArgumentIsEnabled("-debugIPadStudioCompact")
#else
        return false
#endif
    }

#if DEBUG
    private func applyDebugWorkspaceStackConstraintIfNeeded() {
        guard let requestedHeight = debugLayoutSafeHeight else {
            debugWorkspaceStackTopConstraint?.isActive = false
            upperContainerTopConstraint.isActive = true
            return
        }
        let stackHeight = min(requestedHeight, view.safeAreaLayoutGuide.layoutFrame.height)
        if debugWorkspaceStackTopConstraint == nil {
            debugWorkspaceStackTopConstraint = upperContainer.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -stackHeight
            )
            debugWorkspaceStackTopConstraint?.identifier = "debug.ipad-studio.workspace-stack"
        }
        debugWorkspaceStackTopConstraint?.constant = -stackHeight
        upperContainerTopConstraint.isActive = false
        debugWorkspaceStackTopConstraint?.isActive = true
    }

    private var debugForcesKioskHeight: Bool {
        debugArgumentIsEnabled("-debugIPadStudioKiosk")
    }

    private var debugLayoutSafeHeight: CGFloat? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-debugIPadStudioSafeHeight"),
              arguments.indices.contains(index + 1),
              let value = Double(arguments[index + 1]), value > 0
        else { return nil }
        return CGFloat(value)
    }

    private func debugArgumentIsEnabled(_ name: String) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return false
        }
        return arguments[index + 1] == "1"
    }
#endif

    private func observeSettingsIfNeeded() {
        guard !isObservingSettings else { return }
        isObservingSettings = true
        settingsObserverRegistrationCount += 1
        SettingsSync.observe(self) { [weak self] in self?.refreshWorkspace() }
    }

    private func stopObservingSettings() {
        guard isObservingSettings else { return }
        SettingsSync.remove(self)
        isObservingSettings = false
    }
}
