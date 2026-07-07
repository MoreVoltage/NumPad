import Foundation

/// Which pack the QWERTY top strip reopens with (owner decision §0.4): LAST-USED reopens
/// whatever was showing when the keyboard was dismissed; PRIMARY-SELECTED always reopens the
/// pack the user pinned. Cross-process raw storage lives in `UserPrefs` (SharedExtensions);
/// the typed accessors below compile only where QWERTY code does.
enum PackDisplayBehavior: String {
    case lastUsed, primarySelected

    static let `default` = PackDisplayBehavior.lastUsed
}

/// The QWERTY-side pack family — the §2 crossover table made executable. Reuses the existing
/// `PackKeys`/`DateTimeTokens`/`CustomPackManager` data and the `Monetization` entitlement
/// machinery (injected as a closure) — no new gating system (owner decision §0.3).
enum QwertyPackFamily {

    /// Crossover order. Grammar ships first; Units & Cooking stay numpad-only (the "="
    /// converter overlay is their point); Custom crosses unconditionally.
    static let members: [KeyboardType] = [.grammar, .symbols, .finance, .programmer, .datetime, .custom]

    /// Strip content for one pack. `customKeys` is injected (`CustomPackManager.shared.keys`
    /// at the call site) so this stays pure.
    static func content(for pack: KeyboardType, customKeys: [String]) -> [QwertyTopStrip.Content] {
        switch pack {
        case .datetime:
            return DateTimeTokens.ordered.map { .dateTime(token: $0.token, label: $0.label) }
        case .custom:
            return customKeys.filter { !$0.isEmpty }.map { .literal($0) }
        default:
            return PackKeys.symbols(for: pack).map { .literal($0) }
        }
    }

    /// The next strip selection when the pack-switch key is tapped: number row (nil) → each
    /// entitled member in order → back to the number row. A stale/unentitled current
    /// selection restarts at the first entitled pack.
    static func next(after current: KeyboardType?,
                     entitled: (KeyboardType) -> Bool) -> KeyboardType? {
        let available = members.filter(entitled)
        guard !available.isEmpty else { return nil }
        guard let current = current, let index = available.firstIndex(of: current) else {
            return available.first
        }
        let nextIndex = index + 1
        return nextIndex < available.count ? available[nextIndex] : nil
    }

    /// Which pack the strip should show on (re)open, per the display behavior. Nil means the
    /// number row.
    static func packToShow(behavior: PackDisplayBehavior,
                           lastUsed: KeyboardType?,
                           primary: KeyboardType?) -> KeyboardType? {
        switch behavior {
        case .lastUsed: return lastUsed
        case .primarySelected: return primary
        }
    }
}

/// Typed accessors over the raw app-group storage in `UserPrefs` (SharedExtensions). Computed
/// (not stored) because extensions can't add stored properties; compiled only into the app and
/// KeyboardType targets alongside the rest of the Qwerty files.
extension UserPrefs {
    static var packDisplayBehavior: PackDisplayBehavior {
        get { PackDisplayBehavior(rawValue: packDisplayBehaviorRaw) ?? .default }
        set { packDisplayBehaviorRaw = newValue.rawValue }
    }

    /// The strip's last-used pack; nil = the number row.
    static var qwertyTopStripPack: KeyboardType? {
        get { qwertyTopStripPackRaw.flatMap(KeyboardType.init) }
        set { qwertyTopStripPackRaw = newValue?.rawValue }
    }

    /// The pinned PRIMARY-SELECTED pack; nil = the number row.
    static var qwertyPrimaryPack: KeyboardType? {
        get { qwertyPrimaryPackRaw.flatMap(KeyboardType.init) }
        set { qwertyPrimaryPackRaw = newValue?.rawValue }
    }
}
