import Foundation
import CoreGraphics

struct QwertyCalibrationSample: Codable, Equatable {
    enum Source: String, Codable { case naturalTap, guidedTap, alternate, control, behavior }
    let entryID: String
    let touchID: String
    let x: Double
    let y: Double
    let keyMidX: Double
    let keyMidY: Double
    let keyWidth: Double
    let keyHeight: Double
    let timestamp: TimeInterval
    let source: Source
    var dx: Double { (x - keyMidX) / keyWidth }
    var dy: Double { (y - keyMidY) / keyHeight }
    var isValid: Bool {
        !touchID.isEmpty && [x, y, keyMidX, keyMidY, keyWidth, keyHeight, timestamp].allSatisfy { $0.isFinite }
            && keyWidth > 0 && keyHeight > 0
    }
}

struct QwertyCalibrationExercise: Codable, Equatable {
    let id: String
    let instruction: String
    let expectedEntryIDs: [String]
    let page: QwertyCalibrationPage
    let text: String
    let isValidation: Bool
    let isNatural: Bool
    var uppercase: Bool { page.uppercase }
}

/// Conservative first alignment policy: accept only exact, unrevised natural sequences.
/// An omission, insertion, extra touch, or repeated character rejects the whole short phrase;
/// isolated guided targets then provide independent intent, including boundary errors.
enum QwertyCalibrationAligner {
    static func exact(expected: [String], observed: [String], touchCount: Int) -> Bool {
        expected == observed && touchCount == expected.count
    }
}

