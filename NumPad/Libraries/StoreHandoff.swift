//
//  StoreHandoff.swift
//  NumPad / Keyboard
//
//  Shared (both targets). Hands a locked tap in the keyboard over to the app's Store without the
//  keyboard ever launching the app (App Review 4.4.1).
//
//  Keyboard side: every locked tap overwrites one small record in the shared App Group defaults
//  (timestamp, source, pack if known). App side: on becoming active, a record younger than
//  `StoreHandoff.window` for something still locked opens the existing Store once, with the same
//  `source` a locked tap used to send via the old deep link. Every outcome except "app busy"
//  clears the record, so it is acted on at most once.
//

import Foundation

extension LockedTapSource {
    /// The Store's existing funnel `source` for this entry point (see `StoreViewController.source`).
    var storeSource: String {
        switch self {
        case .keyLock: return "key_lock"
        case .packPicker: return "pack_picker"
        case .conversionLock: return "conversion_lock"
        }
    }

    init?(storeSource: String) {
        guard let match = LockedTapSource.allCases.first(where: { $0.storeSource == storeSource }) else { return nil }
        self = match
    }
}

struct StoreHandoffRecord: Equatable {
    let timestamp: Date
    let source: LockedTapSource
    let pack: KeyboardType?
}

/// Reads and writes the single handoff record. Defaults and clock are injected for tests.
struct StoreHandoffStore {
    static let key = Constants.storeHandoffRecord.rawValue
    private static let timeField = "t"
    private static let sourceField = "s"
    private static let packField = "p"

    let defaults: UserDefaults
    let now: () -> Date

    static let shared = StoreHandoffStore(defaults: .group, now: Date.init)

    /// Latest tap wins: overwrites any previous record.
    func record(source: LockedTapSource, pack: KeyboardType?) {
        var value: [String: Any] = [Self.timeField: now().timeIntervalSince1970,
                                    Self.sourceField: source.storeSource]
        if let pack = pack { value[Self.packField] = pack.rawValue }
        defaults.set(value, forKey: Self.key)
    }

    /// `nil` when there is no record or it is malformed.
    func load() -> StoreHandoffRecord? {
        guard let value = defaults.dictionary(forKey: Self.key),
              let time = value[Self.timeField] as? Double,
              let rawSource = value[Self.sourceField] as? String,
              let source = LockedTapSource(storeSource: rawSource) else { return nil }
        let pack = (value[Self.packField] as? String).flatMap(KeyboardType.init(rawValue:))
        return StoreHandoffRecord(timestamp: Date(timeIntervalSince1970: time), source: source, pack: pack)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// What the app can do right now.
struct StoreHandoffContext: Equatable {
    /// Launch finished, nothing modal on screen, no deep link waiting.
    let isAppReady: Bool
    /// A Store screen is already in the navigation stack.
    let isStoreVisible: Bool
}

enum StoreHandoffDecision: Equatable {
    /// No record.
    case none
    /// Stale, entitled, or already satisfied: clear without presenting.
    case discard
    /// Fresh and still locked, but the app is busy: keep the record for a later foreground.
    case wait
    /// Show the Store with this funnel source, then clear.
    case present(source: String)
}

enum StoreHandoff {
    /// Ten minutes covers the real path (see the hint, leave the host app, find and open NumPad,
    /// maybe after finishing a sentence or a quick interruption) while staying well short of the
    /// "opened NumPad later for something else" case, where an unasked-for Store would feel like
    /// an ad rather than a continuation of what the user just tried to do.
    static let window: TimeInterval = 10 * 60

    static func decide(record: StoreHandoffRecord?, now: Date, context: StoreHandoffContext,
                       isStillLocked: (StoreHandoffRecord) -> Bool) -> StoreHandoffDecision {
        guard let record = record else { return .none }
        let age = now.timeIntervalSince(record.timestamp)
        guard age >= 0, age <= window, isStillLocked(record), !context.isStoreVisible else { return .discard }
        guard context.isAppReady else { return .wait }
        return .present(source: record.source.storeSource)
    }

    /// Applies `decide` to the stored record. Returns the Store source to present, if any. The
    /// record is cleared for every outcome except `.wait`, so it is presented at most once. A
    /// malformed record is cleared too.
    static func consume(store: StoreHandoffStore, context: StoreHandoffContext,
                        isStillLocked: (StoreHandoffRecord) -> Bool) -> String? {
        let record = store.load()
        if record == nil {
            store.clear()
            return nil
        }
        switch decide(record: record, now: store.now(), context: context, isStillLocked: isStillLocked) {
        case .none, .wait:
            return nil
        case .discard:
            store.clear()
            return nil
        case .present(let source):
            store.clear()
            return source
        }
    }

    /// Whether what the user tapped is still locked now. A recorded pack checks that pack; a
    /// converter lock without a pack checks both converter packs; anything else falls back to Pro.
    static func isStillLocked(_ record: StoreHandoffRecord, paywallEnabled: Bool, isProEntitled: Bool,
                              isPackLocked: (KeyboardType) -> Bool) -> Bool {
        guard paywallEnabled else { return false }
        if let pack = record.pack { return isPackLocked(pack) }
        if record.source == .conversionLock { return isPackLocked(.units) || isPackLocked(.cooking) }
        return !isProEntitled
    }

    /// Production entitlement check against the shared `Monetization` flags.
    static func isStillLockedNow(_ record: StoreHandoffRecord) -> Bool {
        isStillLocked(record, paywallEnabled: Monetization.paywallEnabled,
                      isProEntitled: Monetization.isProEntitled,
                      isPackLocked: { Monetization.isLocked(pack: $0) })
    }
}
