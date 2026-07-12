//
//  QwertyPageHost.swift
//  Keyboard
//
//  Hosts the full-QWERTY "NumPad Type" page inside the numpad keyboard extension —
//  single keyboard in iOS Settings, one Full Access grant, two pages (owner decision
//  2026-07-09, superseding the separate KeyboardType extension). Ports the glue
//  previously in KeyboardType/QwertyKeyboardViewController.swift; the numpad-flip
//  canvas (`Canvas` enum / `.numpad` case) is gone — the numpad-flip key now leaves
//  this page entirely via `switchToNumpadPage` (see the `.numpadFlip` case below).
//

import UIKit

/// Not a `UIInputViewController` — this page shares one with the numpad page
/// (`KeyboardViewController`), which injects everything this host can't own itself:
/// the text document proxy, `dismissKeyboard()`/`advanceToNextInputMode()`, and — as
/// `hostViewController` — the target for the globe key's `handleInputModeList(from:with:)`.
final class QwertyPageHost: NSObject {

    // MARK: - Injected dependencies

    /// Target for `handleInputModeList(from:with:)` — the globe key must call the *host*
    /// VC's inherited selector, exactly as the standalone extension called it on `self`.
    private weak var hostViewController: UIInputViewController?
    private let textDocumentProxyProvider: () -> UITextDocumentProxy
    private let dismissKeyboard: () -> Void
    private let advanceToNextInputMode: () -> Void
    /// The numpad-flip key's destination now (owner note 2026-07-09): the real numpad
    /// page, not an internal canvas.
    private let switchToNumpadPage: () -> Void

    /// Mirrors `UIInputViewController.needsInputModeSwitchKey`, refreshed by the host VC
    /// whenever it might change (appearance, rotation, settings sync) since this host has
    /// no input-view-controller lifecycle of its own to read it from directly.
    var needsInputModeSwitchKey = true

    private var textDocumentProxy: UITextDocumentProxy { textDocumentProxyProvider() }

    // MARK: - Views

    /// Full-bleed container the host VC pins to the same edges as its numpad `stackView`;
    /// page switches just toggle `isHidden` on the two so both stay mounted afterward.
    let containerView = UIView()
    private let suggestionBar = QwertySuggestionBarView()
    private let keyboardView = QwertyKeyboardView()
    private let spellChecker = QwertySpellChecker()
    /// Frequency re-ranker for the checker's raw output (design doc
    /// docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §1: re-rank,
    /// never replace — `UITextChecker` stays the sole spelling authority; this fixes its
    /// documented alphabetical `completions(forPartialWordRange:)` ordering). `.main` is
    /// the extension bundle here, which carries `qwerty_lexicon_en.bin`; a missing
    /// resource degrades to an empty lexicon whose `rerank(_:)` is the identity.
    private let frequencyLexicon = QwertyFrequencyLexicon(bundled: .main)

    // MARK: - State (ported from QwertyKeyboardViewController)

    private var shift = QwertyShiftMachine()
    private var autocorrectHistory = QwertyAutocorrectHistory()
    private var activeLayer: QwertyLayer = .letters
    /// The pack on the top strip; nil = the persistent number row (owner decision §0.3).
    private var activeTopStripPack: KeyboardType?
    private var lastSpaceTap: TimeInterval?
    private var backspaceRepeatTimer: Timer?
    /// Steps already applied during the current space-bar cursor drag.
    private var spacePanAppliedSteps = 0
    /// The period/comma setting the current key grid was built with (change detection for
    /// `settingsDidChange`).
    private var appliedPeriodComma: Bool?
    /// The theme the current key grid was built with — a theme change from the app rebuilds
    /// the keys so every button re-reads its palette.
    private var appliedTheme: KeyboardTheme?

    private enum Metrics {
        static let suggestionBarHeight: CGFloat = 44
    }

