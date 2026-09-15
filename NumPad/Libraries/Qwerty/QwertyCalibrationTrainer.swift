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
    var shouldActivate: Bool {
        sampleCount >= 78 && distinctKeys >= 26 && distinctKeys <= sampleCount
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
        !manifest.entries.isEmpty && manifest.entries.allSatisfy { coverage[$0.id, default: 0] >= $0.minimumSamples }
    }
}

enum QwertyCalibrationTrainer {
    /// A completed run is saved even when validation declines activation. Raw traces remain
    /// in checkpoints only; the returned history item contains compact statistics/metrics.
    static func finish(session: QwertyCalibrationSession,
                       previous: QwertyCalibrationProfile?) -> QwertyCalibrationRun? {
        guard session.isComplete,
              QwertyCalibrationPage.allCases.allSatisfy({ session.geometry[$0.rawValue] != nil }),
              previous == nil || previous?.layoutFingerprint == session.manifest.layoutFingerprint else { return nil }
        var offsets: [String: QwertyCalibrationOffset] = [:]
        let groups = Dictionary(grouping: session.samples) { $0.entryID }
        for entry in session.manifest.entries where entry.trainsSpatialModel && entry.page == .letters
            && entry.row > 0 && entry.output.first?.isLetter == true {
            let accepted = (groups[entry.id] ?? []).filter {
                ($0.source == .naturalTap || $0.source == .guidedTap)
                    && $0.isValid && abs($0.dx) <= 0.75 && abs($0.dy) <= 0.75
            }
            guard accepted.count >= 5 else { continue }
            // Natural taps count twice as strongly as deliberately isolated taps. A weak
            // zero-centered prior avoids five examples moving a key aggressively.
            var weight = 12.0
            var sumX = 0.0
            var sumY = 0.0
            if let prior = previous?.offsets[entry.id], prior.count >= 5,
               prior.dx.isFinite, prior.dy.isFinite {
                // Fixed bounded prior; never merge historical cumulative sample counts.
                weight += 4; sumX += prior.dx * 4; sumY += prior.dy * 4
            }
            for sample in accepted {
                let importance = sample.source == .naturalTap ? 2.0 : 1.0
                weight += importance; sumX += sample.dx * importance; sumY += sample.dy * importance
            }
            offsets[entry.id] = .init(dx: max(-0.3, min(0.3, sumX / weight)),
                                      dy: max(-0.3, min(0.3, sumY / weight)), count: accepted.count)
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
                     protectedControlFailures: controlFailures)
    }
}
