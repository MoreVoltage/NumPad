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
@MainActor
final class QwertyPageHost: NSObject {

    // MARK: - Injected dependencies

    /// Target for `handleInputModeList(from:with:)` — the globe key must call the *host*
    /// VC's inherited selector, exactly as the standalone extension called it on `self`.
    private weak var hostViewController: UIInputViewController?
    private let textDocumentProxyProvider: () -> UITextDocumentProxy?
    private let dismissKeyboard: () -> Void
    private let advanceToNextInputMode: () -> Void
    /// The numpad-flip key's destination now (owner note 2026-07-09): the real numpad
    /// page, not an internal canvas.
    private let switchToNumpadPage: () -> Void
    /// Full Keyboard already displays the real numpad beside this page. Keep the existing page
    /// exit flush order intact by deciding whether to switch before invoking the destination.
    private let numpadPageIsAlreadyVisible: () -> Bool
    /// Same click/haptic path as numpad touch-down; injected by KeyboardViewController.
    private let keyTouchDownFeedback: () -> Void
    /// Forwards every meaningful QWERTY interaction into the host's single kiosk activity path.
    private let onUserActivity: () -> Void

    /// Mirrors `UIInputViewController.needsInputModeSwitchKey`, refreshed by the host VC
    /// whenever it might change (appearance, rotation, settings sync) since this host has
    /// no input-view-controller lifecycle of its own to read it from directly.
    var needsInputModeSwitchKey = true

    private var textDocumentProxy: UITextDocumentProxy {
        guard let proxy = textDocumentProxyProvider() else {
            preconditionFailure("QwertyPageHost cannot outlive its input view controller")
        }
        return proxy
    }

    // MARK: - Views

    /// Full-bleed container the host VC pins to the same edges as its numpad `stackView`;
    /// page switches just toggle `isHidden` on the two so both stay mounted afterward.
    let containerView = UIView()
    private let suggestionBar = QwertySuggestionBarView()
    private let keyboardView = QwertyKeyboardView()
    private let spellChecker = QwertySpellChecker()
    private let suggestionCoordinator =
        QwertySuggestionCoordinator<QwertyCorrectionEvaluation>(
            onEvent: QwertyLatencyInstrumentation.coordinatorEvent)
    private var suggestionInterval: (
        request: QwertySuggestionRequest,
        interval: QwertyLatencyInstrumentation.SuggestionInterval
    )?
    /// Frequency re-ranker for the checker's raw output (design doc
    /// docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §1: re-rank,
    /// never replace — `UITextChecker` stays the sole spelling authority). Completions get
    /// the full `rerank`: their alphabetical `completions(forPartialWordRange:)` ordering
    /// is undocumented but observed (NSHipster finding; Apple's docs claim probability
    /// sorting — see docs/plans/full-keyboard/2026-07-05-technical-feasibility.md §2).
    /// Guesses are already likelihood-ranked, so they only get `rerankKnown` (see the two
    /// call sites). `.main` is the extension bundle here, which carries
    /// `qwerty_lexicon_en.bin`; a missing resource degrades to an empty lexicon whose
    /// re-rankers are the identity.
    private let frequencyLexicon = QwertyFrequencyLexicon(bundled: .main)

    // MARK: - State (ported from QwertyKeyboardViewController)

    private var shift = QwertyShiftMachine()
    private var autocorrectHistory = QwertyAutocorrectHistory()
    private var visibleCorrection: (original: String, replacement: String)?
    private var typingQualitySession = TypingQualitySession()
    /// Learned words (design §2): protects accepted words from autocorrect and ranks them
    /// first in the bar. Reloaded on every page activation, so an app-side "Reset Typing
    /// Personalization" takes effect on the next raise without any broadcast — PRIVACY: this
    /// store never posts SettingsSync, never logs analytics, and has no export path.
    private var personalDictionary = QwertyPersonalDictionary()
    /// Learned per-key touch offsets (design §3): the mean-offset half of arXiv:2209.11311.
    /// Same lifecycle and PRIVACY posture as `personalDictionary` — reloaded on every page
    /// activation, never SettingsSync-posted, never analytics-logged, no export path.
    private var touchPersonalization = QwertyTouchPersonalization()
    /// Context-keyed persistence owner. The model above is always the entry selected for
    /// `activePersonalizationContext`.
    private var touchPersonalizationEnvelope = QwertyTouchPersonalizationEnvelope()
    private var dictionaryStoreState =
        QwertyTouchPersonalizationPersistence.StoreLoadState.current
    private var touchStoreState =
        QwertyTouchPersonalizationPersistence.StoreLoadState.current
    private var activePersonalizationContext = QwertyPersonalizationContext.phoneAutomatic
    private var personalizationIsLoaded = false
    private var isActive = false
    /// The last letter tap's (base character, normalized offset), awaiting the cheap
    /// acceptance proxy: committed by the next letter tap, a surviving word boundary, or a
    /// page exit; discarded by backspace (tap or autorepeat) and by any correction that
    /// replaces the word it belongs to. See qwertyKeyboardView(_:didTap:) and
    /// commitPendingTouchSample().
    private var pendingTouchSample: (character: String, offset: (dx: Double, dy: Double))?
    /// Whether the in-memory `touchPersonalization` holds samples storage doesn't — set by
    /// commitPendingTouchSample(), consumed by flushTouchPersonalization() so word-boundary
    /// flushes skip when nothing changed.
    private var touchOffsetsDirty = false
    /// The stable odd/even epoch `personalDictionary`/`touchPersonalization` were loaded against.
    /// Persisted payloads carry this epoch, so even a delayed physical write from before reset
    /// cannot be accepted afterward.
    private var loadedPersonalizationEpoch = 0
    /// In-memory cache generation. The persisted reset epoch alone does not move when this
    /// host learns a word, so every accepted-word mutation advances this separate value.
    private var suggestionPersonalizationGeneration: UInt64 = 0
    private var suggestionRejectedWordsGeneration: UInt64 = 0
    private var activeLayer: QwertyLayer = .letters
    /// The pack on the top strip; nil = the persistent number row (owner decision §0.3).
    private var activeTopStripPack: KeyboardType?
    private var lastSpaceTap: TimeInterval?
    private var backspaceRepeatTimer: Timer?
    private var backspaceHoldStarted: TimeInterval?
    private var backspaceConfiguration: QwertyBackspaceInteractionConfiguration?
    private var backspaceDidRepeat = false
    private var backspaceRepeatSessionRecorded = false
    private var spaceCursorInteraction = QwertySpaceCursorInteraction()
    private var spaceCursorLastLocation: CGPoint?
    private weak var activeSpaceButton: QwertyKeyButton?
    /// The period/comma setting the current key grid was built with (change detection for
    /// `settingsDidChange`).
    private var appliedPeriodComma: Bool?
    /// The theme the current key grid was built with — a theme change from the app rebuilds
    /// the keys so every button re-reads its palette.
    private var appliedTheme: KeyboardTheme?
    /// The glide decoder plus the exact letter-key centers map it was built from (glide-and-
    /// accuracy design §4.3, dark — see `FeatureFlags.isGlideTypingActive`). Built LAZILY on
    /// the FIRST glide completion, never at keyboard raise (the extension's most latency-
    /// visible moment): the decoder's init is the expensive step (one ~49k-entry lexicon
    /// walk, ~3.5MB resident — well inside the extension's ~50MB ceiling). Rebuilt only when
    /// the rendered centers change (rotation, height preset, layout/theme grid rebuilds that
    /// actually move keys): `letterKeyCenters()` recomputes from CURRENT frames on every
    /// call, so comparing maps IS the invalidation check — a theme-only rebuild that leaves
    /// frames identical keeps the cache. Deliberately built SYNCHRONOUSLY on that first
    /// glide: decoding cannot proceed without it anyway, the one-time cost lands at gesture
    /// end (not mid-typing), and an async build would add cross-thread mutable state for no
    /// user-visible win.
    private var glideDecoderCache: (decoder: QwertyGlideDecoder, centers: [String: CGPoint])?