    /// Base canvas height (suggestion bar + top strip + four key rows), ported verbatim from
    /// `QwertyKeyboardViewController.baseHeight`. iPad and preset-aware heights follow the
    /// numpad extension's `KeyboardHeightPreset` in a later pass; the exact numbers are
    /// re-measured in the Phase-3 device gates (docs/plans/full-keyboard/).
    var baseHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 384 : 344
    }

    init(hostViewController: UIInputViewController,
         textDocumentProxyProvider: @escaping () -> UITextDocumentProxy,
         dismissKeyboard: @escaping () -> Void,
         advanceToNextInputMode: @escaping () -> Void,
         switchToNumpadPage: @escaping () -> Void) {
        self.hostViewController = hostViewController
        self.textDocumentProxyProvider = textDocumentProxyProvider
        self.dismissKeyboard = dismissKeyboard
        self.advanceToNextInputMode = advanceToNextInputMode
        self.switchToNumpadPage = switchToNumpadPage
        super.init()
        buildViewHierarchy()
        suggestionBar.delegate = self
        keyboardView.delegate = self
        spellChecker.loadLexicon(from: hostViewController)
    }

    deinit {
        backspaceRepeatTimer?.invalidate()
    }

    private func buildViewHierarchy() {
        containerView.addSubview(suggestionBar)
        containerView.addSubview(keyboardView)
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: Metrics.suggestionBarHeight),
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }

    // MARK: - Lifecycle hooks (called by KeyboardViewController)

    /// Whether this page was entered from the numpad page (the ABC key) rather than a fresh
    /// keyboard raise. In numpad context the strip uses `QwertyPackFamily`'s canvas semantics
    /// (owner note 2026-07-10: "when selecting abc, the number row should change to alternative
    /// keys"): a nil selection auto-swaps the strip to the first entitled pack (Grammar), and
    /// pack cycling skips the plain number line — digits are one ABC/NumPad tap away.
    private var stripNumpadContext = false

    /// Called every time the QWERTY page becomes the visible page — mirrors
    /// `QwertyKeyboardViewController.viewWillAppear` (minus the height constraint, which the
    /// host VC now owns alongside the numpad's, and minus the availability lock overlay: the
    /// host VC's page-level gate already prevents reaching this page unless entitled/active,
    /// and bounces back to the numpad page instead if that stops being true mid-session).
    func activate(fromNumpadPage: Bool = false) {
        stripNumpadContext = fromNumpadPage
        activeTopStripPack = resolvedTopStripPack()
        reloadKeys()
        refreshAutocap()
        refreshSuggestions()
    }

    func textWillChange(_ textInput: UITextInput?) {
        // No behavior of its own (system hook only) — kept for API parity with textDidChange.
    }

    func textDidChange(_ textInput: UITextInput?) {
        refreshAutocap()
        refreshSuggestions()
    }

    /// SettingsSync-driven reload, forwarded by the host VC's own observer only while this page
    /// is active: reload only what actually differs, so a live keyboard never rebuilds its keys
    /// twice for one tap.
    func settingsDidChange() {
        let periodComma = UserPrefs.qwertyPeriodComma
        let theme = KeyboardTheme.selectedOrAutomatic
        // Only an EXTERNAL strip change (the wizard's default-pack edits in the app) re-resolves
        // the strip. The pack-switch key writes `qwertyTopStripPack` itself and posts
        // SettingsSync — re-resolving through `packDisplayBehavior` on that same-process echo
        // snapped a PRIMARY-SELECTED user's fresh in-session pack straight back to their
        // primary (owner-reported: "packs do not change when selected in qwerty mode").
        let stripChangedExternally = UserPrefs.qwertyTopStripPack != activeTopStripPack
        if stripChangedExternally || periodComma != appliedPeriodComma || theme != appliedTheme {
            if stripChangedExternally { activeTopStripPack = resolvedTopStripPack() }
            reloadKeys()
        }
    }

    // MARK: - Keyboard assembly

    private var layoutOptions: QwertyLayoutOptions {
        QwertyLayoutOptions(periodCommaOnLetters: UserPrefs.qwertyPeriodComma,
                            needsSwitchKey: needsInputModeSwitchKey,
                            needsDismissKey: UIDevice.current.userInterfaceIdiom == .pad)
    }

    private func reloadKeys() {
        keyboardView.returnKeyLabel = returnKeyLabel()
        let options = layoutOptions
        appliedPeriodComma = options.periodCommaOnLetters
        appliedTheme = KeyboardTheme.selectedOrAutomatic
        let strip = QwertyTopStrip.keys(for: currentTopStrip())
        keyboardView.configure(rows: QwertyLayout.rows(layer: activeLayer, options: options),
                               topStrip: strip)
        keyboardView.update(shiftState: shift.state)
    }

    // MARK: - Top strip (swappable number line, owner decision §0.3)

    /// The canvas-auto-swap semantics apply exactly when this page was entered from the numpad
    /// page (`stripNumpadContext`) — the flip canvas itself is gone, but "arrived from a grid
    /// of digits" carries the same meaning it did (owner note 2026-07-10).
    private func currentTopStrip() -> QwertyTopStrip {
        let pack = QwertyPackFamily.stripPack(selected: activeTopStripPack,
                                              numpadCanvas: stripNumpadContext,
                                              entitled: isPackAvailable)
        guard let pack = pack else { return .numbers }
        let content = QwertyPackFamily.content(for: pack,
                                               customKeys: CustomPackManager.shared.keys,
                                               snippets: SnippetsManager.shared.snippets)
        return content.isEmpty ? .numbers : .pack(content)
    }

    /// The persisted strip selection, validated against the crossover family and current
    /// entitlements (LAST-USED vs PRIMARY-SELECTED per owner decision §0.4).
    private func resolvedTopStripPack() -> KeyboardType? {
        let pack = QwertyPackFamily.packToShow(behavior: UserPrefs.packDisplayBehavior,
                                               lastUsed: UserPrefs.qwertyTopStripPack,
                                               primary: UserPrefs.qwertyPrimaryPack)
        guard let pack = pack, QwertyPackFamily.members.contains(pack),
              isPackAvailable(pack) else { return nil }
        return pack
    }

    /// Same entitlement machinery as the numpad (no new gating system); Custom additionally
    /// needs at least one authored key, and the Snippets row needs at least one snippet —
    /// cycling skips an empty row rather than flashing a blank strip.
    private func isPackAvailable(_ pack: KeyboardType) -> Bool {
        guard !Monetization.isLocked(pack: pack) else { return false }
        if pack == .custom { return !CustomPackManager.shared.keys.isEmpty }
        if pack == .snippets { return SnippetsManager.shared.snippets.contains { !$0.text.isEmpty } }
        return true
    }

    private func returnKeyLabel() -> String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return NSLocalizedString("go", comment: "return key")
        case .search, .google, .yahoo: return NSLocalizedString("search", comment: "return key")
        case .done: return NSLocalizedString("done", comment: "return key")
        case .send: return NSLocalizedString("send", comment: "return key")
        case .next: return NSLocalizedString("next", comment: "return key")
        case .join: return NSLocalizedString("join", comment: "return key")
        case .route: return NSLocalizedString("route", comment: "return key")
        case .continue: return NSLocalizedString("continue", comment: "return key")
        case .emergencyCall: return NSLocalizedString("emergency", comment: "return key")
        case .default: return NSLocalizedString("return", comment: "return key")
        @unknown default: return NSLocalizedString("return", comment: "return key")
        }
    }

    // MARK: - Typing pipeline (ported verbatim)

    /// Inserts a word-boundary character, running the autocorrect pass first (lexicon
    /// expansion beats spell correction — system Text Replacement parity).
    private func insertBoundary(_ text: String) {
        applyPendingCorrection()
        textDocumentProxy.insertText(text)
        didInsert(text)
    }

    private func applyPendingCorrection() {
        guard let word = QwertyAutocorrect.currentWord(
            before: textDocumentProxy.documentContextBeforeInput) else { return }

        if let expansion = QwertyAutocorrect.lexiconExpansion(word: word,
                                                              lexicon: spellChecker.lexicon) {
            replaceCurrentWord(word, with: expansion)
            autocorrectHistory.recordCorrection(original: word, corrected: expansion)
            return
        }

        let analysis = spellChecker.analyze(word: word)
        // Re-ranked guesses deliberately change which correction auto-applies: the
        // highest-FREQUENCY guess wins, not whichever UITextChecker happened to list first.
        let decision = QwertyAutocorrect.decide(word: word,
                                                isMisspelled: analysis.isMisspelled,
                                                guesses: frequencyLexicon.rerank(analysis.guesses),
                                                userRejected: autocorrectHistory.rejectedWords)
        if case .replace(let corrected) = decision {
            replaceCurrentWord(word, with: corrected)
            autocorrectHistory.recordCorrection(original: word, corrected: corrected)
        }
    }

    private func replaceCurrentWord(_ word: String, with replacement: String) {
        for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement)
    }

    private func handleSpace() {
        applyPendingCorrection()
        let now = CACurrentMediaTime()
        let decision = DoubleSpacePeriod.decision(
            before: textDocumentProxy.documentContextBeforeInput,
            secondsSinceLastSpaceTap: lastSpaceTap.map { now - $0 },
            enabled: true)  // becomes a UserPrefs toggle in the settings pass
        if decision.deletions > 0 {
            // The boundary after a pending correction just changed shape ("x " → "x. ") —
            // the one-backspace revert contract no longer holds.
            autocorrectHistory.noteOtherEdit()
        }
        for _ in 0..<decision.deletions { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(decision.insertion)
        lastSpaceTap = now
        didInsert(decision.insertion)
    }

    private func handleBackspace() {
        if let revert = autocorrectHistory.consumeRevert(), revertIsApplicable(revert) {
            textDocumentProxy.deleteBackward()  // the boundary character
            for _ in 0..<revert.deletions { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(revert.insertion)
        } else {
            textDocumentProxy.deleteBackward()
        }
        refreshAutocap()
        refreshSuggestions()
    }

    /// The revert contract assumes the caret still sits right after "<corrected><boundary>";
    /// if the host app moved the caret since, fall back to a plain delete.
    private func revertIsApplicable(_ revert: QwertyAutocorrectHistory.Revert) -> Bool {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              context.count >= revert.corrected.count + 1 else { return false }
        return String(context.dropLast()).hasSuffix(revert.corrected)
    }

    /// Shared post-insertion bookkeeping: consume one-shot shift, apply layer bounce rules,
    /// and re-evaluate autocap and suggestions against the new context.
    private func didInsert(_ text: String) {
        shift.didInsertCharacter(text)
        let bounced = QwertyLayerRules.layer(afterInserting: text, on: activeLayer)
        if bounced != activeLayer {
            activeLayer = bounced
            reloadKeys()
        }
        refreshAutocap()
        refreshSuggestions()
    }

    private func refreshAutocap() {
        let raw = textDocumentProxy.autocapitalizationType?.rawValue
        let policy = raw.flatMap(QwertyAutocapPolicy.init(rawValue:)) ?? .sentences
        let verdict = QwertyAutocap.shouldCapitalize(
            policy: policy,
            before: textDocumentProxy.documentContextBeforeInput)
        shift.evaluateAutocap(shouldCapitalize: verdict)
        keyboardView.update(shiftState: shift.state)
    }

    private func refreshSuggestions() {
        guard let word = QwertyAutocorrect.currentWord(
            before: textDocumentProxy.documentContextBeforeInput) else {
            suggestionBar.clear()
            keyboardView.touchBias = [:]
            return
        }
        let analysis = spellChecker.analyze(word: word)
        let completions = frequencyLexicon.rerank(analysis.completions)
        suggestionBar.show(QwertyAutocorrect.suggestions(word: word,
                                                         guesses: frequencyLexicon.rerank(analysis.guesses),
                                                         completions: completions))
        // Zero-dead-zone touch routing bias (owner note 4): reuses the completions this method
        // already computed above — no extra spell-checker work. Feeding it the RE-RANKED list
        // is deliberate: its 1/(rank+1) weights now reflect frequency order, so the
        // likely-next-key bias improves for free.
        keyboardView.touchBias = QwertyTouchRouting.bias(forCompletions: completions,
                                                         currentWord: word,
                                                         keyOutputs: keyboardView.characterKeyOutputs)
    }

    // MARK: - Space-bar cursor drag (system-keyboard gesture parity, plan §2)

    /// Horizontal drag on the space bar moves the caret — one character per `stepWidth`
    /// points, matching the system keyboard's space-bar trackpad interaction. A plain tap
    /// never moves enough to trigger the pan, so typing a space is unaffected.
    @objc private func spacePanned(_ recognizer: UIPanGestureRecognizer) {
        let stepWidth: CGFloat = 8
        switch recognizer.state {
        case .began:
            spacePanAppliedSteps = 0
            autocorrectHistory.noteOtherEdit()
        case .changed:
            let steps = Int(recognizer.translation(in: containerView).x / stepWidth)
            let delta = steps - spacePanAppliedSteps
            guard delta != 0 else { return }
            textDocumentProxy.adjustTextPosition(byCharacterOffset: delta)
            spacePanAppliedSteps = steps
        case .ended, .cancelled, .failed:
            refreshAutocap()
            refreshSuggestions()
        default:
            break
        }
    }

    // MARK: - Backspace autorepeat

    @objc private func backspaceLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            autocorrectHistory.noteOtherEdit()
            backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1,
                                                        repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
                self?.refreshAutocap()
            }
        case .ended, .cancelled, .failed:
            backspaceRepeatTimer?.invalidate()
            backspaceRepeatTimer = nil
            refreshSuggestions()
        default:
            break
        }
    }
}

