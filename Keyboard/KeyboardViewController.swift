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
    private var packPickerView: PackPickerView?
    private var conversionView: ConversionView?
    private var resultTapeView: ResultTapeView?

    /// The pasteboard `changeCount` we last captured, so we never re-read an unchanged pasteboard.
    private var lastCapturedChangeCount = -1

    /// Transient pack suggested by the host field (smart-pack-defaulting feature). Only applied when
    /// the user is still on the default pack, so it never overrides an explicit pack choice.
    /// Folded into `effectiveKeyboardType` via `refreshEffectiveKeyboardType()`.
    private var smartPackOverride: KeyboardType?

    /// Running x-translation while panning the space key to move the caret (cursor-controls feature).
    private var spacePanLastX: CGFloat = 0

    /// Fixed keyboard height constraint (the 1.5.4 default, restored).
    ///
    /// 1.7.0 removed the height feature and with it the explicit constraint the shipped 1.5.4
    /// build applied, so the keyboard fell back to the system's intrinsic height — visibly
    /// shorter than the released app. This re-creates just the non-configurable default path
    /// from the 1.5.4-era code: a priority-999 constraint on the input view (999 overrides the
    /// system's own height constraint on iPhone without the unsatisfiable-constraint errors
    /// that .required causes), constant = the old default of 300pt clamped to the old limits
    /// (min 220 portrait / 160 landscape, max 50% of the container height). On iPad the old
    /// default preset used pure system sizing, so no constraint is installed there.
    private var heightConstraint: NSLayoutConstraint?

    /// The key grid's top pin to the container. While an overlay band is shown above the keys,
    /// this is deactivated and the grid is pinned below the overlay instead, so the keys stay
    /// visible and tappable rather than being covered by the overlay.
    private var stackTopConstraint: NSLayoutConstraint?

    /// The key grid's trailing pin. On wide iPads overlays present as a trailing side panel
    /// instead of a top band; this is deactivated and the grid is pinned to the panel's leading
    /// edge, so the keys keep their full height next to the panel.
    private var stackTrailingConstraint: NSLayoutConstraint?

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
        self.stackTopConstraint = top
        self.stackTrailingConstraint = trailing
        NSLayoutConstraint.activate([leading, trailing, bottom, top])
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

        // Enable self-sizing so iOS respects our height constraint on iPhone (1.5.4 behavior).
        if let iv = inputView {
            iv.allowsSelfSizing = true
        }

        Button.isFullAccessAvailable = hasFullAccess
        reloadItems()
        // Listen for settings changes from the container app and refresh keyboard immediately.
        // Overlays are dismissed first — their contents (e.g. the pack list) may be stale
        // against the new settings.
        SettingsSync.observe(self) { [weak self] in
            self?.dismissOverlays()
            self?.reloadItems()
            // The height preset may have changed in the app; re-apply while visible.
            self?.applyDefaultHeight()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Full Access can be toggled in Settings between presentations; keep haptics gating current.
        Button.isFullAccessAvailable = hasFullAccess
        // Suggest a pack based on the field we're editing (only used when on the default pack).
        // viewDidLoad already laid out the grid with no override, so rebuild if it changed here.
        let newOverride = FeatureFlags.smartPackDefaulting ? suggestedPack() : nil
        if newOverride != smartPackOverride {
            smartPackOverride = newOverride
            reloadItems()
        }
    }

    /// Map the host field's keyboard type to a sensible pack. Only suggests **unlocked, non-math**
    /// packs (math packs carry a toggle key that depends on the persisted selection). Returns nil
    /// when nothing fits, leaving the default numpad in place.
    private func suggestedPack() -> KeyboardType? {
        let candidate: KeyboardType?
        switch textDocumentProxy.keyboardType {
        case .numbersAndPunctuation, .asciiCapableNumberPad: candidate = .symbols
        default: candidate = nil
        }
        guard let pack = candidate, !Monetization.isLocked(pack: pack) else { return nil }
        return pack
    }

    // Apple's recommended place to set keyboard height — called at the right
    // point in the layout cycle so the system respects our constraint.
    override func updateViewConstraints() {
        super.updateViewConstraints()
        applyDefaultHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.reloadItems()
            // Re-clamp for the new orientation (landscape is shorter than portrait).
            self?.applyDefaultHeight()
        }, completion: { _ in })
    }

    /// Install/refresh the fixed default-height constraint. iPhone only; iPad keeps system sizing.
    private func applyDefaultHeight() {
        guard traitCollection.userInterfaceIdiom != .pad else { return }
        if heightConstraint == nil {
            let constraint = (inputView ?? view).heightAnchor.constraint(equalToConstant: defaultKeyboardHeight())
            constraint.priority = UILayoutPriority(rawValue: 999)
            constraint.isActive = true
            heightConstraint = constraint
        } else {
            let height = defaultKeyboardHeight()
            if heightConstraint?.constant != height {
                heightConstraint?.constant = height
            }
        }
    }

    /// The 1.5.4 default height formula with the user's preset as the base: preset height
    /// (260/300/340) clamped to [220 portrait / 160 landscape, 50% of the container height].
    private func defaultKeyboardHeight() -> CGFloat {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let containerHeight = view.window?.bounds.height ?? inputView?.superview?.bounds.height ?? UIScreen.main.bounds.height
        let minHeight: CGFloat = isCompact ? 160 : 220
        var maxHeight = floor(containerHeight * 0.5)
        if maxHeight < minHeight { maxHeight = minHeight }
        return max(minHeight, min(maxHeight, KeyboardHeightPreset.selected.baseHeight))
    }

    deinit {
        SettingsSync.remove(self)
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
    
    /// Consecutive repeats in the current continuous-backspace hold; resets when the hold ends.
    private var continuousDeleteCount = 0
    private var lastContinuousDeleteAt = Date.distantPast

    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        // The continuous-press timer fires every 0.1s; a longer gap means a new hold started.
        let now = Date()
        if now.timeIntervalSince(lastContinuousDeleteAt) > 0.3 { continuousDeleteCount = 0 }
        lastContinuousDeleteAt = now
        continuousDeleteCount += 1
        // After ~1.2s of holding, escalate from per-character to per-chunk deletion (whole
        // trailing number/word per tick), like the system keyboard's accelerating backspace.
        if FeatureFlags.backspaceWordDelete, continuousDeleteCount > 12,
           let before = self.textDocumentProxy.documentContextBeforeInput {
            for _ in 0..<max(TextDeletion.trailingChunkLength(of: before), 1) {
                self.textDocumentProxy.deleteBackward()
            }
        } else {
            self.textDocumentProxy.deleteBackward()
        }
        playClick()
    }
    
    /// Move the text caret as the user drags horizontally across the space bar. One character of
    /// movement per ~10pt of travel, so it feels like the system keyboard's space-bar trackpad.
    @objc func spacePanned(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            spacePanLastX = 0
        case .changed:
            let x = recognizer.translation(in: recognizer.view).x
            let pointsPerStep: CGFloat = 10
            let steps = Int((x - spacePanLastX) / pointsPerStep)
            if steps != 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
                spacePanLastX += CGFloat(steps) * pointsPerStep
            }
        default:
            break
        }
    }

    @IBAction func panned(recognizer: UIPanGestureRecognizer) {
        // Ignore pan-to-type while an overlay is presented, otherwise a pan that began on
        // the key grid would insert text into the host document behind the overlay.
        guard clipboardView == nil, snippetsView == nil, taxTipView == nil, packPickerView == nil, conversionView == nil, resultTapeView == nil else { return }
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
    
    /// Cached snapshot of `KeyboardType.selected`, resolved for an empty Custom pack.
    /// `effectiveKeyboardType` is consulted on every key tap; reading App Group UserDefaults
    /// there means cross-process cfprefsd traffic (or a plist read when detached) per
    /// keystroke — measurable input lag. The defaults are read once per reload instead;
    /// reloadItems runs on every settings sync, so the cache can never go stale.
    private var cachedEffectiveKeyboardType: KeyboardType = .default

    /// The pack to lay out and gate against. An empty Custom pack contributes no extra row, so
    /// it must render and behave exactly like the default keyboard — otherwise StackView would
    /// treat the first number row as a scrollable pack row and break the layout.
    var effectiveKeyboardType: KeyboardType {
        return cachedEffectiveKeyboardType
    }

    /// The active custom layout, when the customizable-keyboard feature is unlocked and a layout is
    /// selected. Supersedes pack selection (2.0 Phase 1).
    var activeCustomLayout: KeyboardLayout? {
        guard Monetization.isCustomKeyboardEntitled else { return nil }
        return LayoutStore(defaults: .group).activeLayout()
    }

    private func refreshEffectiveKeyboardType() {
        if activeCustomLayout != nil {
            // A custom layout renders the whole grid itself and isn't pack-gated — treat as default
            // so pack lock-chips and pack styling don't apply to the user's own keys.
            cachedEffectiveKeyboardType = .default
            return
        }
        let selected = KeyboardType.selected
        if FeatureFlags.smartPackDefaulting, selected == .default, let pack = smartPackOverride {
            // Smart-pack suggestion only ever replaces the *default* pack, never an explicit choice.
            cachedEffectiveKeyboardType = pack
        } else if selected == .custom && CustomPackManager.shared.keys.isEmpty {
            cachedEffectiveKeyboardType = .default
        } else {
            cachedEffectiveKeyboardType = selected
        }
    }

    func reloadItems() {
        refreshEffectiveKeyboardType()
        items = makeItems()
        stackView.configure(items, keyboardType: effectiveKeyboardType, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, block: { [weak self] (position, item, cell) in
            guard let self = self else { return }
            switch (item.title, item.imageName) {
            case (_, "next"?):
                // Optionally repurpose the Next key to cycle keyboard types instead of system globe
                if UserPrefs.repurposeNextKey {
                    // Replace only the tap action — removing .allEvents would also strip the
                    // touch-down target that plays the key click, leaving this key silent.
                    cell.removeTarget(nil, action: nil, for: .touchUpInside)
                    cell.addTarget(self, action: #selector(self.cycleKeyboardType), for: .touchUpInside)
                    // Long-press jumps straight to any pack instead of cycling one by one.
                    // Only in repurposed mode: the system globe key owns its own long-press
                    // (the keyboard list) which we must not fight.
                    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.showPackPicker(_:)))
                    longPress.minimumPressDuration = 0.35
                    cell.addGestureRecognizer(longPress)
                } else {
                    cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
                }
            case (_, "globe"?):
                // Dedicated keyboard-switch key for devices where needsInputModeSwitchKey is
                // true. .allTouchEvents lets the system handle tap (next keyboard) and
                // long-press (keyboard list) natively.
                cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
                cell.accessibilityLabel = NSLocalizedString("Next Keyboard", comment: "Accessibility label for the keyboard-switch (globe) key")
            case (_, "back"?):
                cell.addTarget(self, action: #selector(longPressed), forContinuousPressWithTimeInterval: 0.1)
            case ("0"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showClipboardHistory(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
                // VoiceOver intercepts long-presses, so expose the overlay via a custom action + hint.
                cell.accessibilityHint = NSLocalizedString("Double tap and hold for clipboard history", comment: "VoiceOver hint for the 0 key")
                cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: NSLocalizedString("Show clipboard history", comment: "VoiceOver custom action for the 0 key")) { [weak self] _ in
                    self?.presentClipboardHistory(); return true
                }]
            case ("."?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showSnippets(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
                cell.accessibilityHint = NSLocalizedString("Double tap and hold for snippets", comment: "VoiceOver hint for the . key")
                cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: NSLocalizedString("Show snippets", comment: "VoiceOver custom action for the . key")) { [weak self] _ in
                    self?.presentSnippets(); return true
                }]
            case ("%"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showTaxTip(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
                cell.accessibilityHint = NSLocalizedString("Double tap and hold for the tax and tip calculator", comment: "VoiceOver hint for the % key")
                cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: NSLocalizedString("Show tax and tip calculator", comment: "VoiceOver custom action for the % key")) { [weak self] _ in
                    self?.presentTaxTip(); return true
                }]
            case (String.space?, _) where FeatureFlags.cursorControls:
                // Drag across the space bar to move the caret (cursor-controls feature).
                let pan = UIPanGestureRecognizer(target: self, action: #selector(spacePanned(_:)))
                cell.addGestureRecognizer(pan)
            case ("="?, _) where FeatureFlags.conversionOverlay:
                // Long-press "=" opens the unit-conversion overlay (the tap still calculates).
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showConversion(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            default:
                // Long-press the return key opens the recent-results tape.
                if item.role == .returnKey, FeatureFlags.lastResultTape {
                    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showResultTape(_:)))
                    longPress.minimumPressDuration = 0.35
                    cell.addGestureRecognizer(longPress)
                }
            }
            // Snippets must stay reachable when the period is remapped away: the middle
            // right-side slot hosts the snippets long-press whatever key occupies it.
            // (A period in that slot already got the gesture from the switch above.)
            if item.slot == 1, item.title != "." {
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.showSnippets(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            }
        }, touchDown: { [weak self] (position, item) in self?.touchDown(position) }, tapped: { [weak self] (position, item) in self?.tapped(position) })
    }

    // MARK: - UIInputViewAudioFeedback
    var enableInputClicksWhenVisible: Bool { true }
    
}

// MARK: - Helpers
private extension KeyboardViewController {
    func touchDown(_ position: Position) {
        playClick()
    }
    
    func tapped(_ position: Position) {
        let item = items[position.0][position.1]
        // While a calculator-style overlay (Tax/Tip or Conversion) is shown, route numeric input
        // into it and swallow everything else, so taps never leak into the host document behind it.
        if let taxView = taxTipView {
            routeIntoCalculatorOverlay(item, append: taxView.append, delete: taxView.deleteBackward, apply: taxView.apply)
            return
        }
        if let conv = conversionView {
            routeIntoCalculatorOverlay(item, append: conv.append, delete: conv.deleteBackward, apply: conv.apply)
            return
        }
        // List overlays (clipboard / snippets / result tape) have their own controls; swallow any
        // numpad tap so it doesn't type into the host document behind the overlay.
        if clipboardView != nil || snippetsView != nil || resultTapeView != nil { return }
        // Premium gating: a key shown with a lock chip must behave as locked. Deep-link to the
        // Store instead of acting. Checked before every other case.
        if Monetization.isKeyLocked(pack: effectiveKeyboardType, row: position.0) {
            // The source query lets the app attribute the store visit (funnel analytics).
            // Nothing the user typed is ever included.
            if let url = URL(string: "numpad://store-preview?source=key_lock") {
                openContainerApp(url)
            }
            return
        }
        if item.role == .returnKey {
            // Inserting a newline is the standard way a keyboard triggers a field's return action;
            // the host (single-line fields, search bars, etc.) interprets it as the return key.
            self.textDocumentProxy.insertText("\n")
            return
        }
        switch (item.title, item.imageName) {
        case (String.space?, _): self.textDocumentProxy.insertText(" ")
        case ("+/-"?, _): toggleSignBeforeCursor()
        case ("="?, _) where FeatureFlags.inlineCalculator: evaluateInlineExpression()
        case ("."?, _) where FeatureFlags.localeAwareSeparators:
            self.textDocumentProxy.insertText(Locale.current.decimalSeparator ?? ".")
        case (_, "next"?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case (_, "math"?), (_, "math2"?): KeyboardType.selected.toggleMath(); reloadItems()
        default:
            if let token = item.token {
                switch token {
                case CustomKeys.cursorLeftToken:
                    self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
                case CustomKeys.cursorRightToken:
                    self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
                case CustomKeys.dismissToken:
                    self.dismissKeyboard()
                default:
                    // Remappable slot keys insert their token's text (e.g. tab → "\t"), not their label.
                    self.textDocumentProxy.insertText(CustomKeys.insertedText(for: token))
                }
            } else {
                item.title.map(self.textDocumentProxy.insertText)
            }
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

    /// Route a numpad tap into a calculator-style overlay's amount field. The return key applies;
    /// digits and the decimal point append; delete removes a character; everything else is ignored.
    private func routeIntoCalculatorOverlay(_ item: Item, append: (String) -> Void, delete: () -> Void, apply: () -> Void) {
        if item.role == .returnKey { apply(); return }
        switch (item.title, item.imageName) {
        case (let title?, _) where ["0","1","2","3","4","5","6","7","8","9",".",","].contains(title):
            append(title)
        case (_, "back"?):
            delete()
        default:
            break
        }
    }

    /// Evaluate the arithmetic expression immediately before the cursor and replace it with the
    /// result (inline-calculator feature). Falls back to inserting a literal "=" when the trailing
    /// text isn't a valid expression, so the key never becomes a no-op.
    func evaluateInlineExpression() {
        let proxy = textDocumentProxy
        let separator = FeatureFlags.localeAwareSeparators ? (Locale.current.decimalSeparator ?? ".") : "."
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else {
            proxy.insertText("="); return
        }
        // Take the trailing run of expression characters (numbers, operators, parens, separators).
        let exprChars = Set("0123456789+-*/%()×÷− .,\(separator)")
        let raw = String(before.reversed().prefix { exprChars.contains($0) }.reversed())
        let expression = raw.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty,
              let result = Calculator.evaluate(expression, decimalSeparator: separator) else {
            proxy.insertText("=")
            return
        }
        let formatted = Calculator.format(result, decimalSeparator: separator)
        for _ in 0..<raw.count { proxy.deleteBackward() }
        proxy.insertText(formatted)
        if FeatureFlags.lastResultTape { ResultTape.shared.add(formatted) }
    }

    /// Toggle the sign of the number immediately before the cursor. Replaces the old behavior of
    /// the finance "+/-" key, which inserted the literal string "+/-". If there is no number before
    /// the cursor we insert a lone minus so the key still does something sensible.
    func toggleSignBeforeCursor() {
        let proxy = textDocumentProxy
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else {
            proxy.insertText("-")
            return
        }
        // Grab the trailing run of numeric characters (digits, grouping/decimal separators).
        let numeric = Set("0123456789.,")
        let token = String(before.reversed().prefix { numeric.contains($0) }.reversed())
        guard !token.isEmpty else {
            proxy.insertText("-")
            return
        }
        // Is the character just before the number already a minus sign?
        let beforeToken = before.dropLast(token.count)
        let hasMinus = beforeToken.last == "-" || beforeToken.last == "−"
        for _ in 0..<token.count { proxy.deleteBackward() }
        if hasMinus {
            proxy.deleteBackward()       // remove the existing minus
            proxy.insertText(token)
        } else {
            proxy.insertText("-" + token)
        }
    }

    /// Fraction of the keyboard height reserved at the top for an overlay band. The key grid
    /// compresses into the remaining space below, so the keys are never covered by the overlay.
    private static let overlayBandFraction: CGFloat = 0.5

    /// Width of the trailing side panel that hosts overlays on wide iPads.
    private static let sidePanelWidth: CGFloat = 360

    /// Wide iPads get overlays as a trailing side panel: the keyboard is short and very wide
    /// there, so a top band would leave both the overlay and the compressed keys unusably flat,
    /// while a 360pt panel costs only a fraction of the width and keeps keys full-height.
    private var usesSidePanelOverlays: Bool {
        return traitCollection.userInterfaceIdiom == .pad && maxWidth >= 700
    }

    /// Pin `overlay` into a band at the top of the keyboard and push the key grid below it, so
    /// the overlay sits *above* the keys instead of covering them. The keys remain visible and
    /// tappable — essential for Tax/Tip, where numpad taps are routed into the overlay.
    /// On wide iPads this delegates to `installOverlayBeside` (trailing side panel) instead.
    /// Returns false (and does nothing) if there is no input view to host the overlay.
    @discardableResult
    private func installOverlayAbove(_ overlay: UIView,
                                     topInset: CGFloat = 8,
                                     heightFraction: CGFloat = overlayBandFraction) -> Bool {
        guard let container = self.inputView else { return false }
        if usesSidePanelOverlays {
            return installOverlayBeside(overlay, in: container)
        }
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)
        // Detach the key grid from the container top and re-pin it below the overlay band.
        stackTopConstraint?.isActive = false
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            overlay.topAnchor.constraint(equalTo: container.topAnchor, constant: topInset),
            overlay.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: heightFraction),
            stackView.topAnchor.constraint(equalTo: overlay.bottomAnchor, constant: 6)
        ])
        return true
    }

    /// iPad variant of `installOverlayAbove`: pin the overlay as a full-height trailing panel and
    /// re-pin the key grid to its leading edge. The keys stay full-height and tappable, and
    /// Tax/Tip input routing works exactly as in the top-band layout.
    private func installOverlayBeside(_ overlay: UIView, in container: UIView) -> Bool {
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)
        stackTrailingConstraint?.isActive = false
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            overlay.widthAnchor.constraint(equalToConstant: Self.sidePanelWidth),
            stackView.trailingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: -6)
        ])
        return true
    }

    /// Remove every overlay so only one is ever presented at a time, and restore the key grid
    /// to fill the whole keyboard. Removing an overlay drops the constraints that referenced it
    /// (including the grid's top pin to it), so we must re-activate the grid's pin to the container.
    func dismissOverlays() {
        clipboardView?.removeFromSuperview(); clipboardView = nil
        snippetsView?.removeFromSuperview(); snippetsView = nil
        taxTipView?.removeFromSuperview(); taxTipView = nil
        packPickerView?.removeFromSuperview(); packPickerView = nil
        conversionView?.removeFromSuperview(); conversionView = nil
        resultTapeView?.removeFromSuperview(); resultTapeView = nil
        stackTopConstraint?.isActive = true
        stackTrailingConstraint?.isActive = true
    }

    func makeItems() -> [[Item]] {
        if let layout = activeCustomLayout {
            // Custom layout supersedes the pack grid (2.0 Phase 1). Falls back to the legacy path
            // below whenever the feature is locked or no layout is active.
            let custom = KeyboardLayoutRenderer.items(for: layout, returnTitle: returnKeyTitle())
            let rtl = self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            return rtl ? custom.map { $0.reversed() } : custom
        }
        // On Home-button devices (older iPads, iPhone 8/SE and earlier) iOS draws no system
        // globe affordance, so the keyboard itself must offer a way to switch keyboards.
        // When the Next key is repurposed to cycle packs it no longer does that, leaving
        // users stuck on NumPad — add a dedicated globe key on exactly those devices.
        let needsDedicatedSwitchKey = needsInputModeSwitchKey && UserPrefs.repurposeNextKey
        let items = Item.all(type: effectiveKeyboardType, includeSwitchKey: needsDedicatedSwitchKey, returnKeyTitle: returnKeyTitle())
        let isReversed = self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return isReversed ? items.map { $0.reversed() } : items
    }

    /// Label for the bottom-right return key, matched to the host field's `returnKeyType` so it
    /// reads "Go"/"Search"/"Done"/… instead of a generic "Enter". The key still inserts a newline
    /// (the standard way a keyboard triggers a text field's return action); only the label adapts.
    private func returnKeyTitle() -> String {
        switch textDocumentProxy.returnKeyType {
        case .go: return NSLocalizedString("Go", comment: "Return key label for a Go action field")
        case .search, .google, .yahoo: return NSLocalizedString("Search", comment: "Return key label for a search field")
        case .send: return NSLocalizedString("Send", comment: "Return key label for a send action field")
        case .done: return NSLocalizedString("Done", comment: "Return key label for a Done action field")
        case .next: return NSLocalizedString("Next", comment: "Return key label to advance to the next field")
        case .join: return NSLocalizedString("Join", comment: "Return key label for a join action field")
        case .route: return NSLocalizedString("Route", comment: "Return key label for a routing action field")
        case .continue: return NSLocalizedString("Continue", comment: "Return key label for a continue action field")
        default: return .enter
        }
    }
    
    @objc func cycleKeyboardType() {
        // Cycle through packs including default, skipping packs the user hasn't unlocked.
        // Math2 is the toggled face of the Math pack (reached via its in-pack toggle), and an
        // empty Custom pack would render identically to default — both are skipped.
        let all: [KeyboardType] = ([.default] + KeyboardType.packs).filter {
            if $0 == .math2 { return false }
            guard !Monetization.isLocked(pack: $0) else { return false }
            if $0 == .custom && CustomPackManager.shared.keys.isEmpty { return false }
            return true
        }
        let current: KeyboardType = KeyboardType.selected == .math2 ? .math : KeyboardType.selected
        if let idx = all.firstIndex(of: current) {
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
    ///
    /// `changeCount` and `hasStrings` do **not** trigger the iOS 16+ "pasted from" banner; reading
    /// `.string` does. So we only read the actual string when the pasteboard has changed *and* holds
    /// a string — that way the same item is never re-read and the banner never fires twice for it.
    /// Also short-circuits entirely when the feature is off or Full Access is denied.
    private func captureCurrentPasteboardItem() {
        guard hasFullAccess, UserPrefs.clipboardHistoryEnabled else { return }
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount != lastCapturedChangeCount else { return }
        lastCapturedChangeCount = pasteboard.changeCount
        guard pasteboard.hasStrings, let text = pasteboard.string, !text.isEmpty else { return }
        ClipboardHistoryManager.shared.add(text)
    }

    @objc func showClipboardHistory(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentClipboardHistory()
    }

    /// Present the clipboard history overlay. Callable from a long-press or a VoiceOver custom action.
    func presentClipboardHistory() {
        dismissOverlays()
        captureCurrentPasteboardItem()
        let view = ClipboardHistoryView()
        view.delegate = self
        view.hasFullAccess = hasFullAccess
        guard installOverlayAbove(view) else { return }
        clipboardView = view
    }

    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String) {
        self.textDocumentProxy.insertText(item)
        dismissOverlays()
    }

    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView) {
        dismissOverlays()
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
        let view = SnippetsListView()
        view.delegate = self
        guard installOverlayAbove(view) else { return }
        snippetsView = view
    }

    func snippetsListView(_ view: SnippetsListView, didSelectText text: String) {
        self.textDocumentProxy.insertText(text)
        dismissOverlays()
    }
    func snippetsListViewDidRequestClose(_ view: SnippetsListView) {
        dismissOverlays()
    }
}