    private enum Metrics {
        static let suggestionBarHeight: CGFloat = 44
    }

    /// Base canvas height (suggestion bar + top strip + four key rows). Uses the same
    /// trustworthy window/screen ceiling as the numpad path — never `containerView.bounds`
    /// (that is keyboard-sized mid page-switch and collapses the 50% cap to the 220pt floor).
    var baseHeight: CGFloat {
        let idiom = UIDevice.current.userInterfaceIdiom
        let container = KeyboardHeightPreset.clampCeilingContainerHeight(
            windowHeight: hostViewController?.view.window?.bounds.height
                ?? containerView.window?.bounds.height,
            screenHeight: UIScreen.main.bounds.height
        )
        let compact = hostViewController?.traitCollection.verticalSizeClass == .compact
        let resolved = KeyboardHeightPreset.resolvedHeight(
            stored: KeyboardHeightPreset.selected,
            kioskEntitled: Monetization.isKioskHeightEntitled,
            idiom: idiom,
            compactHeight: compact,
            containerHeight: container
        )
        if resolved > 0 { return resolved }
        return idiom == .pad ? 384 : 344
    }

    init(hostViewController: UIInputViewController,
         textDocumentProxyProvider: @escaping () -> UITextDocumentProxy?,
         dismissKeyboard: @escaping () -> Void,
         advanceToNextInputMode: @escaping () -> Void,
         switchToNumpadPage: @escaping () -> Void,
         numpadPageIsAlreadyVisible: @escaping () -> Bool = { false },
         keyTouchDownFeedback: @escaping () -> Void = {},
         onUserActivity: @escaping () -> Void = {}) {
        self.hostViewController = hostViewController
        self.textDocumentProxyProvider = textDocumentProxyProvider
        self.dismissKeyboard = dismissKeyboard
        self.advanceToNextInputMode = advanceToNextInputMode
        self.switchToNumpadPage = switchToNumpadPage
        self.numpadPageIsAlreadyVisible = numpadPageIsAlreadyVisible
        self.keyTouchDownFeedback = keyTouchDownFeedback
        self.onUserActivity = onUserActivity
        super.init()
        buildViewHierarchy()
        suggestionBar.delegate = self
        keyboardView.delegate = self
        keyboardView.glideDelegate = self
        spellChecker.loadLexicon(from: hostViewController) { [weak self] in
            guard let self else { return }
            self.finishSuggestionInterval(applied: false)
            self.suggestionCoordinator.invalidate()
            if self.isActive {
                self.refreshSuggestions()
            }
        }
    }

    deinit {
        backspaceRepeatTimer?.invalidate()
    }

