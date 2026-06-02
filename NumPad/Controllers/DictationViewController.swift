//
//  DictationViewController.swift
//  NumPad
//
//  Numbers-only dictation for the container app.
//
//  A custom keyboard extension cannot access the microphone, so dictation is delegated here:
//  the keyboard deep-links to `numpad://dictate`, this screen records audio, transcribes it
//  fully on-device with WhisperKit, converts the result to digits via `SpokenNumberParser`
//  (so only numerals are ever produced), hands the result back to the keyboard through
//  `DictationBridge`, and asks the user to switch back (iOS cannot auto-return to the host app).
//
//  WhisperKit downloads a small (~40 MB) on-device model on first use; everything stays on device.
//

import UIKit
import AVFoundation
import WhisperKit

// WhisperKit requires iOS 16+, while the app deploys to iOS 14. The whole screen is gated so
// the rest of the app keeps its iOS 14 support; callers must guard with `if #available(iOS 16, *)`.
@available(iOS 16.0, *)
final class DictationViewController: UIViewController {

    private let statusLabel = UILabel()
    private let transcriptLabel = UILabel()
    private let numeralLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let insertButton = UIButton(type: .system)

    private var whisperKit: WhisperKit?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false
    private var lastNumerals = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Dictate a number", comment: "Dictation screen title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        configureViews()
        prepare()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRecording()
    }

    private func configureViews() {
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        transcriptLabel.font = .preferredFont(forTextStyle: .title3)
        transcriptLabel.textColor = .label
        transcriptLabel.textAlignment = .center
        transcriptLabel.numberOfLines = 0

        numeralLabel.font = .monospacedSystemFont(ofSize: 40, weight: .bold)
        numeralLabel.textColor = .systemBlue
        numeralLabel.textAlignment = .center
        numeralLabel.numberOfLines = 0

        recordButton.setTitle(NSLocalizedString("Record", comment: ""), for: .normal)
        recordButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        recordButton.isEnabled = false

        insertButton.setTitle(NSLocalizedString("Use this", comment: ""), for: .normal)
        insertButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        insertButton.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)
        insertButton.isEnabled = false

        let stack = UIStackView(arrangedSubviews: [statusLabel, transcriptLabel, numeralLabel, recordButton, insertButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Model

    private func prepare() {
        statusLabel.text = NSLocalizedString("Preparing… (first use downloads a small speech model)", comment: "")
        Task { await loadModel() }
    }

    @MainActor
    private func loadModel() async {
        do {
            // tiny.en is fast and more than enough for digits; downloaded once and cached on device.
            let kit = try await WhisperKit(WhisperKitConfig(model: "tiny.en"))
            whisperKit = kit
            statusLabel.text = NSLocalizedString("Tap Record and say a number.", comment: "")
            recordButton.isEnabled = true
        } catch {
            statusLabel.text = String(format: NSLocalizedString("Couldn't load the speech model: %@", comment: ""), error.localizedDescription)
        }
    }

    // MARK: - Recording

    @objc private func recordTapped() {
        if isRecording {
            stopRecording()
            if let url = recordingURL {
                Task { await transcribe(url) }
            }
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let onPermission: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard granted else {
                    self.statusLabel.text = NSLocalizedString("Microphone permission denied. Enable it in Settings.", comment: "")
                    return
                }
                self.beginRecording()
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: onPermission)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(onPermission)
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("numpad-dictation.wav")
        recordingURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            audioRecorder = recorder
            isRecording = true
            recordButton.setTitle(NSLocalizedString("Stop", comment: ""), for: .normal)
            statusLabel.text = NSLocalizedString("Listening… say a number, then tap Stop.", comment: "")
        } catch {
            statusLabel.text = String(format: NSLocalizedString("Couldn't start recording: %@", comment: ""), error.localizedDescription)
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordButton.setTitle(NSLocalizedString("Record", comment: ""), for: .normal)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Transcription

    @MainActor
    private func transcribe(_ url: URL) async {
        guard let kit = whisperKit else { return }
        statusLabel.text = NSLocalizedString("Transcribing…", comment: "")
        recordButton.isEnabled = false
        do {
            let results = try await kit.transcribe(audioPath: url.path)
            let raw = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let numerals = SpokenNumberParser.parse(raw)
            transcriptLabel.text = raw.isEmpty ? nil : "“\(raw)”"
            numeralLabel.text = numerals
            lastNumerals = numerals
            insertButton.isEnabled = !numerals.isEmpty
            statusLabel.text = numerals.isEmpty
                ? NSLocalizedString("No number recognized. Tap Record to try again.", comment: "")
                : NSLocalizedString("Tap “Use this” to send it to the keyboard.", comment: "")
        } catch {
            statusLabel.text = String(format: NSLocalizedString("Transcription failed: %@", comment: ""), error.localizedDescription)
        }
        recordButton.isEnabled = true
    }

    // MARK: - Actions

    @objc private func insertTapped() {
        guard !lastNumerals.isEmpty else { return }
        DictationBridge.send(lastNumerals)
        statusLabel.text = String(format: NSLocalizedString("Sent “%@”. Return to your app — it will appear where the cursor is.", comment: ""), lastNumerals)
        insertButton.isEnabled = false
    }

    @objc private func cancelTapped() {
        stopRecording()
        dismiss(animated: true)
    }
}

// MARK: - Spoken number parser
//
// Converts an English transcript into the numeric/symbol string a numpad would produce.
// Handles cardinals up to the millions ("one hundred twenty three" -> "123") plus a handful
// of keypad symbols ("point" -> ".", "percent" -> "%"). WhisperKit often emits digits directly,
// which are passed through unchanged; spelled-out forms are converted here.
enum SpokenNumberParser {

    private static let units: [String: Int] = [
        "zero": 0, "oh": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
        "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16,
        "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    private static let symbols: [String: String] = [
        "point": ".", "dot": ".", "decimal": ".", "comma": ",",
        "plus": "+", "minus": "-", "dash": "-", "times": "*", "star": "*",
        "slash": "/", "percent": "%", "equals": "=", "equal": "=",
        "dollar": "$", "dollars": "$", "euro": "€", "euros": "€",
        "pound": "£", "pounds": "£", "hash": "#", "hashtag": "#"
    ]

    static func parse(_ transcript: String) -> String {
        let tokens = transcript.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var out = ""
        var buffer: [String] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            if let n = numberFromWords(buffer) {
                out += String(n)
            }
            buffer.removeAll()
        }

        for token in tokens {
            if token == "and" {
                continue // number connector, e.g. "one hundred and five"
            } else if isNumberWord(token) {
                buffer.append(token)
            } else if let digits = Int(token) {
                flush(); out += String(digits)
            } else if let symbol = symbols[token] {
                flush(); out += symbol
            } else {
                flush() // drop non-number words (numpad only cares about numbers/symbols)
            }
        }
        flush()
        return out
    }

    private static func isNumberWord(_ token: String) -> Bool {
        return units[token] != nil || tens[token] != nil
            || token == "hundred" || token == "thousand" || token == "million"
    }

    private static func numberFromWords(_ words: [String]) -> Int? {
        var result = 0      // accumulates thousands/millions groups
        var current = 0     // current group being built
        var used = false
        for w in words {
            if let u = units[w] {
                current += u; used = true
            } else if let t = tens[w] {
                current += t; used = true
            } else if w == "hundred" {
                current = max(current, 1) * 100; used = true
            } else if w == "thousand" {
                result += max(current, 1) * 1000; current = 0; used = true
            } else if w == "million" {
                result += max(current, 1) * 1_000_000; current = 0; used = true
            } else {
                return nil
            }
        }
        return used ? result + current : nil
    }
}
