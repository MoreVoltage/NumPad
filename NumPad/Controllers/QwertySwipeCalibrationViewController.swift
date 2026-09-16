#if DEBUG && NUMPAD_PRIVATE_SWIPE
import UIKit

/// James's local development exercise. It reuses the shipping renderer and requires a
/// fresh three-sentence calibration covering every letter.
final class QwertySwipeCalibrationViewController: UIViewController,
    QwertyKeyboardViewDelegate, QwertyKeyboardViewGlideDelegate {
    private let keyboard = QwertyKeyboardView()
    private let canvas = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let detail = UILabel()
    private let prompt = UILabel()
    private let progress = UILabel()
    private let primary = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let globe = UISwitch()
    private var heightConstraint: NSLayoutConstraint!
    private var session: QwertySwipeCalibration.Session?
    private var pendingPath: [CGPoint]?
    private var pendingTimestamps: [TimeInterval]?
    private var contextID: String?
    private var decoder: QwertyGlideDecoder?
    private var layer = QwertyLayer.letters
    private var shift = QwertyShiftMachine()
    private var topStrip: QwertyTopStrip = .numbers
    private let store = QwertySwipeCalibrationStore()
    private var options: QwertyLayoutOptions {
        .init(periodCommaOnLetters: UserPrefs.qwertyPeriodComma, needsSwitchKey: globe.isOn,
              needsDismissKey: traitCollection.userInterfaceIdiom == .pad)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Private swipe calibration"
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "calibration.private-swipe"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "History", style: .plain, target: self, action: #selector(history))
        keyboard.delegate = self
        keyboard.glideDelegate = self
        keyboard.calibrationPracticeMode = true
        keyboard.calibrationAllowsSwipe = true
        globe.isOn = true
        buildInterface()
        topStrip = selectedTopStrip()
        renderKeyboard()
        introduction()
        NotificationCenter.default.addObserver(self, selector: #selector(checkpoint), name: UIApplication.willResignActiveNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let container = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: view.window?.bounds.height, screenHeight: UIScreen.main.bounds.height)
        let height = KeyboardHeightPreset.resolvedHeight(stored: KeyboardHeightPreset.selected,
            kioskEntitled: Monetization.isKioskHeightEntitled, idiom: traitCollection.userInterfaceIdiom,
            compactHeight: traitCollection.verticalSizeClass == .compact, containerHeight: container)
        if abs(heightConstraint.constant - height) > 0.5 { heightConstraint.constant = max(height, 160) }
        let composition = IPadKeyboardCompositionGeometry.resolve(bounds: canvas.bounds,
            idiom: traitCollection.userInterfaceIdiom, horizontalSizeClass: traitCollection.horizontalSizeClass,
            layout: UserPrefs.iPadQwertyLayout, numpadSide: UserPrefs.fullKeyboardNumpadSide)
        var frame = composition.qwertyFrame
        frame.origin.y += 44
        frame.size.height = max(0, frame.height - 44)
        keyboard.frame = frame
        keyboard.calibrationCompositionBounds = canvas.bounds
        keyboard.layoutIfNeeded()
        if let contextID, session != nil, contextID != keyboard.calibrationGeometryContextID {
            checkpoint()
            session = nil; pendingPath = nil
            introduction()
            detail.text = "Keyboard geometry changed. Resume in the original size, or complete a three-sentence calibration for this layout first."
        }
    }

    private func buildInterface() {
        [canvas, scroll, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(scroll); view.addSubview(canvas); canvas.addSubview(keyboard); scroll.addSubview(stack)
        stack.axis = .vertical; stack.spacing = 12
        heightConstraint = canvas.heightAnchor.constraint(equalToConstant: 300)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), heightConstraint,
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: canvas.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        for label in [detail, prompt, progress] {
            label.numberOfLines = 0; label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true; stack.addArrangedSubview(label)
        }
        prompt.font = .preferredFont(forTextStyle: .largeTitle)
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 12
        let globeLabel = UILabel(); globeLabel.text = "Show globe key (match tap calibration)"; globeLabel.numberOfLines = 0
        row.addArrangedSubview(globeLabel); row.addArrangedSubview(globe); stack.addArrangedSubview(row)
        globe.addTarget(self, action: #selector(globeChanged), for: .valueChanged)
        primary.addTarget(self, action: #selector(advance), for: .touchUpInside)
        retryButton.setTitle("Retry gesture", for: .normal)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        stack.addArrangedSubview(primary); stack.addArrangedSubview(retryButton)
    }

    private func selectedTopStrip() -> QwertyTopStrip {
        if IPadKeyboardCompositionGeometry.shouldForceNumberStrip(idiom: traitCollection.userInterfaceIdiom, layout: UserPrefs.iPadQwertyLayout) { return .numbers }
        guard let pack = QwertyPackFamily.packToShow(behavior: UserPrefs.packDisplayBehavior,
            lastUsed: UserPrefs.qwertyTopStripPack, primary: UserPrefs.qwertyPrimaryPack),
            QwertyPackFamily.members.contains(pack), !Monetization.isLocked(pack: pack) else { return .numbers }
        let content = QwertyPackFamily.content(for: pack, customKeys: CustomPackManager.shared.keys, snippets: SnippetsManager.shared.snippets)
        return content.isEmpty ? .numbers : .pack(content)
    }
    private func renderKeyboard() {
        keyboard.configure(rows: QwertyLayout.rows(layer: layer, options: options), topStrip: QwertyTopStrip.keys(for: topStrip))
        keyboard.update(shiftState: shift.state); keyboard.layoutIfNeeded()
    }
    private func introduction() {
        detail.text = "Local development only. First complete a fresh three-sentence calibration for this exact layout; that covers A–Z. Then swipe supplied words covering every letter in at least three different words. Confirm your intended word after each gesture. No normal message text is saved."
        prompt.text = nil; progress.text = nil; globe.isEnabled = true
        primary.setTitle("Enable private swipe and start or resume", for: .normal)
        primary.isEnabled = true; retryButton.isHidden = true; keyboard.isUserInteractionEnabled = false
    }
    @objc private func globeChanged() { renderKeyboard() }
    @objc private func close() { checkpoint(); dismiss(animated: true) }
    @objc private func checkpoint() {
        if let session, !store.saveCheckpoint(session) {
            self.session = nil; pendingPath = nil; introduction()
            detail.text = "Swipe calibration was reset or this run already finished. Start a new run."
        }
    }
    @objc private func retry() { pendingPath = nil; primary.isEnabled = false; detail.text = "Swipe the supplied word, then lift your finger." }

    @objc private func advance() {
        if session == nil { start(); return }
        guard let path = pendingPath, let word = session?.nextWord,
              session?.acceptConfirmedPath(path, word: word, centers: keyboard.letterKeyCenters(), timestamps: pendingTimestamps) == true else {
            detail.text = "This gesture could not be reliably matched to the prompt. Please try again."
            pendingPath = nil; primary.isEnabled = false; return
        }
        checkpoint(); showNext()
    }
    private func start() {
        keyboard.layoutIfNeeded()
        let context = keyboard.calibrationGeometryContextID
        let manifest = QwertyCalibrationManifest.make(options: options, topStrip: topStrip, contextID: context)
        let usedTapRuns = Set(store.runs(contextID: context).map(\.tapRunID))
        guard let tapRun = QwertyCalibrationStore.shared.load().runs.last(where: {
            $0.manifest == manifest && $0.hasFullCoverage && !usedTapRuns.contains($0.id)
        }) else {
            detail.text = "Complete a fresh three-sentence calibration for this keyboard size, top row, and globe setting first. Each new swipe calibration starts with those three sentences."
            return
        }
        FeatureFlags.qwertyGlideTyping = true
        guard FeatureFlags.isGlideTypingActive else { detail.text = "The existing swipe kill switch is off. Calibration cannot start while swipe is disabled."; return }
        keyboard.updateGlideAvailability()
        contextID = context
        decoder = QwertyGlideDecoder(keyCenters: keyboard.letterKeyCenters(), lexicon: QwertyFrequencyLexicon(bundled: .main))
        guard decoder?.isEmpty == false else { detail.text = "The word lexicon is unavailable. Swipe calibration cannot start."; return }
        session = store.checkpoint(contextID: context, tapRunID: tapRun.id)
            ?? .init(contextID: context, tapRunID: tapRun.id, generation: store.generation)
        globe.isEnabled = false; keyboard.isUserInteractionEnabled = true; showNext()
    }
    private func showNext() {
        pendingPath = nil
        guard let session else { return }
        if session.complete { finish(); return }
        layer = .letters; shift = QwertyShiftMachine(); renderKeyboard()
        prompt.text = session.nextWord
        progress.text = session.coverage.complete
            ? "Fresh-word validation: \(session.heldOut.count) / \(QwertySwipeCalibration.validationWords.count)"
            : "Letters covered in three distinct words: \(26 - session.coverage.missing.count) / 26. Missing: \(session.coverage.missing.joined(separator: " "))"
        detail.text = "Swipe this word naturally. Crossed keys do not count as intended letters. Tap controls remain available; return to letters to continue."
        primary.setTitle("I swiped the supplied word", for: .normal); primary.isEnabled = false; retryButton.isHidden = false
    }
    private func finish() {
        guard let session, let decoder,
              let run = session.evaluate(centers: keyboard.letterKeyCenters(), decoder: decoder,
                  current: store.activeProfile(contextID: session.contextID)) else { detail.text = "Validation could not finish. Your checkpoint is saved."; return }
        guard store.save(run) else {
            self.session = nil; introduction(); detail.text = "Calibration was reset. This outdated run was not saved."; return
        }
        let m = run.metrics
        detail.text = "\(m.accepted ? "New swipe profile applied." : "Previous swipe profile retained.") Fresh-word top-1 errors: default \(m.baselineTop1Errors), previous \(m.currentTop1Errors), candidate \(m.candidateTop1Errors), out of \(m.words). Top-3 misses: default \(m.baselineTop3Errors), previous \(m.currentTop3Errors), candidate \(m.candidateTop3Errors). Raw exercise paths removed."
        prompt.text = "Complete"; progress.text = "Every required tap key and intended swipe letter covered."
        self.session = nil; pendingPath = nil; primary.isEnabled = false; retryButton.isHidden = true
        keyboard.isUserInteractionEnabled = false
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCompleteGlide path: [CGPoint]) {
        guard session != nil, layer == .letters, contextID == keyboard.calibrationGeometryContextID else { return }
        pendingPath = path; pendingTimestamps = view.calibrationSwipeTimestamps; primary.isEnabled = true
        detail.text = "Confirm only if you intended the displayed word and completed its gesture. Retry accidental or interrupted gestures."
    }
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCreate button: QwertyKeyButton, for key: QwertyKey) {}
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey) {
        pendingPath = nil; primary.isEnabled = false
        switch key.kind {
        case .layerSwitch(let next): layer = next; renderKeyboard()
        case .shift: shift.shiftTapped(at: CACurrentMediaTime()); keyboard.update(shiftState: shift.state)
        case .backspace: detail.text = "Gesture cleared. Swipe the supplied word again."
        case .globe, .dismissKeyboard: checkpoint(); detail.text = "Checkpoint saved. System switching and dismissal keep their usual behavior."
        default: detail.text = "Tap received. Tap controls do not become swipe-letter samples. Swipe the supplied word to continue."
        }
    }
    @objc private func history() {
        let context = keyboard.calibrationGeometryContextID
        let alert = UIAlertController(title: "Private swipe history", message: "Only validated profiles can be restored. Reset removes all swipe runs and checkpoints; tap data stays separate.", preferredStyle: .actionSheet)
        for run in store.runs(contextID: context).reversed().filter({ $0.metrics.accepted }).prefix(8) {
            alert.addAction(UIAlertAction(title: DateFormatter.localizedString(from: run.date, dateStyle: .short, timeStyle: .short), style: .default) { [weak self] _ in
                _ = self?.store.restore(runID: run.id, contextID: context)
            })
        }
        alert.addAction(UIAlertAction(title: "Reset swipe calibration", style: .destructive) { [weak self] _ in
            self?.session = nil; self?.pendingPath = nil; self?.store.reset(); self?.introduction()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(alert, animated: true)
    }
}
#endif