    func deactivate() {
        isActive = false
        finishSuggestionInterval(applied: false)
        suggestionCoordinator.cancelPending()
        finishTypingQualitySession()
        invalidateCorrectionForOtherEdit()
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
        backspaceHoldStarted = nil
        backspaceConfiguration = nil
        backspaceDidRepeat = false
        backspaceRepeatSessionRecorded = false
        spaceCursorInteraction.cancel()
        spaceCursorLastLocation = nil
        activeSpaceButton?.setCursorTrackingActive(false)
        activeSpaceButton = nil
        keyboardView.dismissAlternates()
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
        isActive = true
        // A keyboard lifecycle/page transition can move the caret or mutate the document
        // while this page is absent. Never carry a one-backspace revert across that gap.
        invalidateCorrectionForOtherEdit()
        if fromNumpadPage {
            TypingQualityCounters.increment(.pageSwitches)
        }
        typingQualitySession.activate()
        stripNumpadContext = isIPadNumberStripForced ? false : fromNumpadPage
        var snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData }
        )
        if snapshot.touchEnvelope.requiresMigrationWrite {
            // One-time legacy migration. No SettingsSync, analytics, or export path.
            snapshot = QwertyTouchPersonalizationPersistence
                .persistLegacyMigrationIfCurrent(
                    snapshot: snapshot,
                    currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
                    currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
                    currentTouchData: { UserPrefs.qwertyTouchOffsetsData },
                    persistTouchData: { UserPrefs.qwertyTouchOffsetsData = $0 }
                )
        }
        personalDictionary = snapshot.dictionary
        touchPersonalizationEnvelope = snapshot.touchEnvelope
        dictionaryStoreState = snapshot.dictionaryStoreState
        touchStoreState = snapshot.touchStoreState
        loadedPersonalizationEpoch = snapshot.generation
        suggestionPersonalizationGeneration &+= 1
        suggestionCoordinator.invalidate()
        activePersonalizationContext = keyboardView.personalizationContext
        touchPersonalization = touchPersonalizationEnvelope.model(
            for: activePersonalizationContext
        )
        personalizationIsLoaded = true
        pendingTouchSample = nil
        touchOffsetsDirty = false
        activeTopStripPack = isIPadNumberStripForced ? nil : resolvedTopStripPack()
        reloadKeys()
        // The first configured grid supplies the rows the resolver needs. Resolve before the
        // first touch so iPad never briefly routes with the phone/automatic model.
        containerView.layoutIfNeeded()
        refreshAutocap()
        refreshSuggestions()
    }

    private func finishTypingQualitySession() {
        if typingQualitySession.finish() {
            TypingQualityCounters.increment(.shortAbandonedSessions)
        }
    }

    private func recordTypingAction(_ event: TypingQualityCounters.Event) {
        typingQualitySession.recordTypingAction()
        TypingQualityCounters.increment(event)
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
        reloadPersonalizationIfResetElsewhere()
        // Layout preference/profile changes are resolved against the live bounds and traits on
        // every pass; force that pass now so a visible keyboard moves immediately.
        keyboardView.setNeedsLayout()
        containerView.layoutIfNeeded()
        // Glide availability re-evaluates on every settings sync so a Beta-toggle flip (or
        // the mirrored RC kill switch) lands on a LIVE keyboard without waiting for a grid
        // rebuild. Idempotent — a no-op when the recognizer already matches the gate; while
        // the flag has never been on, the recognizer never exists and this changes nothing.
        keyboardView.updateGlideAvailability()
        synchronizePersonalizationContext(keyboardView.personalizationContext)
        let periodComma = UserPrefs.qwertyPeriodComma
        let theme = KeyboardTheme.selectedOrAutomatic
        // Only an EXTERNAL strip change (the wizard's default-pack edits in the app) re-resolves
        // the strip. The pack-switch key writes `qwertyTopStripPack` itself and posts
        // SettingsSync — re-resolving through `packDisplayBehavior` on that same-process echo
        // snapped a PRIMARY-SELECTED user's fresh in-session pack straight back to their
        // primary (owner-reported: "packs do not change when selected in qwerty mode").
        let stripChangedExternally = !isIPadNumberStripForced
            && UserPrefs.qwertyTopStripPack != activeTopStripPack
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
        // configure() dropped the stale per-index offset map with the old grid — repopulate
        // from the model for the new key set.
        rebuildViewTouchOffsets()
    }

    // MARK: - Top strip (swappable number line, owner decision §0.3)

    /// The canvas-auto-swap semantics apply exactly when this page was entered from the numpad
    /// page (`stripNumpadContext`) — the flip canvas itself is gone, but "arrived from a grid
    /// of digits" carries the same meaning it did (owner note 2026-07-10).
    private func currentTopStrip() -> QwertyTopStrip {
        guard !isIPadNumberStripForced else { return .numbers }
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

    private var isIPadNumberStripForced: Bool {
        IPadKeyboardCompositionGeometry.shouldForceNumberStrip(
            idiom: hostViewController?.traitCollection.userInterfaceIdiom
                ?? UIDevice.current.userInterfaceIdiom,
            layout: UserPrefs.iPadQwertyLayout
        )
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

    /// Complete value snapshot consumed after the coordinator's one main-actor yield. No
    /// document proxy, view, or mutable personalization state is re-read during evaluation.
    private struct SuggestionEvaluationInput {
        let word: String
        let supplementaryLexicon: [String: String]
        let rejectedWords: Set<String>
        let personalDictionary: QwertyPersonalDictionary
    }

    private func suggestionEvaluationSnapshot(for word: String)
        -> (request: QwertySuggestionRequest, input: SuggestionEvaluationInput) {
        let lexicon = spellChecker.lexiconSnapshot
        let rejectedWords = autocorrectHistory.rejectedWords
        return (
            QwertySuggestionRequest(
                word: word,
                lexiconGeneration: lexicon.generation,
                personalizationGeneration: suggestionPersonalizationGeneration,
                rejectedWordsGeneration: suggestionRejectedWordsGeneration),
            SuggestionEvaluationInput(
                word: word,
                supplementaryLexicon: lexicon.entries,
                rejectedWords: rejectedWords,
                personalDictionary: personalDictionary)
        )
    }

    /// Inserts a word-boundary character, running the autocorrect pass first (lexicon
    /// expansion beats spell correction — system Text Replacement parity).
    private func insertBoundary(_ text: String) {
        let correctedState = applyPendingCorrection()
        // The word survived the boundary (applyPendingCorrection discards the buffered tap
        // on any replacement) — accept its final letter tap and persist the word's
        // accumulated samples in one write.
        commitPendingTouchSample()
        flushTouchPersonalization()
        textDocumentProxy.insertText(text)
        didInsert(text)
        if let correctedState {
            _ = suggestionBar.show(correctedState)
        }
    }

    private func applyPendingCorrection() -> QwertySuggestionBarView.State? {
        guard UserPrefs.qwertyAutocorrect else { return nil }
        guard let word = QwertyAutocorrect.currentWord(
            before: textDocumentProxy.documentContextBeforeInput) else { return nil }
        let snapshot = suggestionEvaluationSnapshot(for: word)
        let action = QwertyBoundaryCorrection.resolve(
            evaluation: suggestionCoordinator.cachedResult(for: snapshot.request),
            recordAcceptance: { recordAcceptance(of: word) })

        switch action {
        case .autoApply(let original, let replacement):
            replaceCurrentWord(original, with: replacement)
            autocorrectHistory.recordCorrection(original: original, corrected: replacement)
            visibleCorrection = (original, replacement)
            TypingQualityCounters.increment(.correctionsApplied)
            pendingTouchSample = nil
            return .corrected(original: original, replacement: replacement)
        case .preserveTypedText:
            // A boundary must never put synchronous checker/variant work back into the key
            // stack. A cold cache preserves what the user typed without checker work.
            return nil
        }
    }

    /// iPad Split View stale-write-back guard: the container app can Reset Typing
    /// Personalization while this keyboard is raised in the adjacent app — persisting a
    /// stale in-memory copy would silently undo that reset. The contentless odd/even epoch
    /// detects an in-progress or completed reset (an Int moves across the app group, never
    /// learned content): on mismatch, drop BOTH stale copies and reload their epoch-tagged
    /// payloads. The persist helpers also check after writing, so reset wins even if it starts
    /// immediately after this reload. Call before every persist of either store.
    private func reloadPersonalizationIfResetElsewhere() {
        let generation = UserPrefs.qwertyPersonalizationEpoch
        let loadedSnapshot = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: personalDictionary,
            touchEnvelope: touchPersonalizationEnvelope,
            generation: loadedPersonalizationEpoch,
            dictionaryStoreState: dictionaryStoreState,
            touchStoreState: touchStoreState
        )
        guard QwertyTouchPersonalizationPersistence.requiresHostReload(
            currentEpoch: generation,
            loadedSnapshot: loadedSnapshot
        ) else {
            return
        }
        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData }
        )
        personalDictionary = snapshot.dictionary
        touchPersonalizationEnvelope = snapshot.touchEnvelope
        dictionaryStoreState = snapshot.dictionaryStoreState
        touchStoreState = snapshot.touchStoreState
        touchPersonalization = touchPersonalizationEnvelope.model(
            for: activePersonalizationContext
        )
        // Any unflushed in-memory samples died with the stale copy — the reset wins over a
        // few lost taps, and flushTouchPersonalization() must not write them back.
        touchOffsetsDirty = false
        loadedPersonalizationEpoch = snapshot.generation
        invalidateSuggestionPersonalization()
    }

    /// Learns one accepted word and persists the dictionary. PRIVACY (design §2): no
    /// `SettingsSync.post()`, no analytics — the blob stays inside the app group.
    private func recordAcceptance(of word: String) {
        reloadPersonalizationIfResetElsewhere()
        var updated = personalDictionary
        guard updated.recordAcceptance(of: word) else { return }  // hygiene-rejected: no write
        let priorGeneration = loadedPersonalizationEpoch
        let persisted = QwertyTouchPersonalizationPersistence.persistDictionaryIfCurrent(
            snapshot: QwertyTouchPersonalizationPersistence.Snapshot(
                dictionary: personalDictionary,
                touchEnvelope: touchPersonalizationEnvelope,
                generation: priorGeneration,
                dictionaryStoreState: dictionaryStoreState,
                touchStoreState: touchStoreState
            ),
            updatedDictionary: updated,
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData },
            persistDictionaryData: { UserPrefs.qwertyPersonalDictionaryData = $0 }
        )
        if persisted.writeWasCommitted {
            personalDictionary = persisted.dictionary
            dictionaryStoreState = persisted.dictionaryStoreState
            invalidateSuggestionPersonalization()
        } else {
            applyReloadedPersonalization(persisted)
        }
    }

    // MARK: - Per-key touch personalization (design §3)

    /// Folds the buffered tap offset into the in-memory model — reached only when the user
    /// moved on without deleting (backspace discards the buffer) or losing the word to a
    /// correction (autocorrect replacement, lexicon expansion, and suggestion-chip
    /// replacement all discard it too: a corrected word's final-letter tap is evidence of
    /// a miss, not a habit). The buffer is consumed first, so a sample can never commit
    /// twice. Persistence and the view-map refresh are deferred to
    /// flushTouchPersonalization() — never one cross-process write per keystroke.
    private func commitPendingTouchSample() {
        guard touchPersonalizationEnvelope.permitsPersistence else {
            pendingTouchSample = nil
            return
        }
        guard let sample = pendingTouchSample else { return }
        pendingTouchSample = nil
        var updated = touchPersonalization
        guard updated.recordAcceptedTap(keyCharacter: sample.character,
                                        normalizedOffset: sample.offset) else { return }
        touchPersonalization = updated
        touchOffsetsDirty = true
    }

    /// Persists the accumulated in-memory samples and refreshes the view's routing map —
    /// called at word boundaries (insertBoundary/handleSpace/chip taps) and page exits
    /// (numpad flip, dismiss), so burst typing costs at most one app-group write per word
    /// instead of one per keystroke. The Split View reset guard runs here, at flush time:
    /// if the app reset personalization since load, the accumulated samples die with the
    /// stale model (nothing is written back). PRIVACY: same rules as the personal
    /// dictionary — no `SettingsSync.post()`, no analytics, the blob stays inside the app
    /// group.
    private func flushTouchPersonalization() {
        guard touchOffsetsDirty else { return }
        reloadPersonalizationIfResetElsewhere()  // clears the dirty flag if a reset landed
        guard touchOffsetsDirty else {
            rebuildViewTouchOffsets()  // routing follows the freshly reloaded (empty) model
            return
        }
        touchOffsetsDirty = false
        guard touchPersonalizationEnvelope.setModel(
            touchPersonalization,
            for: activePersonalizationContext
        ) else {
            rebuildViewTouchOffsets()
            return
        }
        let priorGeneration = loadedPersonalizationEpoch
        let persisted = QwertyTouchPersonalizationPersistence.persistTouchIfCurrent(
            snapshot: QwertyTouchPersonalizationPersistence.Snapshot(
                dictionary: personalDictionary,
                touchEnvelope: touchPersonalizationEnvelope,
                generation: priorGeneration,
                dictionaryStoreState: dictionaryStoreState,
                touchStoreState: touchStoreState
            ),
            updatedEnvelope: touchPersonalizationEnvelope,
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData },
            persistTouchData: { UserPrefs.qwertyTouchOffsetsData = $0 }
        )
        if persisted.writeWasCommitted {
            touchPersonalizationEnvelope = persisted.touchEnvelope
            touchStoreState = persisted.touchStoreState
        } else {
            applyReloadedPersonalization(persisted)
        }
        // The flushed samples may have graduated a key past warmup (or nudged a learned
        // offset) — refresh the view's routing map.
        rebuildViewTouchOffsets()
    }

    private func applyReloadedPersonalization(
        _ snapshot: QwertyTouchPersonalizationPersistence.Snapshot
    ) {
        personalDictionary = snapshot.dictionary
        touchPersonalizationEnvelope = snapshot.touchEnvelope
        dictionaryStoreState = snapshot.dictionaryStoreState
        touchStoreState = snapshot.touchStoreState
        touchPersonalization = snapshot.touchEnvelope.model(
            for: activePersonalizationContext
        )
        touchOffsetsDirty = false
        loadedPersonalizationEpoch = snapshot.generation
        invalidateSuggestionPersonalization()
    }

    private func invalidateSuggestionPersonalization() {
        suggestionPersonalizationGeneration &+= 1
        finishSuggestionInterval(applied: false)
        suggestionCoordinator.invalidate()
    }

    private func invalidateSuggestionRejections() {
        suggestionRejectedWordsGeneration &+= 1
        finishSuggestionInterval(applied: false)
        suggestionCoordinator.invalidate()
    }

    /// Feeds the view's gap-resolution offsets: base character → learned normalized offset
    /// (nil while a key is warming up, so fresh users get untouched routing).
    private func rebuildViewTouchOffsets() {
        let model = touchPersonalization
        keyboardView.rebuildTouchOffsets { model.offset(forKeyCharacter: $0) }
    }

    private func replaceCurrentWord(_ word: String, with replacement: String) {
        for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement)
    }

    private func handleSpace() {
        var correctedState = applyPendingCorrection()
        // Word boundary — same acceptance + single-write flush as insertBoundary().
        commitPendingTouchSample()
        flushTouchPersonalization()
        let now = CACurrentMediaTime()
        let decision = DoubleSpacePeriod.decision(
            before: textDocumentProxy.documentContextBeforeInput,
            secondsSinceLastSpaceTap: lastSpaceTap.map { now - $0 },
            enabled: UserPrefs.qwertyDoubleSpacePeriod)
        if decision.deletions > 0 {
            // The boundary after a pending correction just changed shape ("x " → "x. ") —
            // the one-backspace revert contract no longer holds.
            invalidateCorrectionForOtherEdit()
            correctedState = nil
        }
        for _ in 0..<decision.deletions { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(decision.insertion)
        lastSpaceTap = now
        didInsert(decision.insertion)
        if let correctedState {
            _ = suggestionBar.show(correctedState)
        }
    }

    private func handleBackspace() {
        if !revertPendingCorrection() {
            textDocumentProxy.deleteBackward()
        }
        invalidateCorrectionForOtherEdit()
        refreshAutocap()
        refreshSuggestions()
    }

    @discardableResult
    private func revertPendingCorrection() -> Bool {
        guard let revert = autocorrectHistory.consumeRevert(
            matching: revertIsApplicable(_:)) else { return false }
        invalidateSuggestionRejections()
        textDocumentProxy.deleteBackward()  // the boundary character
        for _ in 0..<revert.deletions { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(revert.insertion)
        visibleCorrection = nil
        TypingQualityCounters.increment(.correctionReverts)
        return true
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
        applyPostInsertionState(for: text)
        refreshSuggestions()
    }

    /// Everything `didInsert` does EXCEPT the suggestion recompute — shift consumption,
    /// layer bounce, autocap. Split out so the glide path (design §4.3) can run the same
    /// state machine and then override the bar with the DECODER's candidates instead of
    /// letting `refreshSuggestions()` recompute spell-checker ones.
    private func applyPostInsertionState(for text: String) {
        shift.didInsertCharacter(text)
        let bounced = QwertyLayerRules.layer(afterInserting: text, on: activeLayer)
        if bounced != activeLayer {
            activeLayer = bounced
            reloadKeys()
        }
        refreshAutocap()
    }

    private func refreshAutocap() {
        let raw = textDocumentProxy.autocapitalizationType?.rawValue
        let policy = raw.flatMap(QwertyAutocapPolicy.init(rawValue:)) ?? .sentences
        // Right after replaceCurrentWord's delete/insert burst the proxy transiently reports
        // an empty before-context while the field still has text — that's staleness, not a
        // sentence start, and the shift machine must not move on it (phantom capitals).
        let context = textDocumentProxy.documentContextBeforeInput
        let hasText = textDocumentProxy.hasText
        let verdict = QwertyAutocap.shouldCapitalize(policy: policy,
                                                     before: context,
                                                     hasText: hasText)
        shift.evaluateAutocap(
            shouldCapitalize: verdict,
            isContextKnown: !QwertyAutocap.isContextUnknown(before: context, hasText: hasText))
        keyboardView.update(shiftState: shift.state)
    }

    private func refreshSuggestions() {
        if let correction = visibleCorrection,
           correctionIsStillVisible(correction) {
            cancelSuggestionRequest()
            _ = suggestionBar.show(.corrected(
                original: correction.original,
                replacement: correction.replacement))
            keyboardView.touchBias = [:]
            return
        }
        invalidateCorrectionForOtherEdit()
        guard UserPrefs.qwertySuggestions else {
            cancelSuggestionRequest()
            suggestionBar.clear()
            keyboardView.touchBias = [:]
            return
        }
        guard let word = QwertyAutocorrect.currentWord(
            before: textDocumentProxy.documentContextBeforeInput) else {
            cancelSuggestionRequest()
            suggestionBar.clear()
            keyboardView.touchBias = [:]
            return
        }

        // Never leave candidates for the previous word selectable while enrichment yields.
        // The literal is immediately truthful and cheap; the exact cached/fresh result
        // replaces it after the checker pass.
        _ = suggestionBar.show(.suggestions([.literal(word), .empty, .empty]))
        keyboardView.touchBias = [:]

        let snapshot = suggestionEvaluationSnapshot(for: word)
        beginSuggestionInterval(for: snapshot.request)
        let checker = spellChecker
        let lexicon = frequencyLexicon
        suggestionCoordinator.request(
            snapshot.request,
            input: snapshot.input,
            evaluate: { input in
                QwertyLatencyInstrumentation.measureCheckerSlice(
                    wordLength: input.word.count) {
                    checker.evaluateCorrection(
                        word: input.word,
                        frequencyLexicon: lexicon,
                        supplementaryLexicon: input.supplementaryLexicon,
                        userRejected: input.rejectedWords,
                        isUserKnownWord: input.personalDictionary.isKnown(input.word),
                        personalBoost: input.personalDictionary.boost(for:),
                        isPersonalCandidate: input.personalDictionary.isKnown(_:))
                }
            },
            apply: { [weak self] request, evaluation in
                self?.applySuggestionEvaluation(evaluation, for: request) ?? false
            })
    }

    private func applySuggestionEvaluation(_ evaluation: QwertyCorrectionEvaluation,
                                           for request: QwertySuggestionRequest) -> Bool {
        guard UserPrefs.qwertySuggestions,
              visibleCorrection == nil,
              let visibleWord = QwertyAutocorrect.currentWord(
                before: textDocumentProxy.documentContextBeforeInput),
              visibleWord == request.word,
              suggestionEvaluationSnapshot(for: visibleWord).request == request else {
            if suggestionInterval?.request == request {
                finishSuggestionInterval(applied: false)
            }
            return false
        }
        let nextState = QwertySuggestionBarView.State.suggestions(evaluation.suggestionSlots)
        let isNewImpression = nextState.isNewCandidateImpression(comparedTo: suggestionBar.state)
        _ = suggestionBar.show(nextState)
        if isNewImpression {
            TypingQualityCounters.increment(.suggestionsShown)
        }
        // Zero-dead-zone touch routing bias (owner note 4): reuses the completions this method
        // already computed above — no extra spell-checker work. Feeding it the RE-RANKED list
        // is deliberate: its 1/(rank+1) weights now reflect frequency order, so the
        // likely-next-key bias improves for free.
        keyboardView.touchBias = QwertyTouchRouting.bias(
                                                         forCompletions: evaluation.rankedCompletions,
                                                         currentWord: request.word,
                                                         keyOutputs: keyboardView.characterKeyOutputs)
        if suggestionInterval?.request == request {
            finishSuggestionInterval(applied: true)
        }
        return true
    }

    private func beginSuggestionInterval(for request: QwertySuggestionRequest) {
        guard suggestionInterval?.request != request else { return }
        finishSuggestionInterval(applied: false)
        suggestionInterval = (
            request,
            QwertyLatencyInstrumentation.beginSuggestion(wordLength: request.word.count)
        )
    }

    private func finishSuggestionInterval(applied: Bool) {
        guard let current = suggestionInterval else { return }
        suggestionInterval = nil
        QwertyLatencyInstrumentation.endSuggestion(current.interval, applied: applied)
    }

    private func cancelSuggestionRequest() {
        finishSuggestionInterval(applied: false)
        suggestionCoordinator.cancelPending()
    }

    private func correctionIsStillVisible(
        _ correction: (original: String, replacement: String)) -> Bool {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              let boundary = context.last,
              QwertyAutocorrect.isBoundary(String(boundary)) else { return false }
        return String(context.dropLast()).hasSuffix(correction.replacement)
    }

    // MARK: - Space-bar cursor drag (system-keyboard gesture parity, plan §2)

    /// Space stays a normal key until an intentional 0.35-second hold completes. Only then
    /// does horizontal movement drive the cursor accumulator. The long-press recognizer's
    /// unlimited allowable movement means a quick swipe remains a Space interaction instead
    /// of activating cursor mode.
    @objc private func spaceLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard let button = recognizer.view as? QwertyKeyButton else { return }
        switch recognizer.state {
        case .began:
            let now = CACurrentMediaTime()
            if !spaceCursorInteraction.activateTracking(at: now) {
                // UIKit owns recognition of the hold duration. Touch capture can be absent
                // for synthesized/accessibility input, so seed the model at the threshold
                // rather than discarding a recognizer that has already legitimately begun.
                spaceCursorInteraction.begin(at: now - QwertySpaceCursorInteraction.holdDuration)
                guard spaceCursorInteraction.activateTracking(at: now) else { return }
            }
            activeSpaceButton = button
            spaceCursorLastLocation = recognizer.location(in: containerView)
            button.setCursorTrackingActive(true)
            invalidateCorrectionForOtherEdit()
            onUserActivity()
        case .changed:
            applySpaceCursorMovement(to: recognizer.location(in: containerView))
        case .ended, .cancelled, .failed:
            if recognizer.state == .ended {
                // Some event sources coalesce a short drag and deliver its only changed
                // location with `.ended`; consume it before resetting the accumulator.
                applySpaceCursorMovement(to: recognizer.location(in: containerView))
                _ = spaceCursorInteraction.end()
            } else {
                spaceCursorInteraction.cancel()
            }
            spaceCursorLastLocation = nil
            button.setCursorTrackingActive(false)
            activeSpaceButton = nil
            refreshAutocap()
            refreshSuggestions()
        default:
            break
        }
    }

    private func applySpaceCursorMovement(to location: CGPoint) {
        guard spaceCursorInteraction.state == .tracking,
              let previous = spaceCursorLastLocation else { return }
        spaceCursorLastLocation = location
        let steps = spaceCursorInteraction.move(
            translation: location.x - previous.x,
            at: CACurrentMediaTime()
        )
        guard steps != 0 else { return }
        onUserActivity()
        textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
    }

    @objc private func spaceTouchUpOutside(_ button: QwertyKeyButton) {
        guard spaceCursorInteraction.state == .pressing,
              spaceCursorInteraction.end() == .insertSpace else { return }
        QwertyLatencyInstrumentation.measureTextCommit {
            onUserActivity()
            invalidateCorrectionForOtherEdit()
            recordTypingAction(.keyTaps)
            handleSpace()
        }
    }

    @objc private func spaceTouchCancelled(_ button: QwertyKeyButton) {
        guard spaceCursorInteraction.state != .tracking else { return }
        spaceCursorInteraction.cancel()
        button.setCursorTrackingActive(false)
    }

    // MARK: - Backspace autorepeat

    @objc private func backspaceTouchDown(_ button: QwertyKeyButton) {
        backspaceRepeatTimer?.invalidate()
        backspaceHoldStarted = CACurrentMediaTime()
        backspaceConfiguration = QwertyBackspaceInteractionConfiguration(
            wordDeleteEnabled: FeatureFlags.backspaceWordDelete,
            initialDelay: QwertyBackspacePolicy.initialDelay,
            repeatInterval: QwertyBackspacePolicy.characterInterval
        )
        backspaceDidRepeat = false
        backspaceRepeatSessionRecorded = false
        scheduleBackspaceTick()
    }

    @objc private func backspaceTouchEnded(_ button: QwertyKeyButton) {
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
        backspaceHoldStarted = nil
        backspaceConfiguration = nil
        backspaceRepeatSessionRecorded = false
        // UIControl target ordering is not an API contract. Keep the repeat marker through
        // this touch-up dispatch so `keyTapped` suppresses the release tap whether it runs
        // before or after this target, then clear it for touch-up-outside/cancel paths.
        DispatchQueue.main.async { [weak self] in
            self?.backspaceDidRepeat = false
        }
        refreshSuggestions()
    }

    private func scheduleBackspaceTick() {
        backspaceRepeatTimer?.invalidate()
        guard let started = backspaceHoldStarted,
              let configuration = backspaceConfiguration else { return }
        let elapsed = CACurrentMediaTime() - started
        let interval = QwertyBackspacePolicy.nextInterval(elapsed: elapsed,
                                                          configuration: configuration)
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 0.01),
                                                    repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let started = self.backspaceHoldStarted,
                      let configuration = self.backspaceConfiguration else { return }
                let elapsed = CACurrentMediaTime() - started
                switch QwertyBackspacePolicy.action(elapsed: elapsed,
                                                    configuration: configuration) {
                case .wait:
                    break
                case .deleteCharacter:
                    self.noteBackspaceRepeatIfNeeded()
                    self.onUserActivity()
                    self.textDocumentProxy.deleteBackward()
                    self.recordTypingAction(.backspaceTaps)
                    self.refreshAutocap()
                case .deleteWord:
                    self.noteBackspaceRepeatIfNeeded()
                    self.onUserActivity()
                    self.deleteBackwardWord()
                    self.recordTypingAction(.backspaceTaps)
                    self.refreshAutocap()
                }
                self.scheduleBackspaceTick()
            }
        }
    }

    private func noteBackspaceRepeatIfNeeded() {
        backspaceDidRepeat = true
        guard !backspaceRepeatSessionRecorded else { return }
        backspaceRepeatSessionRecorded = true
        invalidateCorrectionForOtherEdit()
        pendingTouchSample = nil
        TypingQualityCounters.increment(.backspaceRepeatSessions)
    }

    private func deleteBackwardWord() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !before.isEmpty else { return }
        var count = 0
        for ch in before.reversed() {
            if ch.isWhitespace, count > 0 { break }
            count += 1
            if ch.isWhitespace { break }
        }
        for _ in 0..<max(count, 1) { textDocumentProxy.deleteBackward() }
    }
}

