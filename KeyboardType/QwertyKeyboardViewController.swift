import UIKit

/// NumPad Type — the full-QWERTY keyboard extension (docs/plans/full-keyboard/, plan §2).
///
/// V1 free-floor build: typing runs entirely on the pure `Qwerty*` logic (shift/caps machine,
/// autocap, double-space period, layer bounce rules, autocorrect decisions) — this controller
/// is deliberately thin glue between those models, the views, and `textDocumentProxy`.
/// Spell checking uses `UITextChecker` + the supplementary lexicon, both on-device and
/// available with Full Access off, so core typing satisfies App Review 4.4.1 by construction.
class QwertyKeyboardViewController: UIInputViewController {

    private let suggestionBar = QwertySuggestionBarView()
    private let keyboardView = QwertyKeyboardView()
    private let spellChecker = QwertySpellChecker()

    private var shift = QwertyShiftMachine()
    private var autocorrectHistory = QwertyAutocorrectHistory()
    private var activeLayer: QwertyLayer = .letters
    private var lastSpaceTap: TimeInterval?
    private var heightConstraint: NSLayoutConstraint?
    private var backspaceRepeatTimer: Timer?

    private enum Metrics {
        static let suggestionBarHeight: CGFloat = 44
    }

    /// Base canvas height (suggestion bar + top strip + four key rows). iPad and preset-aware
    /// heights follow the numpad extension's `KeyboardHeightPreset` in a later Phase-1 pass;
    /// the exact numbers are re-measured in the Phase-3 device gates.
    private var baseHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 384 : 344
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        suggestionBar.delegate = self
        keyboardView.delegate = self
        view.addSubview(suggestionBar)
        view.addSubview(keyboardView)
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: Metrics.suggestionBarHeight),
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        spellChecker.loadLexicon(from: self)
        reloadKeys()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Remove/re-add each appearance — the numpad extension's iPad height-drift fix.
        updateHeightConstraint()
        reloadKeys()
        refreshAutocap()
        refreshSuggestions()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateHeightConstraint()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshAutocap()
        refreshSuggestions()
    }

    // MARK: - Keyboard assembly

    private var layoutOptions: QwertyLayoutOptions {
        // The period/comma switch becomes a real `UserPrefs` setting in the settings pass
        // (owner decision §0.2 — default ON either way).
        QwertyLayoutOptions(periodCommaOnLetters: true,
                            needsSwitchKey: needsInputModeSwitchKey)
    }

    private func reloadKeys() {
        keyboardView.returnKeyLabel = returnKeyLabel()
        keyboardView.configure(rows: QwertyLayout.rows(layer: activeLayer, options: layoutOptions),
                               topStrip: QwertyTopStrip.keys(for: .numbers))
        keyboardView.update(shiftState: shift.state)
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

    private func updateHeightConstraint() {
        if let constraint = heightConstraint {
            view.removeConstraint(constraint)
        }
        let constraint = view.heightAnchor.constraint(equalToConstant: baseHeight)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        heightConstraint = constraint
    }

    // MARK: - Typing pipeline

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
        let decision = QwertyAutocorrect.decide(word: word,
                                                isMisspelled: analysis.isMisspelled,
                                                guesses: analysis.guesses,
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
            return
        }
        let analysis = spellChecker.analyze(word: word)
        suggestionBar.show(QwertyAutocorrect.suggestions(word: word,
                                                         guesses: analysis.guesses,
                                                         completions: analysis.completions))
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

extension QwertyKeyboardViewController: QwertyKeyboardViewDelegate {

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
            break  // one-tap numpad flip lands with the pack/number-row pass (plan §2)
        }
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didCreate button: QwertyKeyButton,
                            for key: QwertyKey) {
        switch key.kind {
        case .globe:
            // The documented wiring: tap advances, long-press shows the system keyboard
            // list, pixel-identical to the native globe (technical doc §1/§4).
            button.addTarget(self,
                             action: #selector(handleInputModeList(from:with:)),
                             for: .allTouchEvents)
        case .backspace:
            let recognizer = UILongPressGestureRecognizer(target: self,
                                                          action: #selector(backspaceLongPressed(_:)))
            recognizer.minimumPressDuration = 0.5
            button.addGestureRecognizer(recognizer)
        default:
            break
        }
    }
}

// MARK: - QwertySuggestionBarViewDelegate

extension QwertyKeyboardViewController: QwertySuggestionBarViewDelegate {

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
