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

    var coveredKeyCount: Int { manifest.entries.filter { coverage[$0.id, default: 0] >= $0.minimumSamples }.count }
    var requiredKeyCount: Int { manifest.entries.count }
    var hasFullCoverage: Bool { !manifest.entries.isEmpty && coveredKeyCount == requiredKeyCount }
    var isComplete: Bool { hasFullCoverage && validationExercises.allSatisfy { completedExerciseIDs.contains($0.id) } }
    var nextExercise: QwertyCalibrationExercise? {
        if let natural = naturalExercises.first(where: { !completedExerciseIDs.contains($0.id) }) { return natural }
        if let missing = manifest.entries.first(where: { coverage[$0.id, default: 0] < $0.minimumSamples }) {
            let count = missing.minimumSamples - coverage[missing.id, default: 0]
            let label: String
            switch missing.kind {
            case .alternate: label = "Hold the highlighted key and select \(missing.output)."
            case .behavior: label = "Perform \(missing.output) on the highlighted key."
            case .control: label = "Activate \(Self.readable(missing.output)) \(count) times."
            case .character: label = "Type \(missing.output) \(count) times."
            }
            return .init(id: "guided:\(missing.id):\(coverage[missing.id, default: 0])",
                         instruction: label, expectedEntryIDs: Array(repeating: missing.id, count: count),
                         page: missing.page, text: missing.output, isValidation: false, isNatural: false)
        }
        return validationExercises.first { !completedExerciseIDs.contains($0.id) }
    }

    /// Call only after a user's explicit review of this prompted exercise. observedOutputs
    /// are raw key actions before autocorrect/transforms. They only detect ambiguous natural
    /// alignment; they NEVER become the training labels. Guided single-key exercises may
    /// accept a neighboring character hit after review, but controls/menus must match exactly.
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
            for sample in newSamples { coverage[sample.entryID, default: 0] += 1 }
        }
        completedExerciseIDs.insert(exercise.id)
        revision += 1
        return true
    }

    /// Optional natural practice can be skipped after an ambiguous attempt. It never grants
    /// coverage: the guided queue still demands every missing sample on every key.
    mutating func skipNaturalExercise() {
        guard let exercise = nextExercise, exercise.isNatural, !exercise.isValidation else { return }
        completedExerciseIDs.insert(exercise.id); revision += 1
    }

    private mutating func reject() -> Bool { rejectedExercises += 1; revision += 1; return false }

    private var naturalExercises: [QwertyCalibrationExercise] {
        ["the quick brown fox jumps over the lazy dog",
         "pack my box with five dozen liquor jugs",
         "we enjoy quiet walks and fresh ripe berries"].enumerated().compactMap {
            phrase($0.element, id: "natural:\($0.offset)", validation: false)
        }
    }
    private var validationExercises: [QwertyCalibrationExercise] {
        // An isolated, explicitly confirmed intended letter remains known even if baseline
        // routing chooses its neighbor. These are held out; never fed to training/coverage.
        "mqpazwsxnedcrfvtgbyhujikol".enumerated().compactMap { index, letter in
            guard let entry = manifest.entries.first(where: {
                $0.page == .letters && $0.row > 0 && $0.parentID == nil && $0.output == String(letter)
            }) else { return nil }
            return .init(id: "validation:\(index)", instruction: "Validation: tap \(letter) three times naturally.",
                         expectedEntryIDs: Array(repeating: entry.id, count: 3), page: .letters,
                         text: String(letter), isValidation: true, isNatural: false)
        }
    }
    /// Geometry must come from the actual renderer; a changed frame invalidates a run rather
    /// than silently mixing layouts. Capture all pages before their first exercise.
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
    private func phrase(_ text: String, id: String, validation: Bool) -> QwertyCalibrationExercise? {
        let ids = text.map { character in
            manifest.entries.first { $0.page == .letters && $0.row > 0 && $0.parentID == nil && $0.output == String(character) }?.id
        }
        guard ids.allSatisfy({ $0 != nil }) else { return nil }
        return .init(id: id, instruction: "Type the sentence exactly. Review before saving.",
                     expectedEntryIDs: ids.compactMap { $0 }, page: .letters,
                     text: text, isValidation: validation, isNatural: true)
    }
    private static func readable(_ output: String) -> String {
        if output == " " { return "Space" }; if output == "\n" { return "Return" }; return output
    }
}

struct QwertyCalibrationGeometry: Codable, Equatable {
    let frames: [CGRect]
    let bounds: CGRect
}
