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
    /// Learned words (design §2): protects accepted words from autocorrect and ranks them
    /// first in the bar. Reloaded on every page activation, so an app-side "Reset Typing
    /// Personalization" takes effect on the next raise without any broadcast — PRIVACY: this
    /// store never posts SettingsSync, never logs analytics, and has no export path.
    private var personalDictionary = QwertyPersonalDictionary()
    /// Learned per-key touch offsets (design §3): the mean-offset half of arXiv:2209.11311.
    /// Same lifecycle and PRIVACY posture as `personalDictionary` — reloaded on every page
    /// activation, never SettingsSync-posted, never analytics-logged, no export path.
    private var touchPersonalization = QwertyTouchPersonalization()
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
    /// The reset generation `personalDictionary`/`touchPersonalization` were loaded against —
    /// see reloadPersonalizationIfResetElsewhere for the Split View stale-write-back guard
    /// this backs (ONE counter for both stores).
    private var loadedResetGeneration = 0
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
        keyboardView.glideDelegate = self
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
        personalDictionary = QwertyPersonalDictionary(data: UserPrefs.qwertyPersonalDictionaryData)
        touchPersonalization = QwertyTouchPersonalization(data: UserPrefs.qwertyTouchOffsetsData)
        loadedResetGeneration = UserPrefs.qwertyPersonalResetGeneration
        pendingTouchSample = nil
        touchOffsetsDirty = false
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
        // Glide availability re-evaluates on every settings sync so a Beta-toggle flip (or
        // the mirrored RC kill switch) lands on a LIVE keyboard without waiting for a grid
        // rebuild. Idempotent — a no-op when the recognizer already matches the gate; while
        // the flag has never been on, the recognizer never exists and this changes nothing.
        keyboardView.updateGlideAvailability()
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
        // configure() dropped the stale per-index offset map with the old grid — repopulate
        // from the model for the new key set.
        rebuildViewTouchOffsets()
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
        // The word survived the boundary (applyPendingCorrection discards the buffered tap
        // on any replacement) — accept its final letter tap and persist the word's
        // accumulated samples in one write.
        commitPendingTouchSample()
        flushTouchPersonalization()
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
            // The typed word was replaced — its buffered final-letter tap was evidence of
            // a miss, not a habit; never learn it (review follow-up).
            pendingTouchSample = nil
            return
        }

        let analysis = spellChecker.analyze(word: word)
        let decision = QwertyAutocorrect.decide(word: word,
                                                isMisspelled: analysis.isMisspelled,
                                                guesses: rankedGuesses(for: word, analysis: analysis),
                                                userRejected: autocorrectHistory.rejectedWords,
                                                isUserKnownWord: personalDictionary.isKnown(word))
        if case .replace(let corrected) = decision {
            replaceCurrentWord(word, with: corrected)
            autocorrectHistory.recordCorrection(original: word, corrected: corrected)
            // Same rule as the expansion branch above: a corrected word's final-letter tap
            // must not commit on the next key.
            pendingTouchSample = nil
        } else {
            // The word survived the boundary as typed (neither lexicon expansion nor
            // autocorrect fired) — that's an acceptance the dictionary learns from.
            recordAcceptance(of: word)
        }
    }

    /// The ONE guess pipeline behind both applyPendingCorrection() and
    /// refreshSuggestions(): frequency re-rank (`rerankKnown`) first, then typo-variant
    /// repair augments LAST — a checker-validated doubling repair now takes the
    /// auto-apply head slot unconditionally.
    ///
    /// MEASURED BASIS (docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md,
    /// Task 6b addendum): the offline harness scored this exact shape — arm
    /// `noSpatialAugmentLast` — best on the human-typo wiki corpus at 82.0% top-1,
    /// vs 79.7% for augment-last WITH the spatial resort (`variantsLast`) and 77.5%
    /// for the previous production ordering (`variants`). The spatial resort
    /// (`QwertySpatialScore`) measured net-negative in this path on BOTH corpora and
    /// is dropped from production; it remains harness/tuning-only.
    ///
    /// Division of authority: frequency decides the order among corpus-KNOWN guesses;
    /// OUT-OF-CORPUS guesses keep the checker's slots (`rerankKnown` never moves an
    /// unknown word — a correct proper-noun/jargon guess is never demoted); and an
    /// oracle-accepted doubling repair overrides both for index 0.
    /// PERF: refreshSuggestions() runs per keystroke, so the augment step (≤
    /// `QwertyTypoVariants.maxVariants` checker probes, via the verdict-only
    /// `isMisspelled(word:)` — never `analyze`) is gated on `analysis.isMisspelled` — a
    /// correctly-spelled word has empty guesses, must never grow a repair (the
    /// misspelling verdict stays untouched), and skips the probes.
    private func rankedGuesses(for word: String,
                               analysis: QwertySpellChecker.Analysis) -> [String] {
        let reranked = frequencyLexicon.rerankKnown(analysis.guesses)
        guard analysis.isMisspelled else { return reranked }
        return QwertyTypoVariants.augment(
            guesses: reranked, word: word,
            isRealWord: { !spellChecker.isMisspelled(word: $0) })
    }

    /// iPad Split View stale-write-back guard: the container app can Reset Typing
    /// Personalization while this keyboard is raised in the adjacent app — persisting a
    /// stale in-memory copy would silently undo that reset. The contentless generation
    /// counter detects it (an Int moves across the app group, never learned content, so the
    /// privacy constraint holds): on mismatch, drop BOTH stale copies (the dictionary and
    /// the touch offsets share one counter) and reload from storage (empty right after a
    /// reset), so the caller applies only its current mutation on top. Call before every
    /// persist of either store.
    private func reloadPersonalizationIfResetElsewhere() {
        let generation = UserPrefs.qwertyPersonalResetGeneration
        guard generation != loadedResetGeneration else { return }
        personalDictionary = QwertyPersonalDictionary(data: UserPrefs.qwertyPersonalDictionaryData)
        touchPersonalization = QwertyTouchPersonalization(data: UserPrefs.qwertyTouchOffsetsData)
        // Any unflushed in-memory samples died with the stale copy — the reset wins over a
        // few lost taps, and flushTouchPersonalization() must not write them back.
        touchOffsetsDirty = false
        loadedResetGeneration = generation
    }

    /// Learns one accepted word and persists the dictionary. PRIVACY (design §2): no
    /// `SettingsSync.post()`, no analytics — the blob stays inside the app group.
    private func recordAcceptance(of word: String) {
        reloadPersonalizationIfResetElsewhere()
        var updated = personalDictionary
        guard updated.recordAcceptance(of: word) else { return }  // hygiene-rejected: no write
        personalDictionary = updated
        UserPrefs.qwertyPersonalDictionaryData = updated.encoded()
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
        UserPrefs.qwertyTouchOffsetsData = touchPersonalization.encoded()
        // The flushed samples may have graduated a key past warmup (or nudged a learned
        // offset) — refresh the view's routing map.
        rebuildViewTouchOffsets()
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
        applyPendingCorrection()
        // Word boundary — same acceptance + single-write flush as insertBoundary().
        commitPendingTouchSample()
        flushTouchPersonalization()
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
        // Completions get the FULL re-rank (their alphabetical order carries no signal);
        // spatial and typo-variant repair never touch completions — prefix-extensions of
        // a correctly-typed prefix carry no spatial or doubling signal. Guesses share
        // `rankedGuesses(for:analysis:)` with applyPendingCorrection(). Personal-first
        // ordering applies AFTER the frequency prior (design §2: lexicon expansion →
        // personal words → frequency-ranked guesses → completions).
        let completions = QwertyAutocorrect.rankCandidates(
            frequencyLexicon.rerank(analysis.completions),
            personalBoost: personalDictionary.boost(for:))
        let guesses = QwertyAutocorrect.rankCandidates(
            rankedGuesses(for: word, analysis: analysis),
            personalBoost: personalDictionary.boost(for:))
        suggestionBar.show(QwertyAutocorrect.suggestions(word: word,
                                                         guesses: guesses,
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
            // Autorepeat deletion never reaches qwertyKeyboardView(_:didTap:) (the recognizer
            // cancels the button's touch), so discard the buffered tap sample here too — the
            // user is deleting, the same signal as a single backspace tap.
            pendingTouchSample = nil
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
            // Settle the buffered tap and persist first: the host has no dedicated
            // deactivation hook, so page exits are flush points.
            commitPendingTouchSample()
            flushTouchPersonalization()
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
            // A page exit like .numpadFlip above — settle and persist before lowering.
            commitPendingTouchSample()
            flushTouchPersonalization()
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
            // An explicit chip tap is the strongest acceptance signal the dictionary gets;
            // it accepts the word's buffered final-letter tap too.
            autocorrectHistory.reject(word)
            recordAcceptance(of: word)
            commitPendingTouchSample()
            textDocumentProxy.insertText(" ")
        case .candidate(let word):
            if let current = QwertyAutocorrect.currentWord(
                before: textDocumentProxy.documentContextBeforeInput) {
                replaceCurrentWord(current, with: word)
            } else {
                textDocumentProxy.insertText(word)
            }
            recordAcceptance(of: word)
            // The typed word was replaced by the chip — its buffered final-letter tap was
            // part of the miss; it must not commit on the next key (review follow-up).
            pendingTouchSample = nil
            textDocumentProxy.insertText(" ")
        }
        // Chip taps end a word — a flush point like insertBoundary()/handleSpace().
        flushTouchPersonalization()
        didInsert(" ")
    }
}

// MARK: - QwertyKeyboardViewGlideDelegate (glide-and-accuracy design §4.3 — ships DARK)

extension QwertyPageHost: QwertyKeyboardViewGlideDelegate {

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCompleteGlide path: [CGPoint]) {
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
        autocorrectHistory.noteOtherEdit()

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
        suggestionBar.show(suggestions)
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
