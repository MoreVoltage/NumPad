import Foundation

/// The per-user learned touch-offset store behind NumPad Type's per-key tap personalization
/// (design doc docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §3, the
/// mean-offset half of arXiv:2209.11311): for each letter key, an exponential moving average
/// of where the user's accepted taps land relative to the key's center, in key-size-normalized
/// units (dx = (x − midX) / width, dy = (y − midY) / height) so the learned bias survives
/// rotations, height presets, and layout changes. Pure value type — capture, the acceptance
/// proxy, persistence triggers, and view-space denormalization live at the edge
/// (`QwertyPageHost`/`QwertyKeyboardView`).
///
/// PRIVACY (design §2/§3 posture, same as `QwertyPersonalDictionary`): contents never leave
/// the app group — no SettingsSync broadcast on writes, no analytics reads, no export path.
/// The container app only ever *clears* it (Reset Typing Personalization in the NumPad Type
/// wizard, which brackets both stores with the shared odd/even epoch).
struct QwertyTouchPersonalization: Codable, Equatable {

    /// One key's running state: the EMA offset plus how many accepted taps have fed it
    /// (`samples` gates the warmup — see `offset(forKeyCharacter:)`).
    struct Offset: Codable, Equatable {
        var dx: Double
        var dy: Double
        var samples: Int
    }

    /// Keyed by the folded (lowercased) base character — layout-independent, so "A" and "a"
    /// are one physical key.
    private(set) var offsets: [String: Offset] = [:]

    /// EMA alpha: each accepted tap moves the stored offset 20% toward the new sample, so
    /// the model tracks a drifting grip without one stray tap yanking it around.
    static let smoothing = 0.2
    /// No output until a key has this many samples — fresh users (and fresh keys) get
    /// byte-for-byte unchanged routing until a habit is actually established.
    static let warmupSamples = 5
    /// Normalized offsets are clamped into ±1 key-size per axis: a gap-routed tap can
    /// legitimately land outside the key frame (beyond ±0.5), but a full key-size away is
    /// junk input, not a habit.
    static let offsetLimit = 1.0

    // MARK: - Recording

    /// Records one accepted tap's normalized offset for `keyCharacter`, seeding the EMA on
    /// the first sample and stepping it by `smoothing` afterward. Returns whether the sample
    /// was recorded, so callers can skip persisting hygiene-rejected input (junk keys,
    /// non-finite offsets).
    @discardableResult
    mutating func recordAcceptedTap(keyCharacter: String,
                                    normalizedOffset: (dx: Double, dy: Double)) -> Bool {
        guard let key = Self.fold(keyCharacter),
              normalizedOffset.dx.isFinite, normalizedOffset.dy.isFinite else { return false }
        let dx = min(max(normalizedOffset.dx, -Self.offsetLimit), Self.offsetLimit)
        let dy = min(max(normalizedOffset.dy, -Self.offsetLimit), Self.offsetLimit)
        if var existing = offsets[key] {
            existing.dx += Self.smoothing * (dx - existing.dx)
            existing.dy += Self.smoothing * (dy - existing.dy)
            existing.samples += 1
            offsets[key] = existing
        } else {
            offsets[key] = Offset(dx: dx, dy: dy, samples: 1)
        }
        return true
    }

    // MARK: - Policy

    /// The one place that decides which key bases the personalization tracks: exactly one
    /// character, and a letter. Punctuation, digits, and multi-character tokens (date/time,
    /// snippets, "return", …) are never personalized — shared by the page host's tap
    /// buffering and the keyboard view's offset-map rebuild so the two edges can't drift.
    static func isPersonalizable(_ base: String) -> Bool {
        base.count == 1 && base.first?.isLetter == true
    }

    // MARK: - Lookup

    /// The learned normalized offset for `keyCharacter`, or nil while the key is still
    /// warming up (fewer than `warmupSamples` accepted taps) — nil means "change nothing".
    func offset(forKeyCharacter keyCharacter: String) -> (dx: Double, dy: Double)? {
        guard let key = Self.fold(keyCharacter),
              let stored = offsets[key], stored.samples >= Self.warmupSamples else { return nil }
        return (stored.dx, stored.dy)
    }

    // MARK: - Private

    /// Lowercases so shifted/unshifted taps of one physical key share an entry; anything
    /// that isn't exactly one character after folding is junk (multi-character tokens,
    /// empty strings, characters whose lowercase form expands).
    private static func fold(_ keyCharacter: String) -> String? {
        let folded = keyCharacter.lowercased()
        guard folded.count == 1 else { return nil }
        return folded
    }
}

