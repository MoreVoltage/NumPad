import Foundation
import CoreGraphics

struct QwertyCalibrationOffset: Codable, Equatable {
    let dx: Double
    let dy: Double
    let count: Int
}

struct QwertyCalibrationProfile: Codable, Equatable {
    let id: UUID
    let layoutFingerprint: String
    let createdAt: Date
    let parentID: UUID?
    let offsets: [String: QwertyCalibrationOffset]

    func indexedOffsets(manifest: QwertyCalibrationManifest,
                        page: QwertyCalibrationPage, frames: [CGRect]) -> [Int: CGVector] {
        guard manifest.layoutFingerprint == layoutFingerprint else { return [:] }
        var result: [Int: CGVector] = [:]
        for entry in manifest.entries where entry.page == page && entry.trainsSpatialModel {
            guard let offset = offsets[entry.id], offset.count >= 5,
                  offset.dx.isFinite, offset.dy.isFinite, frames.indices.contains(entry.buttonIndex) else { continue }
            let frame = frames[entry.buttonIndex]
            result[entry.buttonIndex] = CGVector(dx: CGFloat(max(-0.3, min(0.3, offset.dx))) * frame.width,
                                                dy: CGFloat(max(-0.3, min(0.3, offset.dy))) * frame.height)
        }
        return result
    }
}

struct QwertyCalibrationValidation: Codable, Equatable {
    let sampleCount: Int
    let distinctKeys: Int
    let baselineErrors: Int
    let previousErrors: Int
    let candidateErrors: Int
    let protectedControlFailures: Int
    /// Absent in saved full-calibration histories; preserve their original activation rule.
    var policyVersion: Int? = nil
    var shouldActivate: Bool {
        if let policyVersion {
            guard policyVersion == 2 else { return false }
            return sampleCount >= 4 && distinctKeys >= 4 && distinctKeys <= sampleCount
                && baselineErrors >= 2 && baselineErrors <= sampleCount
                && previousErrors >= 2 && previousErrors <= sampleCount
                && candidateErrors == 0 && protectedControlFailures == 0
        }
        return sampleCount >= 78 && distinctKeys >= 26 && distinctKeys <= sampleCount
            && baselineErrors >= 0 && baselineErrors <= sampleCount
            && previousErrors >= 0 && previousErrors <= sampleCount
            && candidateErrors >= 0 && candidateErrors <= sampleCount
            && candidateErrors < baselineErrors
            && candidateErrors < previousErrors && protectedControlFailures == 0
    }
}

struct QwertyCalibrationRun: Codable, Equatable {
    let id: UUID
    let completedAt: Date
    let manifest: QwertyCalibrationManifest
    let coverage: [String: Int]
    let profile: QwertyCalibrationProfile
    let validation: QwertyCalibrationValidation
    let rejectedExercises: Int
    var hasFullCoverage: Bool {
        guard let policy = validation.policyVersion else {
            return !manifest.entries.isEmpty
                && manifest.entries.allSatisfy { coverage[$0.id, default: 0] >= $0.minimumSamples }
        }
        return policy == 2 && manifest.requiredEntries.count == 26
            && manifest.requiredEntries.allSatisfy { coverage[$0.id, default: 0] >= $0.minimumSamples }
    }
}

