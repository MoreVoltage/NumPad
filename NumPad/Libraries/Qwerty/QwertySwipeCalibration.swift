#if DEBUG && NUMPAD_PRIVATE_SWIPE
import Foundation
import CoreGraphics

/// Private swipe evidence is deliberately independent of tap-key personalization.
/// Only explicit acceptance of a supplied word counts its intended letters; crossing a
/// key is never evidence of intending that letter. Raw paths exist only in checkpoints.
enum QwertySwipeCalibration {
    static let alphabet = Array("abcdefghijklmnopqrstuvwxyz").map(String.init)
    static let distinctWordsPerLetter = 3
    static let trainingWords = ("quick quiet queen quartz quiver quilt extra exact exit example exercise " +
        "zebra zero zone puzzle frozen lazy jazz jump jacket enjoy joke major " +
        "vivid very voice river wave love brown bright blanket book better bubble " +
        "hello happy house help happy world would water winter word computer " +
        "swift swipe typing keyboard finger different morning school number people " +
        "purple yellow green orange music mother father summer little letter coffee " +
        "apple banana cherry daily dream friend garden night open table under").split(separator: " ").map(String.init)
    static let validationWords = ("quality question equal quote square squeeze maximum mix six next box fox " +
        "amazing size zoom prize buzz dozen journey juice join jelly adjust just " +
        "travel seven brave give view valley amount beach candle dinner early family " +
        "great hundred inside kitchen light money never often picture right small today").split(separator: " ").map(String.init)

    struct Sample: Codable {
        let word: String
        let path: [CGPoint]
        let durationSeconds: Double?
        let meanPitchSpeed: Double?
    }

    struct Coverage: Codable {
        private(set) var words: Set<String> = []
        mutating func accept(word: String) { words.insert(word) }
        func count(_ letter: String) -> Int { words.filter { $0.contains(letter) }.count }
        var missing: [String] { alphabet.filter { count($0) < distinctWordsPerLetter } }
        var complete: Bool { missing.isEmpty }
        var nextWord: String? {
            trainingWords.filter { !words.contains($0) }.max { a, b in
                let score: (String) -> Int = { word in
                    Set(word).reduce(0) { $0 + max(0, distinctWordsPerLetter - count(String($1))) }
                }
                return score(a) == score(b) ? a > b : score(a) < score(b)
            }
        }
    }

    struct Profile: Codable, Equatable {
        let id: UUID
        let contextID: String
        /// Endpoint bias in units of the minimum inter-key pitch, bounded to 0.35.
        let startX: Double
        let startY: Double
        let endX: Double
        let endY: Double
        let trainingWordCount: Int

        func corrected(path: [CGPoint], pitch: CGFloat) -> [CGPoint] {
            guard pitch > 0, path.count > 1 else { return path }
            let total = QwertyGlidePath.pathLength(path)
            guard total > 0 else { return path }
            var distance: CGFloat = 0
            return path.enumerated().map { index, point in
                if index > 0 { distance += QwertyGlidePath.distance(path[index - 1], point) }
                let t = distance / total
                let dx = CGFloat(startX) * (1 - t) + CGFloat(endX) * t
                let dy = CGFloat(startY) * (1 - t) + CGFloat(endY) * t
                return CGPoint(x: point.x - pitch * dx, y: point.y - pitch * dy)
            }
        }
    }

    struct Metrics: Codable {
        let words: Int
        let baselineTop1Errors: Int
        let baselineTop3Errors: Int
        let currentTop1Errors: Int
        let currentTop3Errors: Int
        let candidateTop1Errors: Int
        let candidateTop3Errors: Int
        let accepted: Bool
    }

    struct Run: Codable {
        let generation: Int
        let id: UUID
        let date: Date
        let contextID: String
        let tapRunID: UUID
        let candidate: Profile
        let coverage: Coverage
        let metrics: Metrics
    }

    struct Session: Codable {
        let generation: Int
        let id: UUID
        let contextID: String
        let tapRunID: UUID
        private(set) var coverage = Coverage()
        private(set) var training: [Sample] = []
        private(set) var heldOut: [Sample] = []
        var nextWord: String? {
            if !coverage.complete { return coverage.nextWord }
            let used = Set(heldOut.map(\.word))
            return validationWords.first { !used.contains($0) }
        }
        var complete: Bool { coverage.complete && heldOut.count == validationWords.count }