// MARK: - Persistence coding (raw-Data app-group key: UserPrefs.qwertyTouchOffsetsData)

extension QwertyTouchPersonalization {
    /// Decodes a stored model; empty or corrupt data degrades to an empty model (the
    /// QwertyPersonalDictionary resilience posture — never crash the keyboard).
    init(data: Data) {
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode(QwertyTouchPersonalization.self, from: data)
        else {
            self = QwertyTouchPersonalization()
            return
        }
        self = decoded
    }

    /// JSON blob for the app-group store (at most a few dozen letter-key entries — cheap to
    /// encode on every accepted tap at typing speed).
    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

/// Versioned app-group persistence envelope for touch personalization. Models are keyed by
/// device class + the *resolved* QWERTY layout mode so a phone grip can never bias iPad
/// centered/split/compact hit routing (and different iPad geometries do not contaminate one
/// another).
///
/// Decoding the old unscoped `QwertyTouchPersonalization` format performs the only supported
/// migration: that model is installed at `phone/automatic` and `requiresMigrationWrite` asks
/// the keyboard host to rewrite the envelope immediately. Once rewritten, subsequent reads
/// decode this envelope and cannot run the legacy path again.
struct QwertyTouchPersonalizationEnvelope: Codable, Equatable {
    static let currentVersion = 1

    enum LoadState: Equatable {
        case empty
        case current
        case legacy
        case corrupt
        case unsupportedVersion(Int)
    }

    private(set) var version = currentVersion
    private var models: [String: QwertyTouchPersonalization] = [:]
    private(set) var loadState: LoadState = .empty
    /// Exact bytes of an unsupported envelope. They remain authoritative until a newer app
    /// understands them; this version must never downgrade them through a learning write.
    private var blockedOriginalData: Data?

    var requiresMigrationWrite: Bool { loadState == .legacy }

    var permitsPersistence: Bool {
        if case .unsupportedVersion = loadState { return false }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case version, models
    }

    private struct VersionProbe: Decodable {
        let version: Int?
    }

    init() {}