// MARK: - QwertyKeyboardViewDelegate

extension QwertyPageHost: QwertyKeyboardViewDelegate {

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey) {
        switch key.kind {
        case .character:
            guard let text = shift.output(for: key) else { return }
            if QwertyAutocorrect.isBoundary(text) {
                insertBoundary(text)
            } else {
                autocorrectHistory.noteOtherEdit()
                textDocumentProxy.insertText(text)
                didInsert(text)
            }
        case .space:
            handleSpace()
        case .backspace:
            handleBackspace()
        case .ret:
            insertBoundary("\n")
        case .shift:
            shift.shiftTapped(at: CACurrentMediaTime())
            view.update(shiftState: shift.state)
        case .layerSwitch(let layer):
            activeLayer = layer
            reloadKeys()
        case .globe:
            break  // handled at the button level via handleInputModeList(from:with:)
        case .numpadFlip:
            // Leaves this page entirely now — the real numpad, not an internal canvas.
            switchToNumpadPage()
        case .packSwitch:
            // Cycle from what's displayed. In numpad context (entered via ABC) the canvas
            // semantics skip the plain number line; on a fresh raise the number row cycles
            // normally (owner decision §0.3 + owner note 2026-07-10).
            let displayed = QwertyPackFamily.stripPack(selected: activeTopStripPack,
                                                       numpadCanvas: stripNumpadContext,
                                                       entitled: isPackAvailable)
            let next = QwertyPackFamily.nextStripPack(afterDisplayed: displayed,
                                                      numpadCanvas: stripNumpadContext,
                                                      entitled: isPackAvailable)
            activeTopStripPack = next
            UserPrefs.qwertyTopStripPack = next
            SettingsSync.post()
            // Strip-only swap — never rebuild the main rows for a top-strip change.
            view.updateTopStrip(QwertyTopStrip.keys(for: currentTopStrip()))
        case .dateTimeToken(_, let token):
            guard let value = DateTimeTokens.value(for: token, now: Date(), locale: .current) else {
                return
            }
            autocorrectHistory.noteOtherEdit()
            textDocumentProxy.insertText(value)
            didInsert(value)
        case .snippet(_, let text):
            // Insert-time token expansion — the same rule as the snippets overlay, so
            // "Invoice {date}" always inserts today's date.
            let value = Snippet.expand(text, now: Date())
            autocorrectHistory.noteOtherEdit()
            textDocumentProxy.insertText(value)
            didInsert(value)
        case .dismissKeyboard:
            dismissKeyboard()
        }
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didCreate button: QwertyKeyButton,
                            for key: QwertyKey) {
        switch key.kind {
        case .globe:
            // The documented wiring: tap advances, long-press shows the system keyboard
            // list, pixel-identical to the native globe (technical doc §1/§4). Targets the
            // *host* VC — this object isn't a UIInputViewController itself.
            button.addTarget(hostViewController,
                             action: #selector(UIInputViewController.handleInputModeList(from:with:)),
                             for: .allTouchEvents)
        case .backspace:
            let recognizer = UILongPressGestureRecognizer(target: self,
                                                          action: #selector(backspaceLongPressed(_:)))
            recognizer.minimumPressDuration = 0.5
            button.addGestureRecognizer(recognizer)
        case .space:
            let recognizer = UIPanGestureRecognizer(target: self,
                                                    action: #selector(spacePanned(_:)))
            button.addGestureRecognizer(recognizer)
        default:
            break
        }
    }
}

// MARK: - QwertySuggestionBarViewDelegate

extension QwertyPageHost: QwertySuggestionBarViewDelegate {

    func suggestionBar(_ bar: QwertySuggestionBarView,
                       didSelect suggestion: QwertyAutocorrect.Suggestion) {
        autocorrectHistory.noteOtherEdit()
        switch suggestion {
        case .literal(let word):
            // Accept the word exactly as typed — and never auto-correct it this session.
            autocorrectHistory.reject(word)
            textDocumentProxy.insertText(" ")
        case .candidate(let word):
            if let current = QwertyAutocorrect.currentWord(
                before: textDocumentProxy.documentContextBeforeInput) {
                replaceCurrentWord(current, with: word)
            } else {
                textDocumentProxy.insertText(word)
            }
            textDocumentProxy.insertText(" ")
        }
        didInsert(" ")
    }
}