        init(contextID: String, tapRunID: UUID, generation: Int = 0) {
            id = UUID(); self.contextID = contextID; self.tapRunID = tapRunID
            self.generation = generation
        }

        /// The caller obtains explicit "I swiped this word" confirmation. Never call this
        /// just because the decoder happened to output the requested spelling.
        @discardableResult
        mutating func acceptConfirmedPath(_ path: [CGPoint], word: String,
                                          centers: [String: CGPoint], timestamps: [TimeInterval]? = nil) -> Bool {
            guard word == nextWord, Self.isPlausible(path: path, word: word, centers: centers) else { return false }
            var duration: Double?
            if let timestamps {
                guard timestamps.count == path.count, timestamps.allSatisfy({ $0.isFinite }),
                      zip(timestamps, timestamps.dropFirst()).allSatisfy({ pair in pair.0 < pair.1 }),
                      let first = timestamps.first, let last = timestamps.last, last > first else { return false }
                duration = last - first
            }
            let speed = duration.map { Double(QwertyGlidePath.pathLength(path) / QwertySwipeCalibration.pitch(centers)) / $0 }
            let sample = Sample(word: word, path: QwertyGlidePath.resample(path, to: 96),
                                durationSeconds: duration, meanPitchSpeed: speed)
            if coverage.complete { heldOut.append(sample) }
            else { training.append(sample); coverage.accept(word: word) }
            return true
        }

        static func isPlausible(path: [CGPoint], word: String, centers: [String: CGPoint]) -> Bool {
            let pitch = QwertySwipeCalibration.pitch(centers)
            let ideal = word.compactMap { centers[String($0)] }
            guard path.count >= 2, path.count <= 8192, pitch > 0,
                  path.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
                  ideal.count == word.count, let first = ideal.first, let last = ideal.last,
                  QwertyGlidePath.distance(path[0], first) <= pitch * 1.5,
                  QwertyGlidePath.distance(path[path.count - 1], last) <= pitch * 1.5 else { return false }
            let idealLength = QwertyGlidePath.pathLength(ideal)
            let length = QwertyGlidePath.pathLength(path)
            guard idealLength > 0, length / idealLength >= 0.4, length / idealLength <= 2.2 else { return false }
            // A broad shape gate excludes scribbles. It does not assert per-letter alignment
            // or train interior per-key positions (ambiguous for repeated letters).
            return QwertyGlidePath.channelDistance(
                QwertyGlidePath.normalized(QwertyGlidePath.resample(path)),
                QwertyGlidePath.normalized(QwertyGlidePath.resample(ideal))) < 0.45
        }

        func candidate(centers: [String: CGPoint]) -> Profile? {
            guard coverage.complete, training.count >= 20 else { return nil }
            let pitch = QwertySwipeCalibration.pitch(centers)
            guard pitch > 0 else { return nil }
            var starts: [CGPoint] = [], ends: [CGPoint] = []
            for sample in training {
                guard let firstLetter = sample.word.first, let lastLetter = sample.word.last,
                      let first = centers[String(firstLetter)], let last = centers[String(lastLetter)],
                      let actualFirst = sample.path.first, let actualLast = sample.path.last else { continue }
                starts.append(CGPoint(x: (actualFirst.x - first.x) / pitch, y: (actualFirst.y - first.y) / pitch))
                ends.append(CGPoint(x: (actualLast.x - last.x) / pitch, y: (actualLast.y - last.y) / pitch))
            }
            guard starts.count >= 20 else { return nil }
            // Median rejects isolated slips; shrinkage prevents overfitting short sessions.
            func offset(_ values: [CGFloat]) -> Double {
                let sorted = values.sorted()
                let median = sorted[sorted.count / 2]
                let weight = CGFloat(sorted.count) / CGFloat(sorted.count + 20)
                return Double(min(0.35, max(-0.35, median * weight)))
            }
            return Profile(id: id, contextID: contextID,
                startX: offset(starts.map(\.x)), startY: offset(starts.map(\.y)),
                endX: offset(ends.map(\.x)), endY: offset(ends.map(\.y)), trainingWordCount: starts.count)
        }

