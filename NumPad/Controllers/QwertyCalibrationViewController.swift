import UIKit

/// A supervised practice host for the production key renderer. It never edits a host app,
/// opens a URL, or accepts pasted/programmatic text as touch evidence.
final class QwertyCalibrationViewController: UIViewController, QwertyKeyboardViewDelegate, UIGestureRecognizerDelegate {
    private let keyboard = QwertyKeyboardView()
    private let keyboardCanvas = UIView()
    private let sideCaption = UILabel()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let promptLabel = UILabel()
    private let typedLabel = UILabel()
    private let coverageLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let primaryButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let globeSwitch = UISwitch()
    private var canvasHeight: NSLayoutConstraint!
    private var hasStarted = false
    private var page = QwertyCalibrationPage.letters
    private var shift = QwertyShiftMachine()
    private var topStrip: QwertyTopStrip = .numbers
    private var manifest: QwertyCalibrationManifest?
    private var session: QwertyCalibrationSession?
    private var exercise: QwertyCalibrationExercise?
    private var pendingSamples: [QwertyCalibrationSample] = []
    private var observed: [String] = []
    private var lastPhysicalTouch: QwertyCalibrationPhysicalTouch?
    private var gestureStart: CGPoint?
    private var gestureTouchID: String?
    private var geometryID: String?