// MARK: - QwertyKeyboardViewDelegate

extension QwertyPageHost: QwertyKeyboardViewDelegate {

    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didResolveLayoutMode mode: QwertyLayoutMode) {
        synchronizePersonalizationContext(view.personalizationContext)
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didResolvePersonalizationContext context: QwertyPersonalizationContext) {
        synchronizePersonalizationContext(context)
    }

    private func synchronizePersonalizationContext(_ context: QwertyPersonalizationContext) {
        guard personalizationIsLoaded else { return }
        guard context != activePersonalizationContext else { return }

        // A pending tap was measured in the old geometry. Settle it under that context before
        // selecting the new model; never reinterpret it as evidence for a different layout.
        commitPendingTouchSample()
        flushTouchPersonalization()
        pendingTouchSample = nil
        activePersonalizationContext = context
        touchPersonalization = touchPersonalizationEnvelope.model(for: context)
        touchOffsetsDirty = false
        rebuildViewTouchOffsets()
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTouchDown key: QwertyKey) {
        keyTouchDownFeedback()
        if case .space = key.kind {
            spaceCursorInteraction.begin(at: CACurrentMediaTime())
        }
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey) {
        onUserActivity()
        // Per-key touch personalization (design §3, the cheap acceptance proxy): a backspace
        // means the buffered tap was likely wrong — discard it, never learn it. A letter tap
        // accepts the previous buffered tap (the user moved on) and buffers its own offset.
        // Word-boundary keys resolve the buffer inside insertBoundary()/handleSpace() instead
        // — AFTER autocorrect has ruled, so a corrected word's final-letter tap is discarded
        // there rather than committed here (review follow-up).
        if case .backspace = key.kind {
            pendingTouchSample = nil
        }
        if case .character(let base, _) = key.kind,
           QwertyTouchPersonalization.isPersonalizable(base),
           let offset = view.lastTouchOffset(for: key) {
            commitPendingTouchSample()
            pendingTouchSample = (character: base, offset: offset)
        }

        switch key.kind {
        case .character:
            guard let text = shift.output(for: key) else { return }
            QwertyLatencyInstrumentation.measureTextCommit {
                invalidateCorrectionForOtherEdit()
                recordTypingAction(.keyTaps)
                if QwertyAutocorrect.isBoundary(text) {
                    insertBoundary(text)
                } else {
                    let decision = QwertyPunctuationRules.decision(
                        before: textDocumentProxy.documentContextBeforeInput,
                        inserting: text
                    )
                    for _ in 0..<decision.deletions { textDocumentProxy.deleteBackward() }
                    textDocumentProxy.insertText(decision.insertion)
                    didInsert(decision.insertion)
                }
            }
        case .space:
            guard spaceCursorInteraction.end() == .insertSpace else { return }
            QwertyLatencyInstrumentation.measureTextCommit {
                invalidateCorrectionForOtherEdit()
                recordTypingAction(.keyTaps)
                handleSpace()
            }
        case .backspace:
            guard !backspaceDidRepeat else {
                backspaceDidRepeat = false
                return
            }
            recordTypingAction(.backspaceTaps)
            handleBackspace()
        case .ret:
            QwertyLatencyInstrumentation.measureTextCommit {
                invalidateCorrectionForOtherEdit()
                recordTypingAction(.keyTaps)
                insertBoundary("\n")
            }
        case .shift:
            shift.shiftTapped(at: CACurrentMediaTime())
            view.update(shiftState: shift.state)
        case .layerSwitch(let layer):
            activeLayer = layer
            reloadKeys()
        case .globe:
            break  // handled at the button level via handleInputModeList(from:with:)
        case .emojiMode, .emojiResult:
            // Geometry/rendering checkpoint only. Task 6 replaces these explicit no-ops with
            // reducer effects after the browse/search views exist.
            break
        case .numpadFlip:
            // On Full Keyboard the real numpad is already visible beside this pane, so this is
            // intentionally a no-op rather than needlessly changing page/suggestion lifecycle.
            guard !numpadPageIsAlreadyVisible() else { return }
            // Leaves this page entirely now — the real numpad, not an internal canvas.
            // Settle the buffered tap and persist first: the host has no dedicated
            // deactivation hook, so page exits are flush points.
            commitPendingTouchSample()
            flushTouchPersonalization()
            invalidateCorrectionForOtherEdit()
            TypingQualityCounters.increment(.pageSwitches)
            finishTypingQualitySession()
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
            // A different strip key count shifts every flattened key index — repopulate the
            // learned-offset map for the new indices.
            rebuildViewTouchOffsets()
        case .dateTimeToken(_, let token):
            guard let value = DateTimeTokens.value(for: token, now: Date(), locale: .current) else {
                return
            }
            QwertyLatencyInstrumentation.measureTextCommit {
                invalidateCorrectionForOtherEdit()
                recordTypingAction(.keyTaps)
                textDocumentProxy.insertText(value)
                didInsert(value)
            }
        case .snippet(_, let text):
            // Insert-time token expansion — the same rule as the snippets overlay, so
            // "Invoice {date}" always inserts today's date.
            let value = Snippet.expand(text, now: Date())
            QwertyLatencyInstrumentation.measureTextCommit {
                invalidateCorrectionForOtherEdit()
                recordTypingAction(.keyTaps)
                textDocumentProxy.insertText(value)
                didInsert(value)
            }
        case .dismissKeyboard:
            // A page exit like .numpadFlip above — settle and persist before lowering.
            commitPendingTouchSample()
            flushTouchPersonalization()
            invalidateCorrectionForOtherEdit()
            finishTypingQualitySession()
            dismissKeyboard()
        }
    }

    private func invalidateCorrectionForOtherEdit() {
        visibleCorrection = nil
        autocorrectHistory.endImmediateCorrectionScope()
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
            button.addTarget(self,
                             action: #selector(backspaceTouchDown(_:)),
                             for: .touchDown)
            button.addTarget(self,
                             action: #selector(backspaceTouchEnded(_:)),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel])
        case .space:
            let recognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(spaceLongPressed(_:))
            )
            recognizer.minimumPressDuration = QwertySpaceCursorInteraction.holdDuration
            recognizer.allowableMovement = .greatestFiniteMagnitude
            button.addGestureRecognizer(recognizer)
            button.addTarget(self,
                             action: #selector(spaceTouchUpOutside(_:)),
                             for: .touchUpOutside)
            button.addTarget(self,
                             action: #selector(spaceTouchCancelled(_:)),
                             for: .touchCancel)
            button.accessibilityHint = NSLocalizedString(
                "Double tap to insert a space. Touch and hold, then drag to move the cursor",
                comment: "space key accessibility hint"
            )
        case .character(let base, _):
            guard !QwertyAlternates.values(for: base).isEmpty else { break }
            button.onAccessibilityAlternate = { [weak self] value in
                guard let self else { return false }
                self.insertAlternate(value)
                return true
            }
            button.setAlternateAccessibilityValues(
                QwertyAlternates.values(for: base, uppercase: shift.state != .lowercase)
            )
            let recognizer = UILongPressGestureRecognizer(target: self,
                                                          action: #selector(characterLongPressedForAlternates(_:)))
            recognizer.minimumPressDuration = 0.4
            recognizer.allowableMovement = .greatestFiniteMagnitude
            button.addGestureRecognizer(recognizer)
        case .emojiMode, .emojiResult:
            // Task 6 owns emoji routing. Keeping these explicit prevents a new key kind from
            // silently inheriting unrelated gesture wiring at this checkpoint.
            break
        default:
            break
        }
    }

    @objc private func characterLongPressedForAlternates(_ recognizer: UILongPressGestureRecognizer) {
        guard let button = recognizer.view as? QwertyKeyButton,
              case .character(let base, _) = button.key.kind else { return }
        switch recognizer.state {
        case .began:
            onUserActivity()
            let values = QwertyAlternates.values(for: base,
                                                  uppercase: shift.state != .lowercase)
            keyboardView.showAlternates(values, from: button)
            _ = keyboardView.updateAlternateHighlight(
                at: recognizer.location(in: keyboardView)
            )
        case .changed:
            _ = keyboardView.updateAlternateHighlight(
                at: recognizer.location(in: keyboardView)
            )
        case .ended:
            guard let value = keyboardView.releaseAlternate() else { return }
            insertAlternate(value)
        case .cancelled, .failed:
            keyboardView.dismissAlternates()
        default:
            break
        }
    }

    private func insertAlternate(_ value: String) {
        QwertyLatencyInstrumentation.measureTextCommit {
            onUserActivity()
            invalidateCorrectionForOtherEdit()
            let decision = QwertyPunctuationRules.decision(
                before: textDocumentProxy.documentContextBeforeInput,
                inserting: value
            )
            for _ in 0..<decision.deletions { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(decision.insertion)
            recordTypingAction(.keyTaps)
            didInsert(decision.insertion)
        }
    }
}