    init(data: Data) {
        guard !data.isEmpty else { return }
        let decoder = JSONDecoder()
        if let probe = try? decoder.decode(VersionProbe.self, from: data),
           let storedVersion = probe.version {
            guard storedVersion == Self.currentVersion else {
                version = storedVersion
                loadState = .unsupportedVersion(storedVersion)
                blockedOriginalData = data
                return
            }
            guard let decoded = try? decoder.decode(Self.self, from: data) else {
                loadState = .corrupt
                return
            }
            self = decoded
            loadState = .current
            return
        }
        if let legacy = try? decoder.decode(QwertyTouchPersonalization.self, from: data) {
            models[QwertyPersonalizationContext.phoneAutomatic.storageKey] = legacy
            loadState = .legacy
        } else {
            loadState = .corrupt
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        models = try container.decode(
            [String: QwertyTouchPersonalization].self,
            forKey: .models
        )
        loadState = .current
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(models, forKey: .models)
    }

    func model(for context: QwertyPersonalizationContext) -> QwertyTouchPersonalization {
        models[context.storageKey] ?? QwertyTouchPersonalization()
    }

    @discardableResult
    mutating func setModel(_ model: QwertyTouchPersonalization,
                           for context: QwertyPersonalizationContext) -> Bool {
        guard permitsPersistence else { return false }
        models[context.storageKey] = model
        loadState = .current
        return true
    }

    func encoded() -> Data {
        if !permitsPersistence, let blockedOriginalData {
            return blockedOriginalData
        }
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

/// Cross-process persistence protocol for both learned stores. Closure seams let tests place
/// resets at exact read/write boundaries without involving app-group globals.
enum QwertyTouchPersonalizationPersistence {
    private struct EpochPayload: Codable {
        static let magic = "numpad-qwerty-personalization"
        static let currentVersion = 1

        let marker: String
        let version: Int
        let generation: Int
        let payload: Data

        init(generation: Int, payload: Data) {
            marker = Self.magic
            version = Self.currentVersion
            self.generation = generation
            self.payload = payload
        }
    }

    struct Snapshot: Equatable {
        let dictionary: QwertyPersonalDictionary
        let touchEnvelope: QwertyTouchPersonalizationEnvelope
        let generation: Int
    }

    /// Reads the odd/even epoch on both sides of both learned stores. A reset publishes an odd
    /// value before its first clear; readers reject odd or changed epochs. Each payload also
    /// carries the stable epoch that wrote it, so a delayed pre-reset writer that physically lands
    /// after reset is ignored rather than resurrecting learned data.
    static func loadConsistentSnapshot(
        currentEpoch: () -> Int,
        currentDictionaryData: () -> Data,
        currentTouchData: () -> Data
    ) -> Snapshot {
        while true {
            let generationBefore = currentEpoch()
            guard generationBefore.isMultiple(of: 2) else { continue }
            let storedDictionary = currentDictionaryData()
            let storedTouch = currentTouchData()
            let generationAfter = currentEpoch()
            guard generationBefore == generationAfter,
                  generationAfter.isMultiple(of: 2)
            else {
                continue
            }
            let dictionaryData = payload(
                from: storedDictionary,
                accepting: generationAfter
            )
            let touchData = payload(
                from: storedTouch,
                accepting: generationAfter
            )
            return Snapshot(
                dictionary: QwertyPersonalDictionary(data: dictionaryData),
                touchEnvelope: QwertyTouchPersonalizationEnvelope(data: touchData),
                generation: generationAfter
            )
        }
    }

    static func loadCurrentSnapshot() -> Snapshot {
        loadConsistentSnapshot(
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData }
        )
    }

    /// Migrates a legacy touch blob through the same pre/post-write epoch guard as ordinary
    /// learning. If reset starts after the pre-check, the stale write is epoch-tagged and the
    /// post-check reload rejects it.
    static func persistLegacyMigrationIfCurrent(
        snapshot: Snapshot,
        currentEpoch: () -> Int,
        currentDictionaryData: () -> Data,
        currentTouchData: () -> Data,
        persistTouchData: (Data) -> Void
    ) -> Snapshot {
        guard snapshot.touchEnvelope.requiresMigrationWrite,
              snapshot.touchEnvelope.permitsPersistence
        else {
            return snapshot
        }
        let migratedEnvelope = QwertyTouchPersonalizationEnvelope(
            data: snapshot.touchEnvelope.encoded()
        )
        return persistTouchIfCurrent(
            snapshot: snapshot,
            updatedEnvelope: migratedEnvelope,
            currentEpoch: currentEpoch,
            currentDictionaryData: currentDictionaryData,
            currentTouchData: currentTouchData,
            persistTouchData: persistTouchData
        )
    }

    static func persistDictionaryIfCurrent(
        snapshot: Snapshot,
        updatedDictionary: QwertyPersonalDictionary,
        currentEpoch: () -> Int,
        currentDictionaryData: () -> Data,
        currentTouchData: () -> Data,
        persistDictionaryData: (Data) -> Void
    ) -> Snapshot {
        guard currentEpoch() == snapshot.generation,
              snapshot.generation.isMultiple(of: 2)
        else {
            return loadConsistentSnapshot(
                currentEpoch: currentEpoch,
                currentDictionaryData: currentDictionaryData,
                currentTouchData: currentTouchData
            )
        }
        persistDictionaryData(
            storedData(
                payload: updatedDictionary.encoded(),
                generation: snapshot.generation
            )
        )
        guard currentEpoch() == snapshot.generation else {
            return loadConsistentSnapshot(
                currentEpoch: currentEpoch,
                currentDictionaryData: currentDictionaryData,
                currentTouchData: currentTouchData
            )
        }
        return Snapshot(
            dictionary: updatedDictionary,
            touchEnvelope: snapshot.touchEnvelope,
            generation: snapshot.generation
        )
    }

    static func persistTouchIfCurrent(
        snapshot: Snapshot,
        updatedEnvelope: QwertyTouchPersonalizationEnvelope,
        currentEpoch: () -> Int,
        currentDictionaryData: () -> Data,
        currentTouchData: () -> Data,
        persistTouchData: (Data) -> Void
    ) -> Snapshot {
        guard updatedEnvelope.permitsPersistence,
              currentEpoch() == snapshot.generation,
              snapshot.generation.isMultiple(of: 2)
        else {
            return loadConsistentSnapshot(
                currentEpoch: currentEpoch,
                currentDictionaryData: currentDictionaryData,
                currentTouchData: currentTouchData
            )
        }
        persistTouchData(
            storedData(
                payload: updatedEnvelope.encoded(),
                generation: snapshot.generation
            )
        )
        guard currentEpoch() == snapshot.generation else {
            return loadConsistentSnapshot(
                currentEpoch: currentEpoch,
                currentDictionaryData: currentDictionaryData,
                currentTouchData: currentTouchData
            )
        }
        return Snapshot(
            dictionary: snapshot.dictionary,
            touchEnvelope: updatedEnvelope,
            generation: snapshot.generation
        )
    }

    /// Brackets a destructive two-store reset with an odd in-progress epoch and publishes the
    /// next even epoch only after both clears and the legacy counter bump are durable.
    static func resetAll(
        currentEpoch: () -> Int,
        setEpoch: (Int) -> Void,
        clearDictionary: () -> Void,
        clearTouch: () -> Void,
        incrementLegacyGeneration: () -> Void,
        synchronize: () -> Void = {}
    ) {
        var stableGeneration = currentEpoch()
        while !stableGeneration.isMultiple(of: 2) {
            stableGeneration = currentEpoch()
        }
        let inProgressGeneration = stableGeneration + 1
        setEpoch(inProgressGeneration)
        synchronize()
        clearDictionary()
        clearTouch()
        incrementLegacyGeneration()
        synchronize()
        setEpoch(inProgressGeneration + 1)
        synchronize()
    }

    static func resetAll() {
        resetAll(
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            setEpoch: { UserPrefs.qwertyPersonalizationEpoch = $0 },
            clearDictionary: { UserPrefs.qwertyPersonalDictionaryData = Data() },
            clearTouch: { UserPrefs.qwertyTouchOffsetsData = Data() },
            incrementLegacyGeneration: { UserPrefs.qwertyPersonalResetGeneration += 1 },
            synchronize: { UserDefaults.group.synchronize() }
        )
    }

    /// The app's personal-dictionary editor is also a cross-process mutation. Re-tag both stores
    /// under one new stable epoch so the live keyboard reloads the edit without mixing it with a
    /// pre-edit touch payload.
    @discardableResult
    static func replaceDictionary(
        with updatedDictionary: QwertyPersonalDictionary,
        currentEpoch: () -> Int,
        setEpoch: (Int) -> Void,
        currentDictionaryData: () -> Data,
        currentTouchData: () -> Data,
        persistDictionaryData: (Data) -> Void,
        persistTouchData: (Data) -> Void,
        incrementLegacyGeneration: () -> Void,
        synchronize: () -> Void = {}
    ) -> Snapshot {
        let before = loadConsistentSnapshot(
            currentEpoch: currentEpoch,
            currentDictionaryData: currentDictionaryData,
            currentTouchData: currentTouchData
        )
        let inProgressGeneration = before.generation + 1
        let completedGeneration = before.generation + 2
        setEpoch(inProgressGeneration)
        synchronize()
        let touchPayload = before.touchEnvelope.encoded()
        let updatedTouch = QwertyTouchPersonalizationEnvelope(data: touchPayload)
        persistDictionaryData(
            storedData(
                payload: updatedDictionary.encoded(),
                generation: completedGeneration
            )
        )
        persistTouchData(
            storedData(
                payload: touchPayload,
                generation: completedGeneration
            )
        )
        incrementLegacyGeneration()
        synchronize()
        setEpoch(completedGeneration)
        synchronize()
        return Snapshot(
            dictionary: updatedDictionary,
            touchEnvelope: updatedTouch,
            generation: completedGeneration
        )
    }

    @discardableResult
    static func replaceDictionary(with updatedDictionary: QwertyPersonalDictionary) -> Snapshot {
        replaceDictionary(
            with: updatedDictionary,
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            setEpoch: { UserPrefs.qwertyPersonalizationEpoch = $0 },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData },
            persistDictionaryData: { UserPrefs.qwertyPersonalDictionaryData = $0 },
            persistTouchData: { UserPrefs.qwertyTouchOffsetsData = $0 },
            incrementLegacyGeneration: { UserPrefs.qwertyPersonalResetGeneration += 1 },
            synchronize: { UserDefaults.group.synchronize() }
        )
    }

    private static func storedData(payload: Data, generation: Int) -> Data {
        (try? JSONEncoder().encode(EpochPayload(
            generation: generation,
            payload: payload
        ))) ?? Data()
    }

    private static func payload(from storedData: Data, accepting generation: Int) -> Data {
        guard !storedData.isEmpty else { return Data() }
        guard let wrapped = try? JSONDecoder().decode(EpochPayload.self, from: storedData),
              wrapped.marker == EpochPayload.magic
        else {
            // Compatibility migration: pre-epoch installs use the original raw stores at epoch
            // zero. Once any reset/app mutation advances the epoch, an untagged delayed write is
            // stale by definition and must fail closed.
            return generation == 0 ? storedData : Data()
        }
        guard wrapped.version == EpochPayload.currentVersion,
              wrapped.generation == generation
        else {
            return Data()
        }
        return wrapped.payload
    }
}
