import UIKit

/// NumPad Type — the full-QWERTY keyboard extension (docs/plans/full-keyboard/, plan §2).
///
/// V1 free-floor build: typing runs entirely on the pure `Qwerty*` logic (shift/caps machine,
/// autocap, double-space period, layer bounce rules) — this controller is deliberately thin
/// glue between those models, `QwertyKeyboardView`, and `textDocumentProxy`. Autocorrect
/// (`UITextChecker`) and the suggestion bar land with Phase 1's build-out; core typing works
/// with Full Access off by construction (App Review 4.4.1).
class QwertyKeyboardViewController: UIInputViewController {

    private let keyboardView = QwertyKeyboardView()
    private var shift = QwertyShiftMachine()
    private var activeLayer: QwertyLayer = .letters
    private var lastSpaceTap: TimeInterval?
    private var heightConstraint: NSLayoutConstraint?
    private var backspaceRepeatTimer: Timer?

    /// Base canvas height before any preset work — QWERTY rows plus the top strip. iPad and
    /// preset-aware heights follow the numpad extension's `KeyboardHeightPreset` in a later
    /// Phase-1 pass.
    private var baseHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 340 : 300
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardView.delegate = self
        view.addSubview(keyboardView)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        reloadKeys()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Remove/re-add each appearance — the numpad extension's iPad height-drift fix.
        updateHeightConstraint()
        reloadKeys()
        refreshAutocap()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateHeightConstraint()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshAutocap()
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

    // MARK: - Typing

    private func handleSpace() {
        let now = CACurrentMediaTime()
        let decision = DoubleSpacePeriod.decision(
            before: textDocumentProxy.documentContextBeforeInput,
            secondsSinceLastSpaceTap: lastSpaceTap.map { now - $0 },
            enabled: true)  // becomes a UserPrefs toggle in the settings pass
        for _ in 0..<decision.deletions { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(decision.insertion)
        lastSpaceTap = now
        didInsert(decision.insertion)
    }

    /// Shared post-insertion bookkeeping: consume one-shot shift, apply layer bounce rules,
    /// and re-evaluate autocap against the new context.
    private func didInsert(_ text: String) {
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

    // MARK: - Backspace autorepeat

    @objc private func backspaceLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1,
                                                        repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
                self?.refreshAutocap()
            }
        case .ended, .cancelled, .failed:
            backspaceRepeatTimer?.invalidate()
            backspaceRepeatTimer = nil
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
            textDocumentProxy.insertText(text)
            didInsert(text)
        case .space:
            handleSpace()
        case .backspace:
            textDocumentProxy.deleteBackward()
            refreshAutocap()
        case .ret:
            textDocumentProxy.insertText("\n")
            didInsert("\n")
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