// MARK: - Pack picker overlay
extension KeyboardViewController: PackPickerViewDelegate {
    @objc func showPackPicker(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentPackPicker()
    }

    /// Present the pack picker overlay. Callable from a long-press or a VoiceOver custom action.
    func presentPackPicker() {
        dismissOverlays()
        let view = PackPickerView()
        view.delegate = self
        guard installOverlayAbove(view) else { return }
        packPickerView = view
    }

    func packPickerView(_ view: PackPickerView, didSelect type: KeyboardType) {
        KeyboardType.selected = type
        dismissOverlays()
        reloadItems()
    }

    func packPickerView(_ view: PackPickerView, didSelectLocked type: KeyboardType) {
        dismissOverlays()
        if let url = URL(string: "numpad://store-preview?source=pack_picker") {
            openContainerApp(url)
        }
    }

    func packPickerViewDidRequestClose(_ view: PackPickerView) {
        dismissOverlays()
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
        let view = TaxTipView()
        view.delegate = self
        guard installOverlayAbove(view) else { return }
        taxTipView = view
    }

    func taxTipView(_ view: TaxTipView, didCompute value: String) {
        self.textDocumentProxy.insertText(value)
        dismissOverlays()
    }
    func taxTipViewDidRequestClose(_ view: TaxTipView) {
        dismissOverlays()
    }
}

