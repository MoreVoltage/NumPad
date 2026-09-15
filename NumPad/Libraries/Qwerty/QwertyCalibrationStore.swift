import Foundation

struct QwertyCalibrationSnapshot: Codable, Equatable {
    var version = 1
    var generation = 0
    var sessions: [String: QwertyCalibrationSession] = [:]
    var runs: [QwertyCalibrationRun] = []
    var activeProfiles: [String: QwertyCalibrationProfile] = [:]
    /// Optional for compatibility with pre-projection envelopes. Persisted before publication
    /// so a failed projection write can be retried without losing restore recency.
    var activeProfilePriority: [String]? = nil
}

/// One app-owned atomic envelope contains generation, checkpoints, history AND active
/// profiles. The keyboard reads a separate, size-bounded active-profile projection and never
/// decodes raw checkpoints or accumulated history. Full Access does not gate calibration.
/// All app mutations serialize on a process-wide queue, preventing delayed checkpoints
/// from resurrecting a reset. No disk IO belongs in keypress or layout callbacks.
final class QwertyCalibrationStore {
    enum StoreError: Error { case unavailable, readOnly, unsupportedVersion, corrupt, staleGeneration, staleSession, incompatibleRun }
    static let shared = QwertyCalibrationStore()
    private static let queue = DispatchQueue(label: "com.morevoltage.numpad.calibration.store", qos: .utility)
    private let fileURL: URL?
    private let writable: Bool
    private static let projectionByteLimit = 512 * 1_024
    private static let maximumProjectedProfiles = 16
    private var projectionURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent("qwerty-tap-active-v1.json")
    }
    private struct ActiveProjection: Codable {
        var version = 1
        let generation: Int
        /// A durable deletion fence: an older full envelope cannot restore reset data even
        /// if the app exits or its envelope write fails after the empty projection commits.
        let resetGeneration: Int
        let priority: [String]
        let profiles: [String: QwertyCalibrationProfile]
    }

    init(directoryURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserDefaults.appGroupIdentifier),
         writable: Bool = !Bundle.main.bundlePath.hasSuffix(".appex")) {
        fileURL = directoryURL?.appendingPathComponent("qwerty-tap-calibration-v1.json")
        self.writable = writable
    }

    /// Missing/corrupt/future-version files leave keyboard routing at its safe defaults.
    /// Writes fail closed for corrupt/future data; explicit reset can replace corrupt data.
    func load() -> QwertyCalibrationSnapshot {
        Self.queue.sync { (try? read()) ?? QwertyCalibrationSnapshot() }
    }

    /// Extension entry point. The read itself is capped before decoding; bounded profiles
    /// contain only at most 26 offsets each, never a manifest, history, or raw exercise trace.
    func loadActiveProfiles() -> [String: QwertyCalibrationProfile] {
        Self.queue.sync { (try? readProjection())?.profiles ?? [:] }
    }

    func checkpoint(_ session: QwertyCalibrationSession, expectedGeneration: Int,
                    completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void) {
        mutate(expectedGeneration: expectedGeneration, completion: completion) { state in
            let key = session.manifest.layoutFingerprint
            if let old = state.sessions[key] {
                guard old.id == session.id, old.manifest == session.manifest,
                      session.revision >= old.revision else { throw StoreError.staleSession }
            }
            guard !state.runs.contains(where: { $0.id == session.id }) else { throw StoreError.staleSession }
            state.sessions[key] = session
        }
    }

    /// Explicitly starting again is a separate operation so a stale autosave cannot replace
    /// an in-progress run. It also advances the reset generation to invalidate queued work.
    func startNew(_ session: QwertyCalibrationSession, expectedGeneration: Int,
                  completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void) {
        mutate(expectedGeneration: expectedGeneration, completion: completion) { state in
            state.generation += 1
            state.sessions[session.manifest.layoutFingerprint] = session
        }
    }

    func saveRun(_ run: QwertyCalibrationRun, expectedGeneration: Int,
                 completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void) {
        mutate(expectedGeneration: expectedGeneration, completion: completion) { state in
            let key = run.manifest.layoutFingerprint
            if let existing = state.runs.first(where: { $0.id == run.id }) {
                // The envelope may have committed before projection IO failed. Retrying the
                // same result republishes the projection without duplicating history.
                guard existing == run else { throw StoreError.incompatibleRun }
                return
            }
            guard run.hasFullCoverage, run.profile.layoutFingerprint == key,
                  run.profile.parentID == state.activeProfiles[key]?.id,
                  !state.runs.contains(where: { $0.id == run.id }),
                  state.sessions[key] == nil || state.sessions[key]?.id == run.id else {
                throw StoreError.incompatibleRun
            }
            state.runs.append(run)
            // Compact summaries of every completed run are retained, including unsuccessful
            // candidates. Raw traces are deleted with the completed checkpoint.
            state.sessions.removeValue(forKey: key)
            if run.validation.shouldActivate { state.activeProfiles[key] = run.profile }
        }
    }

    func restore(profileID: UUID, layoutFingerprint: String, expectedGeneration: Int,
                 completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void) {
        mutate(expectedGeneration: expectedGeneration, completion: completion) { state in
            guard let run = state.runs.first(where: {
                $0.profile.id == profileID && $0.manifest.layoutFingerprint == layoutFingerprint
                    && $0.hasFullCoverage && $0.validation.shouldActivate
            }) else { throw StoreError.incompatibleRun }
            state.activeProfiles[layoutFingerprint] = run.profile
            state.activeProfilePriority = [layoutFingerprint]
                + (state.activeProfilePriority ?? []).filter { $0 != layoutFingerprint }
            state.generation += 1 // in-flight training against the former parent is obsolete
        }
    }

    func reset(completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void) {
        Self.queue.async {
            let result: Result<QwertyCalibrationSnapshot, Error>
            do {
                guard self.writable else { throw StoreError.readOnly }
                // Refuse destructive downgrade of a future schema. Corrupt files can be
                // replaced only through this explicit user-invoked reset.
                let old: QwertyCalibrationSnapshot
                do { old = try self.read() }
                catch StoreError.corrupt {
                    var recovery = QwertyCalibrationSnapshot()
                    recovery.generation = Int(Date().timeIntervalSince1970 * 1_000_000)
                    old = recovery
                }
                // A future projection is never silently downgraded by this version.
                do { _ = try self.readProjection() } catch StoreError.corrupt { }
                var fresh = QwertyCalibrationSnapshot()
                fresh.generation = old.generation + 1
                let cleared = ActiveProjection(generation: fresh.generation,
                    resetGeneration: fresh.generation, priority: [], profiles: [:])
                // Reset differs from a normal commit: publish the deletion fence FIRST.
                // If the envelope write fails, reads still honor this reset permanently.
                try self.writeProjection(cleared)
                SettingsSync.post()
                try self.writeEnvelope(fresh)
                result = .success(fresh)
            } catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func mutate(expectedGeneration: Int,
                        completion: @escaping (Result<QwertyCalibrationSnapshot, Error>) -> Void,
                        change: @escaping (inout QwertyCalibrationSnapshot) throws -> Void) {
        Self.queue.async {
            let result: Result<QwertyCalibrationSnapshot, Error>
            do {
                guard self.writable else { throw StoreError.readOnly }
                var state = try self.read()
                guard state.generation == expectedGeneration else { throw StoreError.staleGeneration }
                let oldProfiles = state.activeProfiles
                let priorProjection = try self.readProjection()
                try change(&state)
                let changed = state.activeProfiles.keys.filter { oldProfiles[$0] != state.activeProfiles[$0] }
                let projection = self.makeProjection(state: state, prior: priorProjection, changed: changed)
                state.activeProfilePriority = projection.priority
                // A normal commit first saves durable history, then publishes its compact
                // active view atomically. A projection failure reports failure and leaves the
                // previous validated projection active; no half-written projection is read.
                try self.writeEnvelope(state)
                try self.writeProjection(projection)
                SettingsSync.post()
                result = .success(state)
            } catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func read() throws -> QwertyCalibrationSnapshot {
        guard let fileURL else { throw StoreError.unavailable }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return honoringReset(QwertyCalibrationSnapshot())
        }
        let data = try Data(contentsOf: fileURL)
        struct Probe: Decodable { let version: Int }
        guard let version = try? JSONDecoder().decode(Probe.self, from: data).version else { throw StoreError.corrupt }
        guard version == 1 else { throw StoreError.unsupportedVersion }
        guard let snapshot = try? JSONDecoder().decode(QwertyCalibrationSnapshot.self, from: data),
              snapshot.generation >= 0 else { throw StoreError.corrupt }
        // Active pointers are accepted only when backed by a complete, validated history
        // item, so a partially edited/corrupted pointer cannot turn adaptation on.
        for (key, profile) in snapshot.activeProfiles {
            guard profile.offsets.allSatisfy({ id, offset in
                offset.dx.isFinite && offset.dy.isFinite && abs(offset.dx) <= 0.3
                    && abs(offset.dy) <= 0.3 && offset.count >= 5
                    && snapshot.runs.contains(where: { run in
                        guard run.profile.id == profile.id,
                              let entry = run.manifest.entry(id: id) else { return false }
                        return entry.trainsSpatialModel && entry.page == .letters && entry.row > 0
                            && entry.output.first?.isLetter == true
                    })
            }) else { throw StoreError.corrupt }
            guard snapshot.runs.contains(where: {
                $0.profile == profile && $0.manifest.layoutFingerprint == key
                    && $0.hasFullCoverage && $0.validation.shouldActivate
            }) else { throw StoreError.corrupt }
        }
        return honoringReset(snapshot)
    }

    private func honoringReset(_ snapshot: QwertyCalibrationSnapshot) -> QwertyCalibrationSnapshot {
        guard let projection = try? readProjection(), projection.resetGeneration > snapshot.generation else { return snapshot }
        var empty = QwertyCalibrationSnapshot()
        empty.generation = projection.resetGeneration
        return empty
    }

    private func makeProjection(state: QwertyCalibrationSnapshot, prior: ActiveProjection?,
                                changed: [String]) -> ActiveProjection {
        // A restored older profile is promoted by the active change itself, independent of
        // its creation date. Routine checkpoints retain priority rather than rotating the cap.
        let candidates = changed.sorted()
            + (state.activeProfilePriority ?? prior?.priority ?? [])
            + state.activeProfiles.keys.sorted {
                state.activeProfiles[$0]!.createdAt > state.activeProfiles[$1]!.createdAt
            }
        var seen = Set<String>()
        let priority = Array(candidates.filter {
            state.activeProfiles[$0] != nil && seen.insert($0).inserted
        }.prefix(Self.maximumProjectedProfiles))
        let profiles = Dictionary(uniqueKeysWithValues: priority.map { ($0, state.activeProfiles[$0]!) })
        return ActiveProjection(generation: state.generation,
            resetGeneration: prior?.resetGeneration ?? 0, priority: priority, profiles: profiles)
    }

    private func readProjection() throws -> ActiveProjection? {
        guard let projectionURL else { throw StoreError.unavailable }
        guard FileManager.default.fileExists(atPath: projectionURL.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: projectionURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Self.projectionByteLimit + 1) ?? Data()
        guard data.count <= Self.projectionByteLimit else { throw StoreError.corrupt }
        struct Probe: Decodable { let version: Int }
        guard let version = try? JSONDecoder().decode(Probe.self, from: data).version else { throw StoreError.corrupt }
        guard version == 1 else { throw StoreError.unsupportedVersion }
        guard let projection = try? JSONDecoder().decode(ActiveProjection.self, from: data),
              projection.generation >= 0, projection.resetGeneration >= 0,
              projection.resetGeneration <= projection.generation,
              projection.profiles.count <= Self.maximumProjectedProfiles,
              projection.priority.count == projection.profiles.count,
              Set(projection.priority) == Set(projection.profiles.keys) else { throw StoreError.corrupt }
        for (fingerprint, profile) in projection.profiles {
            guard fingerprint == profile.layoutFingerprint, fingerprint.utf8.count <= 64,
                  profile.offsets.count <= 26,
                  profile.offsets.allSatisfy({ id, offset in
                      let parts = id.split(separator: ":")
                      guard parts.count == 3, parts[0] == "letters",
                            let row = Int(parts[1]), let column = Int(parts[2]) else { return false }
                      let isLetterPosition = (row == 1 && (0...9).contains(column))
                          || (row == 2 && (0...8).contains(column))
                          || (row == 3 && (1...7).contains(column))
                      return isLetterPosition && offset.count >= 5 && offset.dx.isFinite && offset.dy.isFinite
                          && abs(offset.dx) <= 0.3 && abs(offset.dy) <= 0.3
                  }) else { throw StoreError.corrupt }
        }
        return projection
    }

    private func writeProjection(_ projection: ActiveProjection) throws {
        guard let projectionURL else { throw StoreError.unavailable }
        let data = try JSONEncoder().encode(projection)
        guard data.count <= Self.projectionByteLimit else { throw StoreError.corrupt }
        try FileManager.default.createDirectory(at: projectionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: projectionURL, options: .atomic)
    }

    private func writeEnvelope(_ state: QwertyCalibrationSnapshot) throws {
        guard let fileURL else { throw StoreError.unavailable }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
