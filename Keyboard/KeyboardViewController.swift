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
    private var conversionView: ConversionView?
    private var resultTapeView: ResultTapeView?

    /// The pasteboard `changeCount` we last captured, so we never re-read an unchanged pasteboard.
    private var lastCapturedChangeCount = -1

    /// Transient pack suggested by the host field (smart-pack-defaulting feature). Only applied when
    /// the user is still on the default pack, so it never overrides an explicit pack choice.
    private var smartPackOverride: KeyboardType?

    /// The pack to actually render: the smart suggestion when enabled and the user hasn't picked a
    /// pack, otherwise the user's selection.
    private var effectiveKeyboardType: KeyboardType {
        if FeatureFlags.smartPackDefaulting, KeyboardType.selected == .default, let pack = smartPackOverride {
            return pack
        }
        return KeyboardType.selected
    }

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
        // Listen for settings changes from the container app and refresh keyboard immediately
        SettingsSync.observe(self) { [weak self] in
            self?.reloadItems()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Full Access can be toggled in Settings between presentations; keep haptics gating current.
        Button.isFullAccessAvailable = hasFullAccess
        // Suggest a pack based on the field we're editing (only used when on the default pack).
        smartPackOverride = FeatureFlags.smartPackDefaulting ? suggestedPack() : nil
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

    /// The 1.5.4 default height formula: 300pt clamped to [220 portrait / 160 landscape,
    /// 50% of the container height].
    private func defaultKeyboardHeight() -> CGFloat {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let containerHeight = view.window?.bounds.height ?? inputView?.superview?.bounds.height ?? UIScreen.main.bounds.height
        let minHeight: CGFloat = isCompact ? 160 : 220
        var maxHeight = floor(containerHeight * 0.5)
        if maxHeight < minHeight { maxHeight = minHeight }
        return max(minHeight, min(maxHeight, 300))
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
    
    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        self.textDocumentProxy.deleteBackward()
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
        guard clipboardView == nil, snippetsView == nil, taxTipView == nil, conversionView == nil, resultTapeView == nil else { return }
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
        stackView.configure(items, keyboardType: effectiveKeyboardType, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, block: { [weak self] (position, item, cell) in
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
            if let url = URL(string: "numpad://store-preview") {
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

    /// Pin `overlay` into a band at the top of the keyboard and push the key grid below it, so
    /// the overlay sits *above* the keys instead of covering them. The keys remain visible and
    /// tappable — essential for Tax/Tip, where numpad taps are routed into the overlay.
    /// Returns false (and does nothing) if there is no input view to host the overlay.
    @discardableResult
    private func installOverlayAbove(_ overlay: UIView,
                                     topInset: CGFloat = 8,
                                     heightFraction: CGFloat = overlayBandFraction) -> Bool {
        guard let container = self.inputView else { return false }
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

    /// Remove every overlay so only one is ever presented at a time, and restore the key grid
    /// to fill the whole keyboard. Removing an overlay drops the constraints that referenced it
    /// (including the grid's top pin to it), so we must re-activate the grid's pin to the container.
    func dismissOverlays() {
        clipboardView?.removeFromSuperview(); clipboardView = nil
        snippetsView?.removeFromSuperview(); snippetsView = nil
        taxTipView?.removeFromSuperview(); taxTipView = nil
        conversionView?.removeFromSuperview(); conversionView = nil
        resultTapeView?.removeFromSuperview(); resultTapeView = nil
        stackTopConstraint?.isActive = true
    }

    func makeItems() -> [[Item]] {
        let items = Item.all(type: effectiveKeyboardType, returnKeyTitle: returnKeyTitle())
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
        // Cycle through packs including default, skipping packs the user hasn't unlocked
        let all: [KeyboardType] = ([.default] + KeyboardType.packs).filter { !Monetization.isLocked(pack: $0) }
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