// MARK: - Conversion overlay
extension KeyboardViewController: ConversionViewDelegate {
    @objc func showConversion(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentConversion()
    }

    /// Present the unit-conversion overlay. Callable from a long-press or a VoiceOver custom action.
    func presentConversion() {
        dismissOverlays()
        let view = ConversionView()
        view.delegate = self
        guard installOverlayAbove(view) else { return }
        conversionView = view
    }

    func conversionView(_ view: ConversionView, didCompute value: String) {
        self.textDocumentProxy.insertText(value)
        dismissOverlays()
    }
    func conversionViewDidRequestClose(_ view: ConversionView) {
        dismissOverlays()
    }
}

// MARK: - Result tape overlay
extension KeyboardViewController: ResultTapeViewDelegate {
    @objc func showResultTape(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentResultTape()
    }

    /// Present the recent-results tape overlay. Callable from a long-press or a VoiceOver action.
    func presentResultTape() {
        dismissOverlays()
        let view = ResultTapeView()
        view.delegate = self
        guard installOverlayAbove(view) else { return }
        resultTapeView = view
    }

    func resultTapeView(_ view: ResultTapeView, didSelect result: String) {
        self.textDocumentProxy.insertText(result)
        dismissOverlays()
    }
    func resultTapeViewDidRequestClose(_ view: ResultTapeView) {
        dismissOverlays()
    }
}