    private var options: QwertyLayoutOptions {
        QwertyLayoutOptions(periodCommaOnLetters: UserPrefs.qwertyPeriodComma,
                            needsSwitchKey: globeSwitch.isOn,
                            needsDismissKey: traitCollection.userInterfaceIdiom == .pad)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Calibrate typing", comment: "Tap calibration screen title")
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "calibration.tap"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Close calibration"), style: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("History", comment: "Calibration history"), style: .plain, target: self, action: #selector(showHistory))
        buildInterface()
        keyboard.delegate = self
        keyboard.calibrationPracticeMode = true
        keyboard.onCalibrationTouch = { [weak self] touch in self?.receive(touch) }
        topStrip = selectedTopStrip()
        renderKeyboard()
        showIntroduction()
        NotificationCenter.default.addObserver(self, selector: #selector(checkpoint), name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit { deleteTimer?.invalidate(); NotificationCenter.default.removeObserver(self) }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let containerHeight = KeyboardHeightPreset.clampCeilingContainerHeight(windowHeight: view.window?.bounds.height, screenHeight: UIScreen.main.bounds.height)
        let height = KeyboardHeightPreset.resolvedHeight(stored: KeyboardHeightPreset.selected,
            kioskEntitled: Monetization.isKioskHeightEntitled, idiom: traitCollection.userInterfaceIdiom,
            compactHeight: traitCollection.verticalSizeClass == .compact, containerHeight: containerHeight)
        if abs(canvasHeight.constant - height) > 0.5 { canvasHeight.constant = max(height, 160) }
        let composition = IPadKeyboardCompositionGeometry.resolve(bounds: keyboardCanvas.bounds,
            idiom: traitCollection.userInterfaceIdiom, horizontalSizeClass: traitCollection.horizontalSizeClass,
            layout: UserPrefs.iPadQwertyLayout, numpadSide: UserPrefs.fullKeyboardNumpadSide)
        // The extension reserves 44 pt for suggestions above the key grid.
        var gridFrame = composition.qwertyFrame
        gridFrame.origin.y += 44
        gridFrame.size.height = max(0, gridFrame.height - 44)
        keyboard.frame = gridFrame
        keyboard.calibrationCompositionBounds = keyboardCanvas.bounds
        keyboard.layoutIfNeeded()
        sideCaption.frame = composition.numpadFrame?.insetBy(dx: 12, dy: 16) ?? .zero
        sideCaption.isHidden = composition.numpadFrame == nil
        if hasStarted, let geometryID, geometryID != keyboard.calibrationGeometryContextID {
            checkpoint()
            hasStarted = false
            exercise = nil
            pendingSamples.removeAll()
            observed.removeAll()
            showIntroduction()
            detailLabel.text = NSLocalizedString("The keyboard size or orientation changed. Your previous run is saved. Start or resume a run for this layout, or return to the previous size to continue it.", comment: "Calibration geometry change")
        }
    }

    private func buildInterface() {
        keyboardCanvas.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        view.addSubview(keyboardCanvas)
        scrollView.addSubview(stack)
        keyboardCanvas.addSubview(keyboard)
        keyboardCanvas.addSubview(sideCaption)
        stack.axis = .vertical
        stack.spacing = 12
        canvasHeight = keyboardCanvas.heightAnchor.constraint(equalToConstant: 300)
        NSLayoutConstraint.activate([
            keyboardCanvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardCanvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardCanvas.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), canvasHeight,
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboardCanvas.topAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        for label in [titleLabel, detailLabel, promptLabel, typedLabel, coverageLabel, sideCaption] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.font = .preferredFont(forTextStyle: .body)
        }
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        promptLabel.font = .preferredFont(forTextStyle: .title2)
        typedLabel.textColor = .secondaryLabel
        sideCaption.textColor = .secondaryLabel
        sideCaption.text = NSLocalizedString("Letters pane practice. Your separate NumPad pane is not part of this calibration.", comment: "Calibration iPad pane scope")
        [titleLabel, detailLabel, coverageLabel].forEach(stack.addArrangedSubview)
        stack.addArrangedSubview(progressView)
        stack.addArrangedSubview(promptLabel)
        stack.addArrangedSubview(typedLabel)
        let globeRow = UIStackView()
        globeRow.axis = .horizontal
        globeRow.spacing = 12
        let globeLabel = UILabel()
        globeLabel.numberOfLines = 0
        globeLabel.text = NSLocalizedString("My letters keyboard shows a globe key", comment: "Calibration globe configuration")
        globeLabel.font = .preferredFont(forTextStyle: .body)
        globeSwitch.isOn = true
        globeSwitch.accessibilityLabel = globeLabel.text
        globeSwitch.addTarget(self, action: #selector(globeChanged), for: .valueChanged)
        globeRow.addArrangedSubview(globeLabel)
        globeRow.addArrangedSubview(globeSwitch)
        stack.addArrangedSubview(globeRow)
        primaryButton.configuration = .filled()
        primaryButton.titleLabel?.numberOfLines = 0
        primaryButton.addTarget(self, action: #selector(primaryAction), for: .touchUpInside)
        primaryButton.accessibilityIdentifier = "calibration.confirm"
        retryButton.configuration = .plain()
        retryButton.setTitle(NSLocalizedString("Retry this exercise", comment: "Retry calibration exercise"), for: .normal)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        stack.addArrangedSubview(primaryButton)
        stack.addArrangedSubview(retryButton)
    }

    private func showIntroduction() {
        titleLabel.text = NSLocalizedString("Help NumPad learn where you tap", comment: "Calibration introduction")
        detailLabel.text = NSLocalizedString("Hold your device as you normally type. Practice every key, including capitals, symbols, controls, and long-press alternates. You can pause and resume; there is no time limit. Data stays on this device. Only a profile that improves fresh practice results is applied. Touch calibration requires direct finger input; accessibility actions and external keyboards do not create samples.", comment: "Calibration description")
        promptLabel.text = nil
        typedLabel.text = nil
        coverageLabel.text = NSLocalizedString("Choose the globe option to match your actual keyboard. This run covers the displayed letters layout and its selected top row.", comment: "Calibration configuration scope")
        progressView.progress = 0
        globeSwitch.isEnabled = true
        keyboard.isUserInteractionEnabled = false
        primaryButton.isEnabled = true
        primaryButton.setTitle(NSLocalizedString("Start or resume", comment: "Begin calibration"), for: .normal)
        retryButton.isHidden = false
        retryButton.setTitle(NSLocalizedString("Start a new run", comment: "Restart calibration entry"), for: .normal)
    }

    private func selectedTopStrip() -> QwertyTopStrip {
        if IPadKeyboardCompositionGeometry.shouldForceNumberStrip(idiom: traitCollection.userInterfaceIdiom, layout: UserPrefs.iPadQwertyLayout) { return .numbers }
        guard let pack = QwertyPackFamily.packToShow(behavior: UserPrefs.packDisplayBehavior,
            lastUsed: UserPrefs.qwertyTopStripPack, primary: UserPrefs.qwertyPrimaryPack),
            QwertyPackFamily.members.contains(pack), !Monetization.isLocked(pack: pack) else { return .numbers }
        let content = QwertyPackFamily.content(for: pack, customKeys: CustomPackManager.shared.keys,
                                              snippets: SnippetsManager.shared.snippets)
        return content.isEmpty ? .numbers : .pack(content)
    }

    private func renderKeyboard() {
        keyboard.configure(rows: QwertyLayout.rows(layer: page.layer, options: options), topStrip: QwertyTopStrip.keys(for: topStrip))
        let isCapsLockExercise = exercise?.expectedEntryIDs.first.flatMap { manifest?.entry(id: $0) }?.output == "capsLock"
        keyboard.update(shiftState: page.uppercase && !isCapsLockExercise ? .capsLock : shift.state)
        keyboard.layoutIfNeeded()
    }

    @objc private func globeChanged() { renderKeyboard() }
    @objc private func close() {
        deleteTimer?.invalidate()
        keyboard.dismissAlternates()
        guard let session else { dismiss(animated: true); return }
        QwertyCalibrationStore.shared.checkpoint(session, expectedGeneration: generation) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success: self.dismiss(animated: true)
            case .failure:
                let alert = UIAlertController(
                    title: NSLocalizedString("Your current run could not be saved", comment: "Calibration close persistence failure"),
                    message: NSLocalizedString("Try again, or leave without saving the latest exercises.", comment: "Calibration close recovery"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Try again", comment: "Retry calibration save"), style: .default) { [weak self] _ in self?.close() })
                alert.addAction(UIAlertAction(title: NSLocalizedString("Leave without saving", comment: "Discard unsaved calibration exercises"), style: .destructive) { [weak self] _ in
                    self?.session = nil
                    self?.dismiss(animated: true)
                })
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func primaryAction() {
        guard hasStarted else { startOrResume(); return }
        guard let exercise else { finish(); return }
        let accepted = session?.recordConfirmedExercise(exerciseID: exercise.id, samples: pendingSamples,
            observedOutputs: observed, userConfirmed: true) == true
        if accepted {
            checkpoint()
            showNextExercise()
        } else {
            detailLabel.text = NSLocalizedString("This attempt could not be labeled reliably. Repeat the exercise without skipping, adding, or correcting characters. You can skip a sentence; every missing key will still be practiced individually.", comment: "Rejected calibration attempt")
            retry()
        }
    }

    private func startOrResume() {
        keyboard.layoutIfNeeded()
        geometryID = keyboard.calibrationGeometryContextID
        let manifest = QwertyCalibrationManifest.make(options: options, topStrip: topStrip,
                                                       contextID: keyboard.calibrationGeometryContextID)
        self.manifest = manifest
        // Persistence is app-owned. No extension write permission is required here.
        let snapshot = QwertyCalibrationStore.shared.load()
        generation = snapshot.generation
        if let saved = snapshot.sessions[manifest.layoutFingerprint], saved.manifest == manifest {
            session = saved
        } else {
            session = QwertyCalibrationSession(manifest: manifest)
        }
        hasStarted = true
        globeSwitch.isEnabled = false
        keyboard.isUserInteractionEnabled = true
        showNextExercise()
    }

    private func showNextExercise() {
        guard let session else { return }
        pendingSamples.removeAll()
        observed.removeAll()
        lastPhysicalTouch = nil
        exercise = session.nextExercise
        coverageLabel.text = String(format: NSLocalizedString("%d of %d key actions fully covered", comment: "Calibration coverage"), session.coveredKeyCount, session.requiredKeyCount)
        progressView.progress = Float(session.coveredKeyCount) / Float(max(1, session.requiredKeyCount))
        guard let exercise else { finish(); return }
        page = exercise.page
        shift = QwertyShiftMachine()
        renderKeyboard()
        guard self.session?.recordGeometry(page: page, frames: keyboard.calibrationKeyFrames, bounds: keyboard.bounds) == true else {
            hasStarted = false
            showIntroduction()
            showError(NSLocalizedString("The keyboard geometry changed. Resume in the original size or start a separate run for this layout.", comment: "Calibration frame mismatch"))
            return
        }
        retryButton.isHidden = false
        retryButton.setTitle(exercise.isNatural ? NSLocalizedString("Retry or skip sentence", comment: "Natural calibration retry") : NSLocalizedString("Retry this exercise", comment: "Guided calibration retry"), for: .normal)
        titleLabel.text = exercise.isValidation
            ? NSLocalizedString("Check the new profile with fresh taps", comment: "Calibration heldout phase")
            : (exercise.isNatural ? NSLocalizedString("Type naturally", comment: "Natural calibration phase") : NSLocalizedString("Practice the remaining keys", comment: "Guided calibration phase"))
        promptLabel.text = exercise.isNatural ? exercise.text : instruction(for: exercise)
        detailLabel.text = exercise.isNatural
            ? NSLocalizedString("Type the supplied sentence exactly. Review the result, then confirm. Automatic corrections are off. If you skip or add a character, retry this sentence.", comment: "Natural calibration directions")
            : NSLocalizedString("Aim for the highlighted key using your usual grip. Confirm only if you attempted exactly the requested taps. Controls operate only in this practice area; they cannot switch apps or submit a form.", comment: "Guided calibration directions")
        primaryButton.setTitle(exercise.isNatural
            ? NSLocalizedString("I typed this sentence exactly", comment: "Confirm natural calibration intent")
            : NSLocalizedString("I aimed for the requested key", comment: "Confirm guided calibration intent"), for: .normal)
        updateAttempt()
        highlightTarget()
        UIAccessibility.post(notification: .layoutChanged, argument: promptLabel)
    }

    private func instruction(for exercise: QwertyCalibrationExercise) -> String {
        guard let entry = manifest?.entry(id: exercise.expectedEntryIDs.first ?? "") else { return exercise.text }
        switch entry.kind {
        case .alternate:
            return String(format: NSLocalizedString("Touch and hold the highlighted key, then slide to select %@.", comment: "Alternate calibration instruction"), entry.output)
        case .behavior:
            switch entry.output {
            case "capsLock": return NSLocalizedString("Double-tap Shift to turn on Caps Lock.", comment: "Caps lock calibration instruction")
            case "cursorHold": return NSLocalizedString("Hold Space, slide sideways, then lift your finger to move the practice cursor.", comment: "Cursor calibration instruction")
            default: return NSLocalizedString("Hold Delete to erase the practice text, then lift your finger.", comment: "Delete hold calibration instruction")
            }
        default:
            return String(format: NSLocalizedString("Tap %@ %d times.", comment: "Single key calibration instruction"), readable(entry.output), exercise.expectedEntryIDs.count)
        }
    }

    private func readable(_ output: String) -> String {
        switch output {
        case " ": return NSLocalizedString("Space", comment: "Calibration key")
        case "\n": return NSLocalizedString("Return", comment: "Calibration key")
        case "shift": return NSLocalizedString("Shift", comment: "Calibration key")
        case "backspace": return NSLocalizedString("Delete", comment: "Calibration key")
        case "globe": return NSLocalizedString("Globe", comment: "Calibration key")
        case "emoji": return NSLocalizedString("Emoji", comment: "Calibration key")
        case "numpad": return NSLocalizedString("NumPad", comment: "Calibration key")
        case "pack": return NSLocalizedString("Switch pack", comment: "Calibration key")
        case "dismiss": return NSLocalizedString("Hide keyboard", comment: "Calibration key")
        case "page:letters": return "ABC"
        case "page:symbols": return "123"
        case "page:extendedSymbols": return "#+="
        default: return output
        }
    }

    private let targetOutline = CAShapeLayer()
    private func highlightTarget() {
        targetOutline.removeFromSuperlayer()
        guard let exercise, !exercise.isNatural,
              let entry = manifest?.entry(id: exercise.expectedEntryIDs.first ?? ""),
              keyboard.calibrationKeyFrames.indices.contains(entry.buttonIndex) else { return }
        targetOutline.frame = keyboard.bounds
        targetOutline.path = UIBezierPath(roundedRect: keyboard.calibrationKeyFrames[entry.buttonIndex].insetBy(dx: 1, dy: 1), cornerRadius: 4).cgPath
        targetOutline.fillColor = UIColor.clear.cgColor
        targetOutline.strokeColor = UIColor.systemBlue.cgColor
        targetOutline.lineWidth = 3
        targetOutline.zPosition = 100
        keyboard.layer.addSublayer(targetOutline)
    }

    private func receive(_ touch: QwertyCalibrationPhysicalTouch) {
        guard !UIAccessibility.isVoiceOverRunning else { lastPhysicalTouch = nil; return }
        lastPhysicalTouch = touch
        guard hasStarted, let exercise,
              pendingSamples.count < exercise.expectedEntryIDs.count,
              let entry = manifest?.entry(id: exercise.expectedEntryIDs[pendingSamples.count]),
              entry.kind != .alternate, entry.kind != .behavior else { return }
        let output = QwertyCalibrationManifest.output(for: touch.key.kind, uppercase: page.uppercase)
        let actual = manifest?.entry(page: page, buttonIndex: touch.keyIndex)
        // A control can never become a supposed letter miss. Natural sequences use the raw
        // actions, and the aligner rejects insertions/omissions rather than shifting labels.
        if entry.kind == .character && actual?.kind != .character { invalidateAttempt(); return }
        if entry.kind == .control && actual?.id != entry.id { invalidateAttempt(); return }
        appendSample(entry: entry, location: touch.location, touchID: touch.touchID,
            timestamp: touch.timestamp, source: exercise.isNatural ? .naturalTap : (entry.kind == .control ? .control : .guidedTap), output: output)
    }

    private func appendSample(entry: QwertyCalibrationEntry, location: CGPoint, touchID: String,
                              timestamp: TimeInterval, source: QwertyCalibrationSample.Source, output: String) {
        guard keyboard.calibrationKeyFrames.indices.contains(entry.buttonIndex) else { return }
        let frame = keyboard.calibrationKeyFrames[entry.buttonIndex]
        pendingSamples.append(QwertyCalibrationSample(entryID: entry.id, touchID: touchID,
            x: Double(location.x), y: Double(location.y), keyMidX: Double(frame.midX), keyMidY: Double(frame.midY),
            keyWidth: Double(frame.width), keyHeight: Double(frame.height), timestamp: timestamp, source: source))
        observed.append(output)
        updateAttempt()
    }

    private func updateAttempt() {
        guard let exercise else { return }
        let rendered = exercise.isNatural ? observed.joined() : observed.map(readable).joined(separator: " · ")
        typedLabel.text = String(format: NSLocalizedString("Recorded: %@\n%d of %d touches", comment: "Calibration raw result"), rendered, pendingSamples.count, exercise.expectedEntryIDs.count)
        primaryButton.isEnabled = pendingSamples.count == exercise.expectedEntryIDs.count
        // Once the requested sample count is reached the exercise is frozen for review.
        keyboard.isUserInteractionEnabled = pendingSamples.count < exercise.expectedEntryIDs.count
    }

    private func invalidateAttempt() {
        pendingSamples.removeAll()
        observed.removeAll()
        updateAttempt()
        detailLabel.text = NSLocalizedString("That action made the intended sequence uncertain. This exercise has restarted; no taps from that attempt were saved.", comment: "Calibration ambiguous action")
    }

    @objc private func retry() {
        guard hasStarted else { confirmNewRun(); return }
        guard let exercise else { return }
        if exercise.isNatural {
            let alert = UIAlertController(title: NSLocalizedString("Try this sentence again?", comment: "Calibration retry title"), message: NSLocalizedString("Skipping gives no key credit. Every missing key will still appear in guided practice.", comment: "Calibration skip explanation"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: "Retry calibration"), style: .default) { [weak self] _ in self?.showNextExercise() })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Skip sentence", comment: "Skip natural calibration"), style: .default) { [weak self] _ in self?.session?.skipNaturalExercise(); self?.checkpoint(); self?.showNextExercise() })
            present(alert, animated: true)
        } else { showNextExercise() }
    }

    private func confirmNewRun() {
        let alert = UIAlertController(
            title: NSLocalizedString("Start over for this layout?", comment: "New calibration run confirmation"),
            message: NSLocalizedString("This replaces the unfinished exercise for the displayed layout. Completed runs and your active profile are kept.", comment: "New calibration run consequence"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel new calibration run"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Start new run", comment: "Confirm new calibration run"), style: .default) { [weak self] _ in
            guard let self else { return }
            self.keyboard.layoutIfNeeded()
            let manifest = QwertyCalibrationManifest.make(options: self.options, topStrip: self.topStrip,
                contextID: self.keyboard.calibrationGeometryContextID)
            let fresh = QwertyCalibrationSession(manifest: manifest)
            let snapshot = QwertyCalibrationStore.shared.load()
            self.primaryButton.isEnabled = false
            self.retryButton.isEnabled = false
            QwertyCalibrationStore.shared.startNew(fresh, expectedGeneration: snapshot.generation) { [weak self] result in
                guard let self else { return }
                self.primaryButton.isEnabled = true
                self.retryButton.isEnabled = true
                switch result {
                case .success(let saved):
                    self.generation = saved.generation
                    self.manifest = manifest
                    self.session = fresh
                    self.geometryID = manifest.contextID
                    self.hasStarted = true
                    self.globeSwitch.isEnabled = false
                    self.showNextExercise()
                case .failure:
                    self.showError(NSLocalizedString("A new run could not be started. Your previous run is still saved.", comment: "New calibration run failure"))
                }
            }
        })
        present(alert, animated: true)
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey) {
        defer { lastPhysicalTouch = nil }
        guard hasStarted, !UIAccessibility.isVoiceOverRunning, let exercise, !exercise.isNatural,
              let touch = lastPhysicalTouch, touch.key == key else { return }
        if key.kind == .shift {
            shift.shiftTapped(at: ProcessInfo.processInfo.systemUptime)
            keyboard.update(shiftState: shift.state)
            if let entry = manifest?.entry(id: exercise.expectedEntryIDs.first ?? ""),
               entry.kind == .behavior, entry.output == "capsLock", shift.state == .capsLock,
               pendingSamples.isEmpty, touch.keyIndex == entry.buttonIndex {
                appendSample(entry: entry, location: touch.location, touchID: touch.touchID,
                             timestamp: touch.timestamp, source: .behavior, output: "capsLock")
            }
        }
        // All other commands are controlled practice activations. In particular globe,
        // dismiss, pack, emoji and NumPad never dispatch their external host callbacks.
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCreate button: QwertyKeyButton, for key: QwertyKey) {
        switch key.kind {
        case .character, .space, .backspace:
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
            recognizer.minimumPressDuration = 0.45
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            recognizer.numberOfTouchesRequired = 1
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = true
            button.addGestureRecognizer(recognizer)
        default: break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        hasStarted && !UIAccessibility.isVoiceOverRunning && touch.type == .direct && touch.phase == .began
    }

    private var gestureBeganAt: TimeInterval = 0
    private var deleteTimer: Timer?
    private var practiceCharacters = 0
    private var deleteDidRepeat = false

    @objc private func longPress(_ recognizer: UILongPressGestureRecognizer) {
        guard !UIAccessibility.isVoiceOverRunning else {
            deleteTimer?.invalidate()
            keyboard.dismissAlternates()
            gestureStart = nil
            gestureTouchID = nil
            return
        }
        guard hasStarted, let exercise,
              let entry = manifest?.entry(id: exercise.expectedEntryIDs.first ?? ""),
              let button = recognizer.view as? QwertyKeyButton,
              keyboard.calibrationKeys.indices.contains(entry.buttonIndex),
              keyboard.calibrationKeys[entry.buttonIndex] == button.key,
              keyboard.calibrationKeyFrames.indices.contains(entry.buttonIndex),
              button.frame == keyboard.calibrationKeyFrames[entry.buttonIndex],
              pendingSamples.isEmpty,
              entry.kind == .alternate || entry.kind == .behavior else {
            if recognizer.state == .began { invalidateAttempt() }
            return
        }
        let location = recognizer.location(in: keyboard)
        switch recognizer.state {
        case .began:
            // Only an admitted live direct-touch recognizer can open a labeled gesture.
            guard recognizer.numberOfTouches == 1, recognizer.view?.window != nil else { return }
            gestureStart = location
            gestureTouchID = UUID().uuidString
            gestureBeganAt = ProcessInfo.processInfo.systemUptime
            if entry.kind == .alternate, case .character(let base, _) = button.key.kind {
                keyboard.showAlternates(QwertyAlternates.values(for: base, uppercase: page.uppercase), from: button)
            } else if entry.output == "deleteHold" {
                practiceCharacters = 8
                deleteDidRepeat = false
                deleteTimer?.invalidate()
                deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] timer in
                    guard let self, self.practiceCharacters > 0 else { timer.invalidate(); return }
                    self.practiceCharacters -= 1
                    self.deleteDidRepeat = true
                    self.typedLabel.text = String(repeating: "•", count: self.practiceCharacters)
                    if self.practiceCharacters == 0 { timer.invalidate() }
                }
            } else if entry.output == "cursorHold" {
                typedLabel.text = NSLocalizedString("Practice cursor: abc│def", comment: "Cursor hold practice")
            }
        case .changed:
            if entry.kind == .alternate { keyboard.updateAlternateHighlight(at: location) }
            else if entry.output == "cursorHold", let start = gestureStart, abs(location.x - start.x) >= 8 {
                typedLabel.text = location.x > start.x ? "abcdef│" : "│abcdef"
            }
        case .ended:
            deleteTimer?.invalidate()
            defer { gestureStart = nil; gestureTouchID = nil }
            guard let id = gestureTouchID else { return }
            let output: String?
            if entry.kind == .alternate {
                keyboard.updateAlternateHighlight(at: location)
                output = keyboard.releaseAlternate()
            } else if entry.output == "cursorHold", let start = gestureStart,
                      abs(location.x - start.x) >= 8 {
                output = "cursorHold"
            } else if entry.output == "deleteHold", deleteDidRepeat,
                      ProcessInfo.processInfo.systemUptime - gestureBeganAt >= 0.24 {
                output = "deleteHold"
            } else { output = nil }
            guard output == entry.output else {
                detailLabel.text = NSLocalizedString("That gesture did not complete the requested action. Try again; it was not counted.", comment: "Calibration gesture mismatch")
                return
            }
            appendSample(entry: entry, location: location, touchID: id,
                timestamp: ProcessInfo.processInfo.systemUptime,
                source: entry.kind == .alternate ? .alternate : .behavior, output: entry.output)
        case .cancelled, .failed:
            deleteTimer?.invalidate()
            keyboard.dismissAlternates()
            gestureStart = nil
            gestureTouchID = nil
        default: break
        }
    }

    @objc private func checkpoint() {
        deleteTimer?.invalidate()
        keyboard.dismissAlternates()
        gestureStart = nil
        gestureTouchID = nil
        guard let session else { return }
        QwertyCalibrationStore.shared.checkpoint(session, expectedGeneration: generation) { [weak self] result in
            if case .failure = result {
                self?.detailLabel.text = NSLocalizedString("This run could not be saved. Keep this screen open and try again before leaving.", comment: "Calibration checkpoint error")
            }
        }
    }

    private var generation = 0
    private var finishing = false

    private func finish() {
        guard let session, session.isComplete, !finishing else { return }
        finishing = true
        keyboard.isUserInteractionEnabled = false
        primaryButton.isEnabled = false
        retryButton.isHidden = true
        titleLabel.text = NSLocalizedString("Checking your calibration…", comment: "Calibration evaluation progress")
        promptLabel.text = nil
        let snapshot = QwertyCalibrationStore.shared.load()
        let previous = snapshot.activeProfiles[session.manifest.layoutFingerprint]
        let expectedGeneration = generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let run = QwertyCalibrationTrainer.finish(session: session, previous: previous)
            DispatchQueue.main.async {
                guard let self else { return }
                guard let run else {
                    self.finishing = false
                    self.hasStarted = false
                    self.showIntroduction()
                    self.showError(NSLocalizedString("This run could not be evaluated reliably. Start a new run for the displayed layout; completed history is kept.", comment: "Incomplete calibration evaluation"))
                    return
                }
                QwertyCalibrationStore.shared.saveRun(run, expectedGeneration: expectedGeneration) { [weak self] result in
                    guard let self else { return }
                    self.finishing = false
                    switch result {
                    case .success(let snapshot):
                        self.generation = snapshot.generation
                        self.session = nil
                        self.hasStarted = false
                        self.exercise = nil
                        self.titleLabel.text = run.validation.shouldActivate
                            ? NSLocalizedString("Calibration applied", comment: "Calibration success")
                            : NSLocalizedString("Run saved; previous typing profile retained", comment: "Calibration non-regression result")
                        self.detailLabel.text = run.validation.shouldActivate
                            ? NSLocalizedString("The candidate made fewer letter errors on fresh practice taps. Letter touch recognition is now personalized for this exact layout. Digits, symbols, and controls were practiced but retain default routing. Your visible keys stay in place.", comment: "Calibration activated explanation")
                            : NSLocalizedString("The candidate did not meet the improvement rule. Your existing profile stays active. This run is saved in History.", comment: "Calibration rejected explanation")
                        self.typedLabel.text = String(format: NSLocalizedString("Fresh taps: %d\nDefault errors: %d · Previous errors: %d · Candidate errors: %d", comment: "Calibration evaluation counts"), run.validation.sampleCount, run.validation.baselineErrors, run.validation.previousErrors, run.validation.candidateErrors)
                        self.primaryButton.setTitle(NSLocalizedString("Calibrate again", comment: "Recalibrate"), for: .normal)
                        self.primaryButton.isEnabled = true
                        self.globeSwitch.isEnabled = true
                        SettingsSync.post()
                    case .failure:
                        self.primaryButton.isEnabled = true
                        self.showError(NSLocalizedString("The completed run could not be saved. Try saving again.", comment: "Calibration run persistence error"))
                    }
                }
            }
        }
    }

    @objc private func showHistory() {
        let snapshot = QwertyCalibrationStore.shared.load()
        if snapshot.generation != generation, session != nil {
            session = nil
            exercise = nil
            hasStarted = false
            pendingSamples.removeAll()
            observed.removeAll()
            showIntroduction()
        }
        generation = snapshot.generation
        let alert = UIAlertController(title: NSLocalizedString("Calibration history", comment: "Calibration history title"), message: NSLocalizedString("Only validated profiles for the current layout can be restored. Reset deletes saved runs, partial exercises, and active calibration profiles.", comment: "Calibration history explanation"), preferredStyle: .actionSheet)
        let fingerprint = manifest?.layoutFingerprint ?? QwertyCalibrationManifest.make(options: options, topStrip: topStrip, contextID: keyboard.calibrationGeometryContextID).layoutFingerprint
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        for run in snapshot.runs.reversed() {
            let active = snapshot.activeProfiles[run.manifest.layoutFingerprint]?.id == run.profile.id
            let label = String(format: NSLocalizedString("%@ — %d/%d errors%@", comment: "Calibration history row"), dateFormatter.string(from: run.completedAt), run.validation.candidateErrors, run.validation.sampleCount, active ? NSLocalizedString(" (active)", comment: "Active calibration suffix") : "")
            let action = UIAlertAction(title: label, style: .default) { [weak self] _ in
                guard let self else { return }
                QwertyCalibrationStore.shared.restore(profileID: run.profile.id, layoutFingerprint: fingerprint, expectedGeneration: self.generation) { result in
                    switch result {
                    case .success(let snapshot): self.generation = snapshot.generation; SettingsSync.post()
                    case .failure: self.showError(NSLocalizedString("This profile could not be restored for the current layout.", comment: "Calibration restore failure"))
                    }
                }
            }
            action.isEnabled = run.manifest.layoutFingerprint == fingerprint && run.validation.shouldActivate && !active
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete all calibration data", comment: "Calibration reset action"), style: .destructive) { [weak self] _ in self?.confirmReset() })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel history"), style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(alert, animated: true)
    }

    private func confirmReset() {
        let alert = UIAlertController(title: NSLocalizedString("Delete all calibration data?", comment: "Calibration reset confirmation"), message: NSLocalizedString("NumPad will use its default touch recognition. This cannot be undone.", comment: "Calibration reset consequence"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel reset"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Confirm calibration reset"), style: .destructive) { [weak self] _ in
            QwertyCalibrationStore.shared.reset { result in
                guard let self else { return }
                switch result {
                case .success(let snapshot):
                    self.generation = snapshot.generation
                    self.session = nil
                    self.exercise = nil
                    self.hasStarted = false
                    self.pendingSamples.removeAll()
                    self.observed.removeAll()
                    self.showIntroduction()
                    SettingsSync.post()
                case .failure: self.showError(NSLocalizedString("Calibration data could not be deleted. Please try again.", comment: "Calibration reset error"))
                }
            }
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: NSLocalizedString("Calibration", comment: "Calibration error title"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Dismiss calibration message"), style: .default))
        present(alert, animated: true)
    }
}