enum QwertyCalibrationTrainer {
    /// A completed run is saved even when validation declines activation. Raw traces remain
    /// in checkpoints only; the returned history item contains compact statistics/metrics.
    static func finish(session: QwertyCalibrationSession,
                       previous: QwertyCalibrationProfile?) -> QwertyCalibrationRun? {
        guard session.isComplete,
              session.geometry[QwertyCalibrationPage.letters.rawValue] != nil,
              previous == nil || previous?.layoutFingerprint == session.manifest.layoutFingerprint else { return nil }
        let required = session.manifest.requiredEntries
        let requiredIDs = Set(required.map(\.id))
        let heldOutIDs = Set(session.validationSamples.map(\.entryID))
        let accepted = session.samples.filter {
            requiredIDs.contains($0.entryID) && !heldOutIDs.contains($0.entryID)
                && $0.source == .guidedTap && $0.isValid
                && abs($0.dx) <= 0.75 && abs($0.dy) <= 0.75
        }
        var offsets: [String: QwertyCalibrationOffset] = [:]
        // One tap per key supports a shared keyboard bias, not a per-key typing model.
        // All 22 independent training taps must be plausible before learning that bias.
        if accepted.count == 22 && Set(accepted.map(\.entryID)).count == 22 {
            var weight = 12.0 + Double(accepted.count)
            var sumX = accepted.reduce(0.0) { $0 + $1.dx }
            var sumY = accepted.reduce(0.0) { $0 + $1.dy }
            let prior = required.compactMap { previous?.offsets[$0.id] }.filter {
                $0.count >= 5 && $0.dx.isFinite && $0.dy.isFinite
            }
            if !prior.isEmpty {
                weight += 4
                sumX += prior.reduce(0.0) { $0 + max(-0.3, min(0.3, $1.dx)) } / Double(prior.count) * 4
                sumY += prior.reduce(0.0) { $0 + max(-0.3, min(0.3, $1.dy)) } / Double(prior.count) * 4
            }
            let pooled = QwertyCalibrationOffset(dx: max(-0.3, min(0.3, sumX / weight)),
                dy: max(-0.3, min(0.3, sumY / weight)), count: accepted.count)
            for entry in required { offsets[entry.id] = pooled }
        }
        let profile = QwertyCalibrationProfile(id: UUID(), layoutFingerprint: session.manifest.layoutFingerprint,
                                               createdAt: Date(), parentID: previous?.id, offsets: offsets)
        guard let validation = evaluate(session: session, previous: previous, candidate: profile) else { return nil }
        return .init(id: session.id, completedAt: Date(), manifest: session.manifest,
                     coverage: session.coverage, profile: profile, validation: validation,
                     rejectedExercises: session.rejectedExercises)
    }

    static func evaluate(session: QwertyCalibrationSession, previous: QwertyCalibrationProfile?,
                         candidate: QwertyCalibrationProfile) -> QwertyCalibrationValidation? {
        var baselineErrors = 0, previousErrors = 0, candidateErrors = 0, controlFailures = 0
        var evaluated = 0
        var distinct = Set<String>()
        for sample in session.validationSamples {
            guard let entry = session.manifest.entry(id: sample.entryID), entry.trainsSpatialModel,
                  let geometry = session.geometry[entry.page.rawValue], sample.isValid else { return nil }
            let indices = Set(session.manifest.entries.filter {
                $0.page == entry.page && $0.trainsSpatialModel
            }.map(\.buttonIndex))
            let point = CGPoint(x: sample.x, y: sample.y)
            let baseline = QwertyTouchRouting.calibratedKeyIndex(at: point, keyFrames: geometry.frames,
                in: geometry.bounds, characterIndices: indices, offsets: [:])
            let old = QwertyTouchRouting.calibratedKeyIndex(at: point, keyFrames: geometry.frames,
                in: geometry.bounds, characterIndices: indices,
                offsets: previous?.indexedOffsets(manifest: session.manifest, page: entry.page, frames: geometry.frames) ?? [:])
            let new = QwertyTouchRouting.calibratedKeyIndex(at: point, keyFrames: geometry.frames,
                in: geometry.bounds, characterIndices: indices,
                offsets: candidate.indexedOffsets(manifest: session.manifest, page: entry.page, frames: geometry.frames))
            baselineErrors += baseline == entry.buttonIndex ? 0 : 1
            previousErrors += old == entry.buttonIndex ? 0 : 1
            candidateErrors += new == entry.buttonIndex ? 0 : 1
            if let new, !indices.contains(new), new != baseline { controlFailures += 1 }
            evaluated += 1; distinct.insert(entry.id)
        }
        return .init(sampleCount: evaluated, distinctKeys: distinct.count, baselineErrors: baselineErrors,
                     previousErrors: previousErrors, candidateErrors: candidateErrors,
                     protectedControlFailures: controlFailures, policyVersion: 2)
    }
}