// MARK: - QwertySuggestionBarViewDelegate

extension QwertyPageHost: QwertySuggestionBarViewDelegate {

    func suggestionBar(_ bar: QwertySuggestionBarView,
                       didSelect content: QwertySuggestionBarView.State.Content) {
        onUserActivity()
        switch content {
        case .suggestion(.literal(let word)):
            invalidateCorrectionForOtherEdit()
            // Accept the word exactly as typed — and never auto-correct it this session.
            // An explicit chip tap is the strongest acceptance signal the dictionary gets;
            // it accepts the word's buffered final-letter tap too.
            let rejectedCount = autocorrectHistory.rejectedWords.count
            autocorrectHistory.reject(word)
            if autocorrectHistory.rejectedWords.count != rejectedCount {
                invalidateSuggestionRejections()
            }
            recordAcceptance(of: word)
            commitPendingTouchSample()
            textDocumentProxy.insertText(" ")
        case .suggestion(.candidate(let word)):
            invalidateCorrectionForOtherEdit()
            if let current = QwertyAutocorrect.currentWord(
                before: textDocumentProxy.documentContextBeforeInput) {
                replaceCurrentWord(current, with: word)
            } else {
                textDocumentProxy.insertText(word)
            }
            recordAcceptance(of: word)
            TypingQualityCounters.increment(.suggestionsAccepted)
            // The typed word was replaced by the chip — its buffered final-letter tap was
            // part of the miss; it must not commit on the next key (review follow-up).
            pendingTouchSample = nil
            textDocumentProxy.insertText(" ")
        case .undoLiteral:
            guard revertPendingCorrection() else {
                invalidateCorrectionForOtherEdit()
                refreshSuggestions()
                return
            }
            refreshAutocap()
            refreshSuggestions()
            return
        case .suggestion(.empty), .corrected, .empty:
            return
        }
        // Chip taps end a word — a flush point like insertBoundary()/handleSpace().
        flushTouchPersonalization()
        didInsert(" ")
    }
}