struct QwertyCalibrationSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let manifest: QwertyCalibrationManifest
    private(set) var coverage: [String: Int] = [:]
    private(set) var samples: [QwertyCalibrationSample] = []
    private(set) var validationSamples: [QwertyCalibrationSample] = []
    private(set) var completedExerciseIDs: Set<String> = []
    private(set) var geometry: [String: QwertyCalibrationGeometry] = [:]
    private(set) var revision: Int = 0
    private(set) var rejectedExercises: Int = 0

    init(manifest: QwertyCalibrationManifest) {
        id = UUID(); startedAt = Date(); self.manifest = manifest
    }

    var coveredKeyCount: Int {
        manifest.requiredEntries.filter { coverage[$0.id, default: 0] >= $0.minimumSamples }.count
    }
    var requiredKeyCount: Int { manifest.requiredEntries.count }
    var hasFullCoverage: Bool { requiredKeyCount == 26 && coveredKeyCount == requiredKeyCount }
    var isComplete: Bool {
        hasFullCoverage && exercises.count == 2 && exercises.allSatisfy { completedExerciseIDs.contains($0.id) }
    }
    var nextExercise: QwertyCalibrationExercise? {
        exercises.first { !completedExerciseIDs.contains($0.id) }
    }

    /// Call only after a user's explicit review of this prompted exercise. observedOutputs
    /// are raw key actions before autocorrect/transforms. They only detect ambiguous natural
    /// alignment; they NEVER become the training labels. Guided sequences may accept a
    /// neighboring character hit after review; each label is the next prompted letter.
    @discardableResult
    mutating func recordConfirmedExercise(exerciseID: String,
                                         samples newSamples: [QwertyCalibrationSample],
                                         observedOutputs: [String], userConfirmed: Bool) -> Bool {
        guard userConfirmed, let exercise = nextExercise, exercise.id == exerciseID,
              newSamples.count == exercise.expectedEntryIDs.count,
              observedOutputs.count == newSamples.count else { return reject() }
        let expected = exercise.expectedEntryIDs.compactMap { manifest.entry(id: $0)?.output }
        guard expected.count == exercise.expectedEntryIDs.count else { return reject() }
        let identities = newSamples.map(\.touchID)
        let previous = Set((samples + validationSamples).map(\.touchID))
        guard Set(identities).count == identities.count,
              previous.isDisjoint(with: identities) else { return reject() }
        if exercise.isNatural {
            guard QwertyCalibrationAligner.exact(expected: expected, observed: observedOutputs,
                                                 touchCount: newSamples.count) else { return reject() }
        }
        for (index, sample) in newSamples.enumerated() {
            guard sample.isValid, sample.entryID == exercise.expectedEntryIDs[index],
                  let entry = manifest.entry(id: sample.entryID),
                  let pageGeometry = geometry[entry.page.rawValue],
                  pageGeometry.frames.indices.contains(entry.buttonIndex) else { return reject() }
            let frame = pageGeometry.frames[entry.buttonIndex]
            // Labels refer to the prompted key's actual frame, never the routed neighbor.
            guard abs(sample.keyMidX - Double(frame.midX)) < 0.01,
                  abs(sample.keyMidY - Double(frame.midY)) < 0.01,
                  abs(sample.keyWidth - Double(frame.width)) < 0.01,
                  abs(sample.keyHeight - Double(frame.height)) < 0.01 else { return reject() }
            switch entry.kind {
            case .character:
                guard sample.source == (exercise.isNatural ? .naturalTap : .guidedTap),
                      abs(sample.dx) <= 1.25, abs(sample.dy) <= 1.25 else { return reject() }
            case .alternate:
                guard sample.source == .alternate, observedOutputs[index] == entry.output else { return reject() }
            case .control:
                guard (sample.source == .control || (exercise.isNatural && entry.output == " " && sample.source == .naturalTap)),
                      observedOutputs[index] == entry.output else { return reject() }
            case .behavior:
                guard sample.source == .behavior, observedOutputs[index] == entry.output else { return reject() }
            }
        }
        if exercise.isValidation {
            validationSamples += newSamples
        } else {
            samples += newSamples
        }
        // Held-out taps complete physical-key coverage but never enter training samples.
        for sample in newSamples { coverage[sample.entryID, default: 0] += 1 }
        completedExerciseIDs.insert(exercise.id)
        revision += 1
        return true
    }

    /// Retained for older callers/checkpoints. Quick calibration has no optional drills.
    mutating func skipNaturalExercise() {}

    private mutating func reject() -> Bool { rejectedExercises += 1; revision += 1; return false }

    private var exercises: [QwertyCalibrationExercise] {
        let heldOut = Set("rfjn".map(String.init))
        let required = manifest.requiredEntries
        guard required.count == 26, Set(required.map(\.output)) == Set("abcdefghijklmnopqrstuvwxyz".map(String.init)) else { return [] }
        let training = required.filter { !heldOut.contains($0.output) }
        let validation = "rfjn".compactMap { letter in required.first { $0.output == String(letter) } }
        return [
            .init(id: "quick-v2:training", instruction: "Tap each highlighted letter once, then confirm.",
                  expectedEntryIDs: training.map(\.id), page: .letters,
                  text: training.map(\.output).joined(), isValidation: false, isNatural: false),
            .init(id: "quick-v2:validation", instruction: "Tap the last four highlighted letters, then confirm.",
                  expectedEntryIDs: validation.map(\.id), page: .letters,
                  text: validation.map(\.output).joined(), isValidation: true, isNatural: false)
        ]
    }
    /// Geometry must come from the actual renderer; a changed frame invalidates a run rather
    /// than silently mixing layouts. Only the letters page is needed for quick calibration.
    @discardableResult
    mutating func recordGeometry(page: QwertyCalibrationPage, frames: [CGRect], bounds: CGRect) -> Bool {
        let entries = manifest.entries.filter { $0.page == page && $0.parentID == nil }
        guard frames.count == entries.count, bounds.width > 0, bounds.height > 0,
              frames.allSatisfy({ $0.width > 0 && $0.height > 0 && !$0.isInfinite && !$0.isNull }) else { return false }
        let value = QwertyCalibrationGeometry(frames: frames, bounds: bounds)
        if let previous = geometry[page.rawValue] { return previous == value }
        geometry[page.rawValue] = value
        revision += 1
        return true
    }

}

struct QwertyCalibrationGeometry: Codable, Equatable {
    let frames: [CGRect]
    let bounds: CGRect
}
