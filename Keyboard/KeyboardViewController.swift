//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {
    private var clipboardView: ClipboardHistoryView?
    private var snippetsView: SnippetsListView?
    private var taxTipView: TaxTipView?
    
    private var heightConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    
    
    lazy var stackView: StackView = { [unowned self] in
        let stackView = StackView()
        stackView.backgroundColor = KeyboardTheme.scheme.border
        stackView.addGestureRecognizer({
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned))
            gesture.maximumNumberOfTouches = 1
            return gesture
        }())
        guard let container = self.inputView else { return stackView }
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        let leading = stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        let trailing = stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        let bottom = stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        let top = stackView.topAnchor.constraint(equalTo: container.topAnchor)
        NSLayoutConstraint.activate([leading, trailing, bottom, top])
        self.stackViewTopConstraint = top
        return stackView
    }()
    
    lazy var items: [[Item]] = self.makeItems()
    
    var maxWidth: CGFloat {
        if let bounds = self.inputView?.bounds, !bounds.isEmpty { return bounds.width }
        // Before the input view is laid out, prefer the hosting view's width over the full
        // screen width — UIScreen.main overstates available width in Split View / Slide Over.
        if let superWidth = self.inputView?.superview?.bounds.width, superWidth > 0 { return superWidth }
        return view.window?.bounds.width ?? UIScreen.main.bounds.width
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Clear stale ephemeral live-adjustment values that may persist if the container
        // app was killed during slider drag. Done unconditionally so an iPhone can never
        // be left with `isKeyboardHeightLiveAdjusting == true` stuck on.
        UserPrefs.currentKeyboardHeightLive = 0
        UserPrefs.isKeyboardHeightLiveAdjusting = false

        // Keyboard height adjustment is iPad-only for now; iPhone uses the system default.
        if traitCollection.userInterfaceIdiom == .pad {
            // Enable self-sizing so iOS respects our height constraint
            if let iv = inputView {
                iv.allowsSelfSizing = true
            }
        }

        reloadItems()
        // Listen for settings changes from the container app and refresh keyboard immediately
        SettingsSync.observe(self) { [weak self] in
            guard let self = self else { return }
            self.reloadItems()
            guard self.traitCollection.userInterfaceIdiom == .pad else { return }
            self.updateAdjustableHeightFeatureState()
            // Live height value (ephemeral) takes precedence when present
            let live = UserPrefs.currentKeyboardHeightLive
            if live > 0 {
                self.ensureHeightConstraintExists()
                let proposed = CGFloat(live)
                let clamped = self.clampedHeight(for: proposed)
                if self.heightConstraint?.constant != clamped {
                    self.heightConstraint?.constant = clamped
                    self.persistHeight(clamped)
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
            } else if UserPrefs.isKeyboardHeightLiveAdjusting {
                self.ensureHeightConstraintExists()
                if let restored = self.restoredHeightIfAny() {
                    let clamped = self.clampedHeight(for: restored)
                    if self.heightConstraint?.constant != clamped {
                        self.heightConstraint?.constant = clamped
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                    }
                }
            }
        }

        // Dictation result from the container app → insert into the host document.
        DictationBridge.observe(self) { [weak self] in
            guard let self = self, let text = DictationBridge.consume() else { return }
            self.textDocumentProxy.insertText(text)
        }

        // Low-latency live height listener (iPad only)
        NPLiveHeightMessenger.observe(self) { [weak self] msg in
            guard let self = self else { return }
            guard self.traitCollection.userInterfaceIdiom == .pad else { return }
            guard UserPrefs.liveKeyboardHeightAdjustEnabled else { return }
            self.ensureHeightConstraintExists()
            let proposed = CGFloat(msg.height)
            let clamped = self.clampedHeight(for: proposed)
            if self.heightConstraint?.constant != clamped {
                self.heightConstraint?.constant = clamped
                self.persistHeight(clamped)
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }
    }

    // Apple's recommended place to set keyboard height — called at the right
    // point in the layout cycle so the system respects our constraint.
    override func updateViewConstraints() {
        super.updateViewConstraints()
        guard traitCollection.userInterfaceIdiom == .pad else { return }
        ensureHeightConstraintExists()
        if let restored = restoredHeightIfAny() {
            heightConstraint?.constant = clampedHeight(for: restored)
        }
    }

    // Re-assert height after layout passes where the system may have reset it
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard traitCollection.userInterfaceIdiom == .pad else { return }
        if let hc = heightConstraint, let restored = restoredHeightIfAny() {
            let clamped = clampedHeight(for: restored)
            if hc.constant != clamped {
                hc.constant = clamped
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            self.reloadItems()
            guard self.traitCollection.userInterfaceIdiom == .pad else { return }
            self.ensureHeightConstraintExists()
            self.clampHeightToBounds()
            if let restored = self.restoredHeightIfAny() {
                let clamped = self.clampedHeight(for: restored)
                self.heightConstraint?.constant = clamped
            }
        }, completion: { _ in })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard traitCollection.userInterfaceIdiom == .pad else { return }
        // Capture the system's default keyboard height on first-ever appearance.
        if UserPrefs.systemDefaultHeight <= 0,
           let iv = inputView, iv.bounds.height > 0 {
            UserPrefs.systemDefaultHeight = Double(iv.bounds.height)
        }
        ensureHeightConstraintExists()
        if let restored = restoredHeightIfAny() {
            heightConstraint?.constant = clampedHeight(for: restored)
            view.setNeedsLayout()
        }
    }
    
    deinit {
        SettingsSync.remove(self)
        NPLiveHeightMessenger.remove(self)
        DictationBridge.remove(self)
    }

    // Open the container app to capture dictation (the keyboard can't use the mic).
    @objc func startDictation(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentDictation()
    }

    func presentDictation() {
        guard let url = URL(string: "numpad://dictate") else { return }
        openContainerApp(url)
    }

    /// Open the container app via its `numpad://` URL scheme.
    ///
    /// A keyboard extension's `extensionContext.open(_:)` does nothing — that API only opens the
    /// containing app for Today widgets, not keyboards. The working technique is to walk the
    /// responder chain to the object that still responds to the legacy `openURL:` selector
    /// (UIApplication) and invoke it. Requires Full Access.
    @discardableResult
    func openContainerApp(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        return false
    }
    
    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        self.textDocumentProxy.deleteBackward()
        playClick()
    }
    
    @IBAction func panned(recognizer: UIPanGestureRecognizer) {
        // Ignore pan-to-type while an overlay is presented, otherwise a pan that began on
        // the key grid would insert text into the host document behind the overlay.
        guard clipboardView == nil, snippetsView == nil, taxTipView == nil else { return }
        switch recognizer.state {
        case .changed, .ended:
            let point = recognizer.location(in: recognizer.view)
            for cell in stackView.cells {
                let frame = cell.convert(cell.bounds, to: stackView)
                let containsPoint = frame.contains(point)
                switch recognizer.state {
                case .changed:
                    cell._isHighlighted = containsPoint
                case .ended where containsPoint:
                    cell.sendActions(for: .touchUpInside)
                    fallthrough
                default:
                    cell._isHighlighted = false
                }
            }
        default: break
        }
    }
    
    func reloadItems() {
        items = makeItems()
        stackView.configure(items, keyboardType: .selected, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, block: { [weak self] (position, item, cell) in
            guard let self = self else { return }
            switch (item.title, item.imageName) {
            case (_, "next"?):
                // Optionally repurpose the Next key to cycle keyboard types instead of system globe
                if UserPrefs.repurposeNextKey {
                    cell.removeTarget(nil, action: nil, for: .allEvents)
                    cell.addTarget(self, action: #selector(self.cycleKeyboardType), for: .touchUpInside)
                } else {
                    cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
                }
            case (_, "back"?):
                cell.addTarget(self, action: #selector(longPressed), forContinuousPressWithTimeInterval: 0.1)
            case ("0"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showClipboardHistory(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            case ("."?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showSnippets(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            case ("%"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showTaxTip(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            case (String.enter?, _):
                // Long-press Enter to dictate numbers via the container app.
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(startDictation(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            default: break
            }
        }, touchDown: { [weak self] (position, item) in self?.touchDown(position) }, tapped: { [weak self] (position, item) in self?.tapped(position) })
    }

    // MARK: - UIInputViewAudioFeedback
    var enableInputClicksWhenVisible: Bool { true }
    
}

// MARK: - Helpers
private extension KeyboardViewController {
    func updateAdjustableHeightFeatureState() {
        ensureHeightConstraintExists()
        clampHeightToBounds()
        if let restored = restoredHeightIfAny() {
            let newHeight = clampedHeight(for: restored)
            heightConstraint?.constant = newHeight
            view.setNeedsLayout()
        }
    }

    func ensureHeightConstraintExists() {
        // Height adjustment is iPad-only. On iPhone, tear down any constraint and let the
        // system size the keyboard so we never fight the host with a stale custom height.
        guard traitCollection.userInterfaceIdiom == .pad else {
            heightConstraint?.isActive = false
            heightConstraint = nil
            return
        }
        // iPad default preset: remove custom height and let the system size the keyboard
        if UserPrefs.iPadHeightPreset == 0 {
            heightConstraint?.isActive = false
            heightConstraint = nil
            return
        }

        if heightConstraint == nil {
            let currentHeight = (inputView?.bounds.height ?? view.bounds.height)
            let fallback: CGFloat = currentHeight > 0 ? currentHeight : 300
            heightConstraint = (inputView ?? view).heightAnchor.constraint(equalToConstant: clampedHeight(for: fallback))
            // Priority 999 overrides the system's height constraint (~999) on iPhone
            // while avoiding unsatisfiable-constraint errors that .required (1000) causes
            heightConstraint?.priority = UILayoutPriority(rawValue: 999)
            heightConstraint?.isActive = true
        }
    }

    func clampedHeight(for proposed: CGFloat) -> CGFloat {
        let limits = heightLimits()
        return max(limits.min, min(limits.max, proposed))
    }

    func clampHeightToBounds() {
        if let hc = heightConstraint {
            hc.constant = clampedHeight(for: hc.constant)
        }
    }

    func heightLimits() -> (min: CGFloat, max: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let containerHeight = view.window?.bounds.height ?? inputView?.superview?.bounds.height ?? UIScreen.main.bounds.height
        // Height limits validated for 2024-2025 device lineup (iPhone mini through Pro Max):
        // - Portrait min 220pt: 4pt above system ~216pt on standard devices, below ~226pt on large devices
        // - Landscape min 160pt: 2pt below system ~162pt, provides flexibility
        // - Max 50% of container: 406-478pt depending on device, reasonable accessibility ceiling
        // These values must match between KeyboardViewController.heightLimits() and
        // KeyboardHeightViewController.recalcIPhone() to ensure slider range matches keyboard range.
        let minH: CGFloat = isCompact ? 160 : 220
        // iPad caps at 50% (matching the large preset); iPhone at 50%
        let maxFraction: CGFloat = isPad ? 0.50 : 0.5
        var maxH: CGFloat = floor(containerHeight * maxFraction)
        // Ensure max is never below min
        if maxH < minH { maxH = minH }
        return (minH, maxH)
    }

    func persistHeight(_ height: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        if isCompact {
            UserPrefs.keyboardHeightCompactValue = Double(height)
        } else {
            UserPrefs.keyboardHeightRegularValue = Double(height)
        }
    }

    func restoredHeightIfAny() -> CGFloat? {
        // iPad presets: compute height dynamically from screen size
        if traitCollection.userInterfaceIdiom == .pad {
            let preset = UserPrefs.iPadHeightPreset
            guard preset > 0 else { return nil } // preset 0 = system default
            let screenHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
            switch preset {
            case 1: return floor(screenHeight * 0.35) // medium
            case 2: return floor(screenHeight * 0.50) // large
            default: return nil
            }
        }
        // iPhone: height adjustment is disabled — always use the system default height.
        return nil
    }
    
    func touchDown(_ position: Position) {
        playClick()
    }
    
    func tapped(_ position: Position) {
        let item = items[position.0][position.1]
        // If Tax/Tip overlay is visible, route numeric input to the overlay instead of the host app
        if let taxView = taxTipView {
            switch (item.title, item.imageName) {
            case (let title?, _) where ["0","1","2","3","4","5","6","7","8","9","."].contains(title):
                taxView.append(title)
                return
            case (_, "back"?):
                taxView.deleteBackward()
                return
            case (String.enter?, _):
                // Compute and insert when Enter is tapped
                taxView.apply()
                return
            default:
                break
            }
        }
        // Premium gating: a key shown with a lock chip must behave as locked. Deep-link to the
        // Store instead of acting. Checked before every other case so it also covers the math toggles.
        if Monetization.isKeyLocked(title: item.title, imageName: item.imageName) {
            if let url = URL(string: "numpad://store-preview") {
                openContainerApp(url)
            }
            return
        }
        switch (item.title, item.imageName) {
        case (String.space?, _): self.textDocumentProxy.insertText(" ")
        case (String.enter?, _): self.textDocumentProxy.insertText("\n")
        case (_, "next"?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case (_, "math"?), (_, "math2"?): KeyboardType.selected.toggleMath(); reloadItems()
        default: item.title.map(self.textDocumentProxy.insertText)
        }
        // No analytics here: the keyboard extension never records or transmits
        // anything the user types. Keystroke tracking has been removed entirely.
    }

    func playClick() {
        guard hasFullAccess else { return }
        if UserPrefs.soundEnabled {
            UIDevice.current.playInputClick()
        }
    }

    /// Remove every overlay so only one is ever presented at a time.
    func dismissOverlays() {
        clipboardView?.removeFromSuperview(); clipboardView = nil
        snippetsView?.removeFromSuperview(); snippetsView = nil
        taxTipView?.removeFromSuperview(); taxTipView = nil
    }

    func makeItems() -> [[Item]] {
        let items = Item.all(type: .selected)
        let isReversed = self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return isReversed ? items.map { $0.reversed() } : items
    }
    
    @objc func cycleKeyboardType() {
        // Cycle through packs including default
        let all: [KeyboardType] = [.default] + KeyboardType.packs
        if let idx = all.firstIndex(of: KeyboardType.selected) {
            let next = all[(idx + 1) % all.count]
            KeyboardType.selected = next
        } else {
            KeyboardType.selected = .default
        }
        reloadItems()
    }
    
}

// MARK: - Clipboard overlay
extension KeyboardViewController: ClipboardHistoryViewDelegate {
    /// Capture the current system pasteboard item into clipboard history (if new and non-empty).
    /// On iOS 16+, reading UIPasteboard.general.string triggers a system permission banner.
    /// If the user denies, `string` returns nil and we gracefully fall back to existing history.
    private func captureCurrentPasteboardItem() {
        guard hasFullAccess else { return }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            ClipboardHistoryManager.shared.add(text)
        }
    }

    @objc func showClipboardHistory(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentClipboardHistory()
    }

    /// Present the clipboard history overlay. Callable from a long-press or a VoiceOver custom action.
    func presentClipboardHistory() {
        dismissOverlays()
        guard let container = self.inputView else { return }
        captureCurrentPasteboardItem()
        let view = ClipboardHistoryView()
        view.delegate = self
        view.hasFullAccess = hasFullAccess
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        let horizontalInset: CGFloat = 10
        let heightMultiplier: CGFloat = 0.6
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: heightMultiplier)
        ])
        clipboardView = view
    }

    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String) {
        self.textDocumentProxy.insertText(item)
        clipboardView?.removeFromSuperview()
        clipboardView = nil
    }

    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView) {
        clipboardView?.removeFromSuperview()
        clipboardView = nil
    }
}

// MARK: - Snippets overlay
extension KeyboardViewController: SnippetsListViewDelegate {
    @objc func showSnippets(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentSnippets()
    }

    /// Present the snippets overlay. Callable from a long-press or a VoiceOver custom action.
    func presentSnippets() {
        dismissOverlays()
        guard let container = self.inputView else { return }
        let view = SnippetsListView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.6)
        ])
        snippetsView = view
    }

    func snippetsListView(_ view: SnippetsListView, didSelectText text: String) {
        self.textDocumentProxy.insertText(text)
        snippetsView?.removeFromSuperview()
        snippetsView = nil
    }
    func snippetsListViewDidRequestClose(_ view: SnippetsListView) {
        snippetsView?.removeFromSuperview()
        snippetsView = nil
    }
}

// MARK: - Tax/Tip overlay
extension KeyboardViewController: TaxTipViewDelegate {
    @objc func showTaxTip(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentTaxTip()
    }

    /// Present the tax/tip overlay. Callable from a long-press or a VoiceOver custom action.
    func presentTaxTip() {
        dismissOverlays()
        guard let container = self.inputView else { return }
        let view = TaxTipView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5)
        ])
        taxTipView = view
    }

    func taxTipView(_ view: TaxTipView, didCompute value: String) {
        self.textDocumentProxy.insertText(value)
        taxTipView?.removeFromSuperview()
        taxTipView = nil
    }
    func taxTipViewDidRequestClose(_ view: TaxTipView) {
        taxTipView?.removeFromSuperview()
        taxTipView = nil
    }
}