        func evaluate(centers: [String: CGPoint], decoder: QwertyGlideDecoder,
                      current: Profile?) -> Run? {
            guard complete, let candidate = candidate(centers: centers) else { return nil }
            // Training and held-out spellings are disjoint by construction and checked here.
            guard Set(training.map(\.word)).isDisjoint(with: Set(heldOut.map(\.word))) else { return nil }
            var baseline = [0, 0], previous = [0, 0], proposed = [0, 0]
            for sample in heldOut {
                func errors(_ profile: Profile?) -> [Int] {
                    let words = decoder.decode(path: sample.path, calibrationProfile: profile).map(\.word)
                    return [words.first == sample.word ? 0 : 1, words.contains(sample.word) ? 0 : 1]
                }
                let compatibleCurrent = current?.contextID == contextID ? current : nil
                let a = errors(nil), b = errors(compatibleCurrent), c = errors(candidate)
                for i in 0...1 { baseline[i] += a[i]; previous[i] += b[i]; proposed[i] += c[i] }
            }
            let accepted = heldOut.count >= 30 && proposed[0] < previous[0] && proposed[1] <= previous[1]
                && proposed[0] <= baseline[0] && proposed[1] <= baseline[1]
            let metrics = Metrics(words: heldOut.count, baselineTop1Errors: baseline[0], baselineTop3Errors: baseline[1],
                currentTop1Errors: previous[0], currentTop3Errors: previous[1],
                candidateTop1Errors: proposed[0], candidateTop3Errors: proposed[1], accepted: accepted)
            return Run(generation: generation, id: id, date: Date(), contextID: contextID, tapRunID: tapRunID,
                       candidate: candidate, coverage: coverage, metrics: metrics)
        }
    }

    static func pitch(_ centers: [String: CGPoint]) -> CGFloat {
        let points = Array(centers.values)
        var result = CGFloat.greatestFiniteMagnitude
        for i in points.indices {
            for j in points.indices where j > i {
                let distance = QwertyGlidePath.distance(points[i], points[j])
                if distance > 0 { result = min(result, distance) }
            }
        }
        return result == .greatestFiniteMagnitude ? 0 : result
    }
}

/// App-owned writes; the keyboard may read shared defaults without assuming shared write
/// permission. The host caches activeProfile outside gesture decoding. Never saves host text.
final class QwertySwipeCalibrationStore {
    private let defaults: UserDefaults
    private let key = "numpad.private-swipe.calibration.v1"
    private struct State: Codable {
        var generation = 0
        var runs: [QwertySwipeCalibration.Run] = []
        var active: [String: UUID] = [:]
        var checkpoint: QwertySwipeCalibration.Session?
    }
    init(defaults: UserDefaults = .group) { self.defaults = defaults }
    private func read() -> State {
        guard let data = defaults.data(forKey: key), data.count <= 4_000_000,
              let state = try? JSONDecoder().decode(State.self, from: data) else { return State() }
        return state
    }
    private func write(_ state: State) {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
    func activeProfile(contextID: String) -> QwertySwipeCalibration.Profile? {
        let state = read()
        return state.runs.last { $0.id == state.active[contextID] && $0.contextID == contextID && $0.metrics.accepted }?.candidate
    }
    func checkpoint(contextID: String, tapRunID: UUID) -> QwertySwipeCalibration.Session? {
        let checkpoint = read().checkpoint
        return checkpoint?.contextID == contextID && checkpoint?.tapRunID == tapRunID ? checkpoint : nil
    }
    var generation: Int { read().generation }
    @discardableResult
    func saveCheckpoint(_ session: QwertySwipeCalibration.Session) -> Bool {
        var state = read()
        guard session.generation == state.generation,
              !state.runs.contains(where: { $0.id == session.id }) else { return false }
        state.checkpoint = session; write(state); return true
    }
    @discardableResult
    func save(_ run: QwertySwipeCalibration.Run) -> Bool {
        var state = read()
        guard run.generation == state.generation else { return false }
        state.runs.removeAll { $0.id == run.id }; state.runs.append(run)
        if run.metrics.accepted { state.active[run.contextID] = run.id }
        state.checkpoint = nil // Completed runs never retain raw traces.
        write(state); SettingsSync.post(); return true
    }
    func runs(contextID: String) -> [QwertySwipeCalibration.Run] { read().runs.filter { $0.contextID == contextID } }
    func restore(runID: UUID, contextID: String) -> Bool {
        var state = read()
        guard state.runs.contains(where: { $0.id == runID && $0.contextID == contextID && $0.metrics.accepted }) else { return false }
        state.active[contextID] = runID; write(state); SettingsSync.post(); return true
    }
    func reset() {
        let nextGeneration = read().generation + 1
        var state = State(); state.generation = nextGeneration
        write(state); SettingsSync.post()
    }
}
#endif