// MARK: - QwertyKeyboardViewGlideDelegate (glide-and-accuracy design §4.3 — ships DARK)

extension QwertyPageHost: QwertyKeyboardViewGlideDelegate {

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCompleteGlide path: [CGPoint]) {
        onUserActivity()
        // Defense in depth: the recognizer only exists while the gate passes, but the flag
        // can flip mid-gesture via settings sync — never decode or insert with the gate off.
        // While the flag has never been on, this delegate never fires at all (the recognizer
        // object doesn't exist), so flag-off behavior stays byte-for-byte unchanged.
        guard FeatureFlags.isGlideTypingActive else { return }

        // The glide supersedes the in-progress word (Task-8 report note 1): the previously
        // buffered letter tap's acceptance evidence is ambiguous now — discard it, never
        // learn from it. This holds even when the decode below yields nothing: the gesture
        // itself already cancelled the tap, so the buffered offset's fate was decided by
        // the glide, not by whatever the decoder returns.
        pendingTouchSample = nil

        // Missing/corrupt lexicon blob or degenerate layout: nothing could ever decode —
        // suppress everything (no insertion, no bar override). The trail already faded in
        // the view on .ended; there is no text side effect to undo.
        let decoder = resolvedGlideDecoder()
        guard !decoder.isEmpty else { return }

        // Candidate 0 wins; no candidates → do nothing (same no-side-effect reasoning).
        let candidates = decoder.decode(path: path)
        guard let top = candidates.first else { return }

        // Autocap/shift parity with tapped letters: the decoder's candidates are all
        // lowercase, so capture the shift state NOW (applyPostInsertionState below consumes
        // a one-shot shift) and case the inserted word AND the chip alternates identically
        // — a tapped alternate must match the casing of the word it replaces.
        let shiftState = shift.state
        let word = QwertyGlideInsertion.applying(shiftState: shiftState, to: top.word)

        // Chaining (design §4.3): gliding straight after a word supplies the separating
        // space the user never typed. Deliberately a bare insertText — NOT handleSpace()/
        // insertBoundary(" "): the previous word keeps exactly what the user left there
        // (no autocorrect pass, no double-space period, no touch-sample bookkeeping — the
        // buffer was just discarded above).
        if QwertyGlideInsertion.leadingSpaceNeeded(
            before: textDocumentProxy.documentContextBeforeInput) {
            textDocumentProxy.insertText(" ")
        }

        // The glide voids any one-backspace revert contract from a previous autocorrection
        // — backspace after a glide must delete, not resurrect an older word.
        invalidateCorrectionForOtherEdit()

        // No trailing boundary: the glided word stays the "current word", so the personal
        // dictionary learns it at the NEXT boundary through the ordinary
        // applyPendingCorrection() → recordAcceptance() path, exactly like a typed word —
        // no special path — and the chips below can still replace it wholesale.
        textDocumentProxy.insertText(word)
        applyPostInsertionState(for: word)

        // Bar override: the DECODER's candidates instead of refreshSuggestions()'s
        // spell-checker output, so alternates are one tap away. The existing chip handlers
        // already do the right thing with these — verified, no special cases needed:
        //   .literal(top): records acceptance + inserts the trailing space — accepts the
        //     glided word as-is (commitPendingTouchSample() inside is a no-op; the buffer
        //     was discarded above).
        //   .candidate(alt): replaces the current word — the glided word — with the
        //     alternate via replaceCurrentWord, then records + spaces.
        // The next keystroke/text change reverts the bar to spell-checker suggestions
        // naturally (every path funnels through refreshSuggestions()).
        var suggestions: [QwertyAutocorrect.Suggestion] = [.literal(word)]
        suggestions.append(contentsOf: candidates.dropFirst().map {
            .candidate(QwertyGlideInsertion.applying(shiftState: shiftState, to: $0.word))
        })
        let glideState = QwertySuggestionBarView.State.suggestions(suggestions)
        let isNewImpression = glideState.isNewCandidateImpression(comparedTo: suggestionBar.state)
        _ = suggestionBar.show(glideState)
        if isNewImpression {
            TypingQualityCounters.increment(.suggestionsShown)
        }
        // No prefix-completion signal exists for a just-glided WHOLE word, so there is
        // nothing for QwertyTouchRouting to bias toward — clear the stale pre-glide bias
        // rather than leaving it; the next refreshSuggestions() repopulates it.
        view.touchBias = [:]
    }

    /// Returns the cached decoder when the rendered letter-key centers still match what it
    /// was built from; otherwise builds (first glide) or rebuilds (geometry changed) and
    /// re-caches. See `glideDecoderCache` for the laziness/synchronous-build rationale.
    private func resolvedGlideDecoder() -> QwertyGlideDecoder {
        let centers = keyboardView.letterKeyCenters()
        if let cache = glideDecoderCache, cache.centers == centers {
            return cache.decoder
        }
        let decoder = QwertyGlideDecoder(keyCenters: centers, lexicon: frequencyLexicon)
        glideDecoderCache = (decoder: decoder, centers: centers)
        return decoder
    }
}
