//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {
    /// The two pages the merged extension hosts (owner decision 2026-07-09): the numpad,
    /// unchanged, and the folded-in full-QWERTY page. Persisted via `UserPrefs.keyboardPageRaw`.
    enum Page: String {
        case numpad, qwerty
    }

    /// What's on screen right now — kept separate from the persisted selection
    /// (`UserPrefs.keyboardPageRaw`) so a gate that's merely temporarily off (RC kill switch,
    /// lapsed Pro) can fall back to the numpad for display without clobbering the user's saved
    /// QWERTY choice. Always `.numpad` when `qwertyPageAvailable` is false.
    private var currentPage: Page = .numpad

    /// The QWERTY page's host, lazily created on first entry and kept alive afterward — leaving
    /// the page only hides its view, it's never torn down.
    private var qwertyPageHost: QwertyPageHost?

    /// Kill-switch + entitlement gate for the QWERTY page (owner decision 2026-07-09). The "ABC"
    /// key, the persisted-page raise on appear, and every page switch all check this single source
    /// of truth. When false, the ABC key is never inserted and the page can never be reached — the
    /// numpad renders and behaves byte-for-byte as it did before the merge. The local
    /// `fullKeyboardEnabled` flag is deliberately absent — it gates app-side surfacing only
    /// (see `FeatureFlags.qwertyPageAvailable`).
    private var qwertyPageAvailable: Bool {
        FeatureFlags.isQwertyPageAvailable
    }

    private var clipboardView: ClipboardHistoryView?
    private var snippetsView: SnippetsListView?
    private var taxTipView: TaxTipView?
    private var packPickerView: PackPickerView?
    private var conversionView: ConversionView?
    private var resultTapeView: ResultTapeView?
    /// Shared app-group-backed kiosk clock survives extension appearances.
    private let kioskSessionClock = KioskSessionClock()
    private var kioskInactivityTimer: Timer?


    /// The Live Math Preview result chip. Created once in `viewDidLoad` (after the key grid, so it
    /// always draws on top) and toggled hidden/visible rather than added/removed — it's shown and
    /// hidden far more often than any overlay.
    private var mathPreviewChip: MathPreviewChipView?
    /// The decision backing whatever the chip currently shows, so a tap knows exactly what raw text
    /// to delete and what to insert without re-parsing.
    private var pendingMathPreviewDecision: MathPreviewChip.Decision?
    /// Debounce timer for recomputing the chip on `textDidChange`/`selectionDidChange`. Tiny
    /// interval — just enough to avoid re-parsing on every single keystroke of a multi-digit number.
    private var mathPreviewDebounceTimer: Timer?
    private static let mathPreviewDebounceInterval: TimeInterval = 0.12
    /// Whether `mathPreviewShown` has already been counted for this appearance, so rapid re-renders
    /// while typing don't inflate the funnel count (mirrors `lockImpressionLoggedThisAppearance`).
    private var mathPreviewShownLoggedThisAppearance = false

    /// The pasteboard `changeCount` we last captured, so we never re-read an unchanged pasteboard.
    private var lastCapturedChangeCount = -1

    /// Transient pack suggested by the host field (smart-pack-defaulting feature). Only applied when
    /// the user is still on the default pack, so it never overrides an explicit pack choice.
    /// Folded into `effectiveKeyboardType` via `refreshEffectiveKeyboardType()`.
    private var smartPackOverride: KeyboardType?

    /// Running x-translation while panning the space key to move the caret (cursor-controls feature).
    private var spacePanLastX: CGFloat = 0

    /// Fixed keyboard height constraint (the 1.5.4 default, restored; 2.0 extends it to iPad).
    ///
    /// 1.7.0 removed the height feature and with it the explicit constraint the shipped 1.5.4
    /// build applied, so the keyboard fell back to the system's intrinsic height — visibly
    /// shorter than the released app. This re-creates just the non-configurable default path
    /// from the 1.5.4-era code: a priority-999 constraint on the input view (999 overrides the
    /// system's own height constraint without the unsatisfiable-constraint errors that .required
    /// causes), constant = the preset height clamped to [220pt portrait / 160pt landscape, 50% of
    /// the container height]. Torn down and rebuilt (not just mutated) on every appearance — see
    /// `viewWillAppear` — because iPad otherwise grows the keyboard on repeated keyboard switches.
    /// Suppressed entirely on iPad's pinch-to-float mini keyboard (`isFloatingKeyboard`), which the
    /// system must size itself.
    private var heightConstraint: NSLayoutConstraint?

    /// Whether this keyboard appearance has already logged a lock impression, so repeated
    /// `reloadItems()` calls within the same appearance (settings sync, rotation, pack switch)
    /// don't over-count. Reset in `viewWillAppear`.
    private var lockImpressionLoggedThisAppearance = false

    /// Guards the one-time corrective rebuild after the first real layout pass. `viewDidLoad` builds
    /// the grid before the input view has real bounds and a settled layout direction, so on a cold
    /// launch (fresh install) the first render can be wrong — e.g. the layout direction or width
    /// isn't resolved yet. We rebuild once the view has actually laid out (the same `reloadItems()`
    /// a keyboard switch or pack selection already triggers), then never again for this controller.
    private var didInitialLayoutRebuild = false

    /// The key grid's top pin to the container. While an overlay band is shown above the keys,
    /// this is deactivated and the grid is pinned below the overlay instead, so the keys stay
    /// visible and tappable rather than being covered by the overlay.
    private var stackTopConstraint: NSLayoutConstraint?

    /// The key grid's trailing pin. On wide iPads overlays present as a trailing side panel
    /// instead of a top band; this is deactivated and the grid is pinned to the panel's leading
    /// edge, so the keys keep their full height next to the panel.
    private var stackTrailingConstraint: NSLayoutConstraint?

    /// Shared iOS 26 Liquid Glass backdrop for the "Glass"/"Glass Dark" themes — one
    /// `UIVisualEffectView` behind the whole key grid, deliberately **not** one per cell (would be
    /// ~40 blur passes in a ~50MB extension). Each `Cell`'s already-translucent glass-theme
    /// background (`UIColor.itemScheme`) lets this single blur read through both the inter-key
    /// spacing and the keycaps themselves. `nil` on iOS <26 or non-glass themes, where the
    /// translucent flat color alone stands in (see `applyGlassBackdrop`).
    private var glassBackdropView: UIVisualEffectView?
    /// The theme `glassBackdropView` was last built for, so a live theme switch (Settings ↔
    /// keyboard) rebuilds the tint instead of leaving a stale one, without rebuilding on every
    /// `reloadItems()` call for the *same* theme (pack switches, rotations).
    private var appliedGlassTheme: KeyboardTheme?

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
        // Installed after the first reloadItems() (which creates the key grid) so the chip is
        // always the last subview added — guaranteeing it draws on top of the keys.
        installMathPreviewChip()
        // Raise directly into the QWERTY page when it was the last-used page and the gate still
        // passes (owner decision 2026-07-09); falls back to (and stays on) the numpad otherwise.
        // No-op when the feature is off — `currentPage` never leaves `.numpad`.
        syncPageWithPersistedState()
        // Listen for settings changes from the container app and refresh keyboard immediately.
        // Overlays are dismissed first — their contents (e.g. the pack list) may be stale
        // against the new settings.
        SettingsSync.observe(self) { [weak self] in
            guard let self = self else { return }
            self.dismissOverlays()
            self.syncPageWithPersistedState()
            switch self.currentPage {
            case .numpad:
                self.reloadItems()
            case .qwerty:
                self.qwertyPageHost?.needsInputModeSwitchKey = self.needsInputModeSwitchKey
                self.qwertyPageHost?.settingsDidChange()
            }
            // The height preset may have changed in the app; re-apply while visible.
            self.applyDefaultHeight()
            // Theme or the Live Math Preview toggle may have changed.
            self.mathPreviewChip?.applyTheme()
            self.scheduleMathPreviewRefresh()
            // Profile activation can enable/disable kiosk enforcement while the keyboard remains
            // visible in Split View. Reconcile the persisted clock and monitor immediately.
            self.recordKioskActivity()
            self.startKioskInactivityMonitor()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // New appearance: allow one fresh lock impression to be logged for it.
        lockImpressionLoggedThisAppearance = false
        // New appearance: allow one fresh Live Math Preview "shown" impression to be logged for it.
        mathPreviewShownLoggedThisAppearance = false
        // Full Access can be toggled in Settings between presentations; keep haptics gating current.
        Button.isFullAccessAvailable = hasFullAccess

        // A prior appearance may already be expired. Evaluate and apply its reset before this
        // appearance reads the persisted page/pack, then refresh the coarse activity timestamp.
        recordKioskActivity()
        startKioskInactivityMonitor()

        // Raise into (or fall back from) the QWERTY page per the persisted selection + gate —
        // see `syncPageWithPersistedState()`. No-op when the feature is off.
        syncPageWithPersistedState()

        switch currentPage {
        case .numpad:
            // Suggest a pack based on the field we're editing (only used when on the default
            // pack). viewDidLoad already laid out the grid with no override, so rebuild if it
            // changed here.
            let newOverride = UserPrefs.smartPackDefaulting ? suggestedPack() : nil
            if newOverride != smartPackOverride {
                smartPackOverride = newOverride
                reloadItems()
            }
        case .qwerty:
            qwertyPageHost?.needsInputModeSwitchKey = needsInputModeSwitchKey
            qwertyPageHost?.activate()
        }

        // iPad height-drift fix: mutating an existing height constraint's `.constant` across
        // repeated keyboard switches causes it to compound and grow. Tearing the constraint down
        // and building a fresh one on every appearance avoids that; also re-evaluates the floating
        // -mini-keyboard suppression (pinch state can change between appearances).
        heightConstraint?.isActive = false
        heightConstraint = nil
        applyDefaultHeight()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        kioskInactivityTimer?.invalidate()
        kioskInactivityTimer = nil
        mathPreviewDebounceTimer?.invalidate()
        mathPreviewDebounceTimer = nil
        qwertyPageHost?.deactivate()
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

    /// On a cold launch the very first grid build in `viewDidLoad` runs before the input view has
    /// real bounds or a settled layout direction, so the keys can render in the wrong order until
    /// something forces a rebuild. Rebuild exactly once the view has actually laid out — the same
    /// `reloadItems()` a keyboard switch or pack selection already does — so the order is right from
    /// the user's first look.
    ///
    /// Height is intentionally NOT re-applied here. Re-running `applyDefaultHeight()` on every
    /// layout pass recomputed the clamp from a container height that, mid-layout, reads as the
    /// keyboard's own height rather than the screen — collapsing `min(preset, 50% of container)` to
    /// the 220pt floor and pinning the keyboard to its minimum, so the height preset stopped taking
    /// effect. Height stays owned by `updateViewConstraints` / `viewWillTransition` / `viewWillAppear`
    /// / settings-sync.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // QWERTY's `QwertyKeyboardView` recomputes its own frames from `bounds` on every layout
        // pass (no cold-launch direction bug to correct), so this rebuild-once fixup only ever
        // applies to the numpad page.
        if !didInitialLayoutRebuild, let container = inputView, !container.bounds.isEmpty {
            didInitialLayoutRebuild = true
            if currentPage == .numpad { reloadItems() }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            if self.currentPage == .numpad {
                self.reloadItems()
            }
            // Re-clamp for the new orientation (landscape is shorter than portrait).
            self.applyDefaultHeight()
        }, completion: { _ in })
    }

    /// iPad's pinch-to-float mini keyboard vs. a narrow iPad Slide Over/multitasking window (see
    /// `KeyboardHeightPreset.isFloatingKeyboard` for why both width and height are needed). Re-checked
    /// on every `applyDefaultHeight()` call rather than cached, so pinching in/out mid-session
    /// (without a fresh `viewWillAppear`) is still picked up the next time height is applied
    /// (rotation, settings sync, appearance).
    ///
    /// `containerHeight` here is the RAW window height (screen fallback) — deliberately NOT
    /// `KeyboardHeightPreset.clampCeilingContainerHeight`, whose small-window rejection (added
    /// for the page-switch height fix) would mask the floating mini keyboard's genuinely small
    /// (~225pt) window and break floating detection. Also deliberately NOT
    /// `inputView?.superview?.bounds.height`: that superview is the system's small placeholder
    /// input-view container on a fresh `window == nil` appearance (notification quick-reply and
    /// other lightweight hosts); trusting it here satisfied the `< 500` floating check for a
    /// perfectly normal host, which dropped the height constraint entirely.
    private var isFloatingKeyboard: Bool {
        return KeyboardHeightPreset.isFloatingKeyboard(
            isPad: traitCollection.userInterfaceIdiom == .pad,
            width: maxWidth,
            containerHeight: view.window?.bounds.height ?? UIScreen.main.bounds.height
        )
    }

    /// Install/refresh the fixed default-height constraint, on iPhone and iPad alike. No-ops (and
    /// tears down any existing constraint) on iPad's floating mini keyboard. On the QWERTY page
    /// this uses `QwertyPageHost.baseHeight` (ported verbatim from the standalone extension's own
    /// height formula) in place of the numpad's preset-based `defaultKeyboardHeight()` — same
    /// constraint, same remove/re-add pattern, just a different source height per page.
    private func applyDefaultHeight() {
        guard !isFloatingKeyboard else {
            heightConstraint?.isActive = false
            heightConstraint = nil
            return
        }
        let height = currentPage == .qwerty ? (qwertyPageHost?.baseHeight ?? defaultKeyboardHeight()) : defaultKeyboardHeight()
        if heightConstraint == nil {
            let constraint = (inputView ?? view).heightAnchor.constraint(equalToConstant: height)
            constraint.priority = UILayoutPriority(rawValue: 999)
            constraint.isActive = true
            heightConstraint = constraint
        } else {
            if heightConstraint?.constant != height {
                heightConstraint?.constant = height
            }
        }
    }

    /// The 1.5.4 default height formula with the user's preset as the base: idiom-aware preset
    /// height (falling back from an unentitled Kiosk selection to Tall) clamped to [220 portrait /
    /// 160 landscape, 50% of the container height].
    ///
    /// The clamp ceiling's `containerHeight` deliberately does NOT fall back through
    /// `inputView.superview.bounds.height` the way `maxWidth` does — see
    /// `KeyboardHeightPreset.clampCeilingContainerHeight` (also used by `isFloatingKeyboard` for the
    /// same reason). On a fresh appearance with no window yet
    /// attached (notification quick-reply and other lightweight hosts), that superview reports the
    /// system's small placeholder keyboard height rather than the real available height, which
    /// starved the 50%-of-container cap below `minHeight` and pinned every preset to the 220pt
    /// floor — the "height keeps resetting to minimum" regression.
    private func defaultKeyboardHeight() -> CGFloat {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(
            windowHeight: view.window?.bounds.height,
            screenHeight: UIScreen.main.bounds.height
        )
        let minHeight: CGFloat = isCompact ? 160 : 220
        let preset = KeyboardHeightPreset.effective(stored: KeyboardHeightPreset.selected, kioskEntitled: Monetization.isKioskHeightEntitled)
        let base = preset.baseHeight(idiom: traitCollection.userInterfaceIdiom)
        return KeyboardHeightPreset.clampedHeight(base: base, minHeight: minHeight, maxHeightCap: floor(containerHeight * 0.5))
    }

    deinit {
        SettingsSync.remove(self)
        kioskInactivityTimer?.invalidate()
        mathPreviewDebounceTimer?.invalidate()
    }

    /// Forwarded to the QWERTY page host only while it's active — the numpad has no use for this
    /// hook (Live Math Preview reacts on `textDidChange`/`selectionDidChange` instead).
    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        if currentPage == .qwerty {
            qwertyPageHost?.textWillChange(textInput)
        }
    }

    /// The system calls this whenever the document's text changes — including as a direct result of
    /// our own `textDocumentProxy.insertText`/`deleteBackward` calls, not just external edits — so
    /// it's the right hook to recompute the Live Math Preview chip on every keystroke on the numpad
    /// page, or to refresh autocap/suggestions on the QWERTY page.
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        recordKioskActivity()
        if currentPage == .qwerty {
            qwertyPageHost?.textDidChange(textInput)
        } else {
            scheduleMathPreviewRefresh()
        }
    }

    /// Moving the cursor (tap, cursor-controls pan, arrow keys) can also change what's "immediately
    /// before the cursor," so the chip must react here too, not just on text edits.
    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        recordKioskActivity()
        scheduleMathPreviewRefresh()
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
        recordKioskActivity()
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
                recordKioskActivity()
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

    /// The active custom keyboard, when the feature is unlocked and the user has built one with at
    /// least one peripheral key. Supersedes pack selection (custom keyboard v2).
    var activeCustomKeyboardConfig: CustomKeyboardConfig? {
        guard Monetization.isCustomKeyboardEntitled else { return nil }
        guard let config = CustomKeyboardStore(defaults: .group).load(), config.hasAnyKeys else { return nil }
        return config
    }

    private func refreshEffectiveKeyboardType() {
        // The custom keyboard no longer overrides packs: it renders the numpad + side columns, and the
        // selected pack flows into its top-row slot (so packs still cycle through the top row).
        let selected = KeyboardType.selected
        if UserPrefs.smartPackDefaulting, selected == .default, let pack = smartPackOverride {
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
        // Lock chips only ever render on row 0 of a locked pack (`Monetization.isKeyLocked`'s own
        // gate) — checking row 0 here mirrors StackView's per-cell check without walking the grid.
        if !lockImpressionLoggedThisAppearance, Monetization.isKeyLocked(pack: effectiveKeyboardType, row: 0) {
            lockImpressionLoggedThisAppearance = true
            LockFunnelCounters.incrementLockImpressions()
        }
        items = makeItems()
        stackView.configure(items, keyboardType: effectiveKeyboardType, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, customHasTopRow: activeCustomKeyboardConfig.map { !customKeyboardTopRow(for: $0).isEmpty }, block: { [weak self] (position, item, cell) in
            guard let self = self else { return }
            switch (item.title, item.imageName) {
            case (_, KeyGlyph.packSwitch?):
                // Optionally repurpose the pack-switch key to cycle keyboard types instead of system globe
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
                    // Not repurposed: this key drives the exact same system input-mode-list
                    // behavior as the dedicated "globe" key below, so it must carry the same
                    // VoiceOver label — `Cell.accessibilityLabel(for:)` only knows the glyph, not
                    // this runtime wiring, and defaults to "Switch pack" otherwise.
                    cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
                    cell.accessibilityLabel = NSLocalizedString("Next Keyboard", comment: "Accessibility label for the keyboard-switch (globe) key")
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
            case (String.space?, _) where UserPrefs.cursorControls:
                // Drag across the space bar to move the caret (cursor-controls feature).
                let pan = UIPanGestureRecognizer(target: self, action: #selector(spacePanned(_:)))
                cell.addGestureRecognizer(pan)
            case ("ABC"?, _):
                // Jumps to the folded-in QWERTY page (owner decision 2026-07-09); the tap action
                // itself lives in `tapped(_:)`, matching every other plain-text special key.
                cell.accessibilityLabel = NSLocalizedString("Letters", comment: "Accessibility label for the ABC key that switches to the QWERTY page")
            // GA for anyone entitled to the Units & Conversion pack or the Cooking & Baking pack
            // (owns either, or Pro); the experimental flag stays as the un-entitled DEBUG/TestFlight
            // path so testers can still exercise the overlay without buying either pack.
            case ("="?, _) where Monetization.isConversionOverlayReachable(experimentalFlagOn: FeatureFlags.conversionOverlay, unitsPackLocked: Monetization.isLocked(pack: .units), cookingPackLocked: Monetization.isLocked(pack: .cooking)):
                // Long-press "=" opens the unit-conversion overlay (the tap still calculates).
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showConversion(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
                cell.accessibilityHint = NSLocalizedString("Double tap and hold for unit conversion", comment: "VoiceOver hint for the = key")
                cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: NSLocalizedString("Show unit conversion", comment: "VoiceOver custom action for the = key")) { [weak self] _ in
                    self?.presentConversion(); return true
                }]
            default:
                // Long-press the return key opens the recent-results tape.
                if item.role == .returnKey, UserPrefs.lastResultTape {
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
        applyGlassBackdrop()
    }

    /// Install, refresh, or tear down the shared Liquid Glass backdrop behind the key grid for the
    /// "Glass"/"Glass Dark" themes. On iOS <26 (or any other theme), this simply restores the
    /// classic flat `stackView.backgroundColor` border — the translucent-gray fallback lives
    /// entirely in `UIColor.itemScheme`'s color choice, not here. Called from `viewDidLoad` and
    /// every `reloadItems()` (pack switch, rotation, `SettingsSync` — including a live theme
    /// change from the container app).
    private func applyGlassBackdrop() {
        let theme = KeyboardTheme.selectedOrAutomatic
        guard #available(iOS 26.0, *), theme.isGlass else {
            if glassBackdropView != nil {
                glassBackdropView?.removeFromSuperview()
                glassBackdropView = nil
                appliedGlassTheme = nil
            }
            stackView.backgroundColor = KeyboardTheme.scheme.border
            return
        }
        guard appliedGlassTheme != theme else {
            stackView.backgroundColor = .clear
            return
        }
        guard let container = inputView else { return }
        glassBackdropView?.removeFromSuperview()
        let effect = UIGlassEffect(style: .regular)
        effect.tintColor = (theme == .glassDark) ? UIColor.black.withAlphaComponent(0.18) : UIColor.white.withAlphaComponent(0.28)
        let backdrop = UIVisualEffectView(effect: effect)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(backdrop, belowSubview: stackView)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: stackView.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
        ])
        glassBackdropView = backdrop
        stackView.backgroundColor = .clear
        appliedGlassTheme = theme
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
        recordKioskActivity()
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
            LockFunnelCounters.incrementLockedKeyTaps()
            // The source query lets the app attribute the store visit (funnel analytics).
            // Nothing the user typed is ever included.
            if let url = URL(string: "numpad://store-preview?source=key_lock"), openContainerApp(url) {
                LockFunnelCounters.incrementStoreDeeplinkOpens()
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
        case ("="?, _) where UserPrefs.inlineCalculator: evaluateInlineExpression()
        case ("."?, _) where FeatureFlags.localeAwareSeparators:
            self.textDocumentProxy.insertText(Locale.current.decimalSeparator ?? ".")
        case (_, KeyGlyph.packSwitch?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case (_, "math"?), (_, "math2"?): KeyboardType.selected.toggleMath(); reloadItems()
        case ("ABC"?, _): switchToPage(.qwerty)
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
                    if let dtToken = DateTimeTokens.token(fromKey: token),
                       let value = DateTimeTokens.value(for: dtToken, now: Date(), locale: .current) {
                        // Date/Time pack keys insert a computed value (today's date, the time, …).
                        self.textDocumentProxy.insertText(value)
                    } else {
                        // Remappable slot keys insert their token's text (e.g. tab → "\t"), not their label.
                        self.textDocumentProxy.insertText(CustomKeys.insertedText(for: token))
                    }
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
        if UserPrefs.lastResultTape { ResultTape.shared.add(formatted) }
    }

    // MARK: - Live Math Preview (compute-as-you-type result chip)

    /// Create the chip and pin it to the container's top-trailing corner (leading/trailing anchors,
    /// so it's RTL-safe automatically), hidden until the first valid expression appears. Called once
    /// from `viewDidLoad`, after the key grid already exists, so the chip is always the last subview
    /// added — guaranteeing it draws on top of the keys without participating in their layout.
    func installMathPreviewChip() {
        guard mathPreviewChip == nil, let container = self.inputView else { return }
        let chip = MathPreviewChipView()
        chip.delegate = self
        chip.onUserActivity = { [weak self] in self?.recordKioskActivity() }
        chip.isHidden = true
        chip.alpha = 0
        container.addSubview(chip)
        chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chip.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            chip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            chip.heightAnchor.constraint(equalToConstant: 28)
        ])
        mathPreviewChip = chip
    }

    /// Cheap synchronous guard, then a tiny debounce before the real parse/evaluate. Call on every
    /// `textDidChange`/`selectionDidChange`. A failed guard hides the chip immediately (no
    /// debounce, no timer allocation) — it must never linger once the trailing text can't possibly
    /// be an expression, e.g. the moment a letter or space follows a number.
    func scheduleMathPreviewRefresh() {
        guard currentPage == .numpad,
              LiveMathPreview.isEnabled, !isFloatingKeyboard, !isAnyOverlayPresented,
              let before = textDocumentProxy.documentContextBeforeInput,
              MathPreviewChip.lastCharacterCouldEndExpression(before) else {
            hideMathPreviewChip()
            return
        }
        mathPreviewDebounceTimer?.invalidate()
        mathPreviewDebounceTimer = Timer.scheduledTimer(withTimeInterval: Self.mathPreviewDebounceInterval, repeats: false) { [weak self] _ in
            self?.refreshMathPreviewChip()
        }
    }

    /// The real (still cheap, but non-trivial) evaluation, run after the debounce settles.
    /// Guards are re-checked here since state (an overlay opening, the floating-keyboard state)
    /// can change during the debounce window.
    private func refreshMathPreviewChip() {
        guard currentPage == .numpad,
              LiveMathPreview.isEnabled, !isFloatingKeyboard, !isAnyOverlayPresented,
              let before = textDocumentProxy.documentContextBeforeInput else {
            hideMathPreviewChip()
            return
        }
        let separator = FeatureFlags.localeAwareSeparators ? (Locale.current.decimalSeparator ?? ".") : "."
        guard let decision = MathPreviewChip.decide(textBeforeCursor: before, decimalSeparator: separator) else {
            hideMathPreviewChip()
            return
        }
        showMathPreviewChip(decision)
    }

    private func showMathPreviewChip(_ decision: MathPreviewChip.Decision) {
        guard let chip = mathPreviewChip else { return }
        // Session-throttled: once per appearance, not once per render (the chip can redraw many
        // times a second while typing a multi-digit number).
        if !mathPreviewShownLoggedThisAppearance {
            mathPreviewShownLoggedThisAppearance = true
            MathPreviewCounters.incrementShown()
        }
        pendingMathPreviewDecision = decision
        chip.setResultText(decision.displayText)
        guard chip.isHidden else { return } // already visible — text just updated above, no re-animate
        chip.isHidden = false
        if UIAccessibility.isReduceMotionEnabled {
            chip.alpha = 1
        } else {
            UIView.animate(withDuration: 0.15) { chip.alpha = 1 }
        }
    }

    /// Also cancels any pending debounce timer, so a hide (overlay opening, expression turning
    /// invalid, settings toggled off) can never be raced by a stale timer firing right after.
    func hideMathPreviewChip() {
        mathPreviewDebounceTimer?.invalidate()
        mathPreviewDebounceTimer = nil
        pendingMathPreviewDecision = nil
        guard let chip = mathPreviewChip, !chip.isHidden else { return }
        if UIAccessibility.isReduceMotionEnabled {
            chip.alpha = 0
            chip.isHidden = true
        } else {
            UIView.animate(withDuration: 0.15, animations: { chip.alpha = 0 }, completion: { _ in chip.isHidden = true })
        }
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
    // MARK: - Kiosk inactivity

    func recordKioskActivity() {
        guard let configuration = KioskSessionPolicy.activeConfiguration() else { return }
        let evaluation = kioskSessionClock.evaluateBeforeRecordingActivity(
            configuration: configuration
        )
        applyKioskEvaluation(evaluation)
    }

    private func startKioskInactivityMonitor() {
        kioskInactivityTimer?.invalidate()
        kioskInactivityTimer = nil
        guard KioskSessionPolicy.activeConfiguration() != nil else { return }
        kioskInactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.evaluateKioskInactivity()
        }
    }

    private func evaluateKioskInactivity() {
        guard let configuration = KioskSessionPolicy.activeConfiguration() else {
            kioskInactivityTimer?.invalidate()
            kioskInactivityTimer = nil
            return
        }
        let evaluation = kioskSessionClock.evaluateWithoutRecordingActivity(
            configuration: configuration
        )
        guard !evaluation.actions.isEmpty else { return }
        applyKioskEvaluation(evaluation)
        // The reset itself starts a clean kiosk session and prevents the repeating timer from
        // reapplying the same expired reset every five seconds.
        kioskSessionClock.recordActivity()
    }

    private func applyKioskEvaluation(_ evaluation: KioskSessionEvaluation) {
        guard !evaluation.actions.isEmpty else { return }
        if evaluation.actions.contains(.dismissOverlays) {
            dismissOverlays()
        }
        if evaluation.actions.contains(.clearResultTape) {
            ResultTape.shared.clear()
        }
        if evaluation.actions.contains(.clearClipboardHistory) {
            ClipboardHistoryManager.shared.clear()
        }
        if evaluation.actions.contains(.resetPageAndPack) {
            KeyboardType.selected = evaluation.resetPack
            let resetPage = Page(rawValue: evaluation.resetPage) ?? .numpad
            UserPrefs.keyboardPageRaw = resetPage.rawValue
            if currentPage != resetPage {
                switchToPage(resetPage, persist: true)
            } else {
                reloadItems()
            }
        }
        SettingsSync.post()
    }

    func dismissOverlays() {

        clipboardView?.removeFromSuperview(); clipboardView = nil
        snippetsView?.removeFromSuperview(); snippetsView = nil
        taxTipView?.removeFromSuperview(); taxTipView = nil
        packPickerView?.removeFromSuperview(); packPickerView = nil
        conversionView?.removeFromSuperview(); conversionView = nil
        resultTapeView?.removeFromSuperview(); resultTapeView = nil
        stackTopConstraint?.isActive = true
        stackTrailingConstraint?.isActive = true
        // The chip must never linger over (or fight for space with) a full overlay.
        hideMathPreviewChip()
    }

    /// Whether any calculator-style or list overlay is currently presented. The Live Math Preview
    /// chip must stay hidden while any of these are up — they cover the same visual territory and
    /// the numpad taps are routed away from the host document into the overlay while they're shown.
    private var isAnyOverlayPresented: Bool {
        clipboardView != nil || snippetsView != nil || taxTipView != nil
            || packPickerView != nil || conversionView != nil || resultTapeView != nil
    }

    func makeItems() -> [[Item]] {
        let rtl = self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        // With the pack-switch key repurposed to cycle packs (the default), the numpad still
        // needs its own globe key on Home-button devices (iOS draws no system affordance
        // there). Reaching the QWERTY page never needs the globe — it's the in-keyboard ABC
        // key (single-keyboard architecture, owner decision 2026-07-09).
        let needsDedicatedSwitchKey = Keyboard.numpadNeedsDedicatedSwitchKey(
            systemNeedsSwitchKey: needsInputModeSwitchKey,
            repurposeNextKey: UserPrefs.repurposeNextKey)
        if let config = activeCustomKeyboardConfig {
            // The custom keyboard renders the numpad + the user's side columns; the digits stay fixed
            // and the switch key is always emitted (the two springboard device bugs gone). The top row
            // is the selected pack's row, or the custom top row when no pack is selected — so packs
            // still cycle through the top while the columns persist.
            let body = CustomKeyboardLayout.bodyRows(for: config, handedness: UserPrefs.handedness,
                                                     needsSwitchKey: needsDedicatedSwitchKey, reversed: Keyboard.isReversedMode)
            var items = CustomKeyboardItems.items(for: body, returnKeyTitle: returnKeyTitle())
            let topRow = customKeyboardTopRow(for: config)
            if !topRow.isEmpty { items.insert(topRow, at: 0) }
            return rtl ? insertingQwertyPageKey(items).map { $0.reversed() } : insertingQwertyPageKey(items)
        }
        let items = Item.all(type: effectiveKeyboardType, includeSwitchKey: needsDedicatedSwitchKey, returnKeyTitle: returnKeyTitle())
        return rtl ? insertingQwertyPageKey(items).map { $0.reversed() } : insertingQwertyPageKey(items)
    }

    /// "ABC" jumps to the folded-in QWERTY page (owner decision 2026-07-09), in BOTH layout
    /// branches (the Custom Keyboard's fixed bottom row included: a custom layout must never
    /// lose access to the QWERTY page). Bottom-row order per owner note 2026-07-10: ABC
    /// leftmost, 0 centered under the digit grid, pack-switch immediately right of 0 — so the
    /// pack switcher moves out of its legacy leading slot whenever the QWERTY page is
    /// reachable. Absent entirely when the page isn't available: the numpad renders
    /// byte-for-byte as it did pre-merge.
    private func insertingQwertyPageKey(_ items: [[Item]]) -> [[Item]] {
        guard qwertyPageAvailable, var bottomRow = items.last else { return items }
        let packSwitch = bottomRow.firstIndex { $0.imageName == KeyGlyph.packSwitch }
            .map { bottomRow.remove(at: $0) }
        bottomRow.insert(Item(title: "ABC", font: .text, style: .primary), at: 0)
        if let packSwitch = packSwitch {
            let zeroIndex = bottomRow.firstIndex { $0.title == "0" }
            bottomRow.insert(packSwitch, at: zeroIndex.map { $0 + 1 } ?? min(2, bottomRow.count))
        }
        var updated = items
        updated[updated.count - 1] = bottomRow
        return updated
    }

    /// The custom keyboard's top-row slot: the selected pack's row when a real pack is active, else
    /// the user's custom top row (empty when neither). Tokens render via the same path as the
    /// right-side slots, so literals and {space}/{tab}/{left}/{right}/{dismiss} insert correctly.
    private func customKeyboardTopRow(for config: CustomKeyboardConfig) -> [Item] {
        let packRow = Item.packRow(for: effectiveKeyboardType)
        if !packRow.isEmpty { return packRow }
        return config.topRowKeys.filter { !$0.isEmpty }.map {
            Item(title: CustomKeys.displayName(for: $0), actionToken: $0)
        }
    }

    // MARK: - Pages (numpad ↔ QWERTY, owner decision 2026-07-09)

    /// Reconciles the in-memory `currentPage` with the persisted selection and the current
    /// rollout/entitlement gate — called on every appearance and every settings sync so a gate
    /// change (Pro purchase, RC kill switch) or a persisted QWERTY selection takes effect without
    /// an explicit page switch. Never mutates the persisted value: a gate that's merely
    /// temporarily off must not overwrite the user's saved QWERTY choice.
    private func syncPageWithPersistedState() {
        let persisted = Page(rawValue: UserPrefs.keyboardPageRaw) ?? .numpad
        let target: Page = (persisted == .qwerty && qwertyPageAvailable) ? .qwerty : .numpad
        guard target != currentPage else { return }
        switchToPage(target, persist: false)
    }

    /// Switches the visible page: dismisses numpad-only overlays/chip, swaps which content view
    /// is hidden, and rebuilds the height constraint via the same remove-then-reactivate pattern
    /// `applyDefaultHeight()` already uses for the iPad height-drift fix. `persist` is false only
    /// for gate-driven fallbacks (`syncPageWithPersistedState`), never for an explicit user choice.
    private func switchToPage(_ page: Page, persist: Bool = true) {
        guard page != currentPage else { return }
        dismissOverlays()
        hideMathPreviewChip()
        currentPage = page
        if persist { UserPrefs.keyboardPageRaw = page.rawValue }
        switch page {
        case .numpad:
            qwertyPageHost?.containerView.isHidden = true
            stackView.isHidden = false
            reloadItems()
        case .qwerty:
            stackView.isHidden = true
            let host = qwertyHost()
            host.needsInputModeSwitchKey = needsInputModeSwitchKey
            host.containerView.isHidden = false
            // `persist` is true exactly when this is the user's explicit ABC tap from the
            // numpad page — the strip then uses numpad-context (canvas) semantics; gate-driven
            // restores on raise keep the normal number-row default.
            host.activate(fromNumpadPage: persist)
        }
        heightConstraint?.isActive = false
        heightConstraint = nil
        applyDefaultHeight()
    }

    /// Lazily creates the QWERTY page host and pins its container to the same edges `stackView`
    /// already occupies. Both stay mounted afterward — page switches only toggle `isHidden`.
    private func qwertyHost() -> QwertyPageHost {
        if let existing = qwertyPageHost { return existing }
        let host = QwertyPageHost(
            hostViewController: self,
            textDocumentProxyProvider: { [unowned self] in self.textDocumentProxy },
            dismissKeyboard: { [unowned self] in self.dismissKeyboard() },
            advanceToNextInputMode: { [unowned self] in self.advanceToNextInputMode() },
            switchToNumpadPage: { [unowned self] in self.switchToPage(.numpad) },
            keyTouchDownFeedback: { [unowned self] in self.playClick() },
            onUserActivity: { [unowned self] in self.recordKioskActivity() })
        host.containerView.isHidden = true
        if let container = inputView {
            container.addSubview(host.containerView)
            host.containerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.containerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                host.containerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                host.containerView.topAnchor.constraint(equalTo: container.topAnchor),
                host.containerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        qwertyPageHost = host
        return host
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
        recordKioskActivity()
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
        recordKioskActivity()
        dismissOverlays()
        captureCurrentPasteboardItem()
        let view = ClipboardHistoryView()
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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
        recordKioskActivity()
        dismissOverlays()
        let view = SnippetsListView()
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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
        recordKioskActivity()
        dismissOverlays()
        let view = PackPickerView()
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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
        LockFunnelCounters.incrementLockedKeyTaps()
        if let url = URL(string: "numpad://store-preview?source=pack_picker"), openContainerApp(url) {
            LockFunnelCounters.incrementStoreDeeplinkOpens()
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
        recordKioskActivity()
        dismissOverlays()
        let view = TaxTipView()
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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
        recordKioskActivity()
        dismissOverlays()
        // Same-pack scoping as the long-press gate above: a buyer of only Units & Conversion (or
        // only Cooking & Baking) must only see their own pack's categories in the picker.
        let entitledCategories = Monetization.entitledConversionCategories(
            experimentalFlagOn: FeatureFlags.conversionOverlay,
            unitsPackLocked: Monetization.isLocked(pack: .units),
            cookingPackLocked: Monetization.isLocked(pack: .cooking))
        let view = ConversionView(entitledCategories: entitledCategories)
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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
    func conversionViewDidSelectLockedCategory(_ view: ConversionView) {
        dismissOverlays()
        LockFunnelCounters.incrementLockedKeyTaps()
        // Distinct source from "key_lock"/"pack_picker" so the store-visit funnel can attribute
        // this entry point separately; StoreViewController.source has no per-source copy switch
        // (it's only used for Analytics attribution), so any new source string is safe.
        if let url = URL(string: "numpad://store-preview?source=conversion_lock"), openContainerApp(url) {
            LockFunnelCounters.incrementStoreDeeplinkOpens()
        }
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
        recordKioskActivity()
        dismissOverlays()
        let view = ResultTapeView()
        view.delegate = self
        view.onUserActivity = { [weak self] in self?.recordKioskActivity() }
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

// MARK: - Live Math Preview chip
extension KeyboardViewController: MathPreviewChipViewDelegate {
    /// Insert the chip's result exactly as the "=" key would (delete the matched trailing
    /// expression, insert the formatted result), and feed the same result tape.
    func mathPreviewChipViewDidTapInsert(_ view: MathPreviewChipView) {
        guard let decision = pendingMathPreviewDecision else { return }
        let proxy = textDocumentProxy
        for _ in 0..<decision.expression.count { proxy.deleteBackward() }
        proxy.insertText(decision.insertText)
        if UserPrefs.lastResultTape { ResultTape.shared.add(decision.insertText) }
        MathPreviewCounters.incrementInserted()
        hideMathPreviewChip()
    }
}
