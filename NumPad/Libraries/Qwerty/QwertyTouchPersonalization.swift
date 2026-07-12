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
/// wizard, which also bumps the shared reset-generation counter).
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
