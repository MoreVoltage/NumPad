import Foundation

/// Editable draft of the structured custom keyboard, backed by `CustomKeyboardStore`.
///
/// Mirrors the write-through pattern of the right-side-keys editor: every edit produces a *new*
/// config (value semantics — never mutated in place), persists it, and posts `onChange` so a live
/// keyboard re-reads via `SettingsSync`. "Active" means the stored config has at least one key
/// (`CustomKeyboardConfig.hasAnyKeys`); the three section switches and per-cell entry are the only
/// controls. Handedness is the global `UserPrefs.handedness`.
///
/// On first open the draft is seeded from the user's existing Custom Pack (→ Top Row) and right-side
/// slots (→ Column 1), so their first custom keyboard starts from what they already have.
///
/// All external effects (persistence, notification, analytics, handedness storage) are injected so
/// the model is unit-testable without touching the real app group.
final class CustomKeyboardEditorModel: ObservableObject {
    enum Section: CaseIterable, Identifiable { case topRow, column1, column2; var id: Self { self } }

    /// A peripheral cell address: which section, and the index within it.
    struct Cell: Equatable, Hashable { let section: Section; let index: Int }

    static let columnCapacity = 3                          // aligned to the three number rows
    static let topRowCapacity = 10                         // a horizontal strip above the numpad
    static let maxKeyLength = CustomKeys.maxTokenLength    // 4 — "char or token"

    @Published private(set) var config: CustomKeyboardConfig
    @Published private(set) var handedness: Handedness

    private let store: CustomKeyboardStore
    private let notify: () -> Void
    private let persistHandedness: (Handedness) -> Void
    private let logEvent: (String, [String: Any]) -> Void

    init(store: CustomKeyboardStore = CustomKeyboardStore(defaults: .group),
         handedness: Handedness = UserPrefs.handedness,
         seedPackKeys: [String] = CustomPackManager.shared.keys,
         seedSlots: [String] = CustomKeys.slots,
         notify: @escaping () -> Void = { SettingsSync.post() },
         persistHandedness: @escaping (Handedness) -> Void = { UserPrefs.handedness = $0 },
         logEvent: @escaping (String, [String: Any]) -> Void = { Analytics.logEvent(name: $0, attributes: $1) }) {
        self.store = store
        self.notify = notify
        self.persistHandedness = persistHandedness
        self.logEvent = logEvent
        self.config = store.load() ?? CustomKeyboardConfig.seeded(customPackKeys: seedPackKeys, rightSlots: seedSlots)
        self.handedness = handedness
    }

    // MARK: Section switches

    func isEnabled(_ section: Section) -> Bool { keys(for: section) != nil }

    /// Enabling an off section turns it ON-but-empty (`[]`); disabling clears it to `nil`.
    func setEnabled(_ section: Section, _ enabled: Bool) {
        let new: [String]? = enabled ? (keys(for: section) ?? []) : nil
        update(section, to: new)
        logEvent("custom_keyboard_section", ["section": String(describing: section), "enabled": enabled])
    }

    // MARK: Per-cell entry

    func keys(for section: Section) -> [String]? {
        switch section {
        case .topRow: return config.topRow
        case .column1: return config.column1
        case .column2: return config.column2
        }
    }

    func key(at cell: Cell) -> String {
        let arr = keys(for: cell.section) ?? []
        return cell.index < arr.count ? arr[cell.index] : ""
    }

    /// Sets the key at `cell`, padding the (enabled) section with empties up to the index. A raw
    /// value is trimmed and capped at `maxKeyLength`, except function tokens which pass through.
    func setKey(_ raw: String, at cell: Cell) {
        guard cell.index < capacity(cell.section) else { return }
        var arr = keys(for: cell.section) ?? []
        while arr.count <= cell.index { arr.append("") }
        arr[cell.index] = sanitize(raw)
        update(cell.section, to: arr)
    }

    /// Appends a key to the next free slot of an (enabled) section; returns its new cell, or `nil`
    /// when empty or at capacity.
    @discardableResult
    func appendKey(_ raw: String, to section: Section) -> Cell? {
        let key = sanitize(raw)
        guard !key.isEmpty else { return nil }
        var arr = keys(for: section) ?? []
        guard arr.count < capacity(section) else { return nil }
        arr.append(key)
        update(section, to: arr)
        return Cell(section: section, index: arr.count - 1)
    }

    func removeKey(at cell: Cell) {
        guard var arr = keys(for: cell.section), arr.indices.contains(cell.index) else { return }
        arr.remove(at: cell.index)
        update(cell.section, to: arr)
    }

    /// The cell to focus after editing `cell`: the next index in the same section, allowing one new
    /// empty slot at the end so the user can keep typing. `nil` at the section's capacity.
    func nextCell(after cell: Cell) -> Cell? {
        let count = (keys(for: cell.section) ?? []).count
        let nextIndex = cell.index + 1
        guard nextIndex < capacity(cell.section), nextIndex <= count else { return nil }
        return Cell(section: cell.section, index: nextIndex)
    }

    func capacity(_ section: Section) -> Int {
        section == .topRow ? Self.topRowCapacity : Self.columnCapacity
    }

    // MARK: Handedness

    func setHandedness(_ new: Handedness) {
        guard new != handedness else { return }
        handedness = new
        persistHandedness(new)
        notify()
        logEvent("custom_keyboard_handedness", ["value": new.rawValue])
    }

    // MARK: Internals

    /// Function tokens pass through verbatim; everything else is trimmed and length-capped.
    private func sanitize(_ raw: String) -> String {
        if CustomKeys.palette.contains(raw) { return raw }
        return String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxKeyLength))
    }

    private func update(_ section: Section, to value: [String]?) {
        var updated = config
        switch section {
        case .topRow: updated.topRow = value
        case .column1: updated.column1 = value
        case .column2: updated.column2 = value
        }
        config = updated
        // Persist only a keyboard worth rendering; an empty config clears storage so the keyboard
        // cleanly falls back to the normal layout.
        if config.hasAnyKeys { store.save(config) } else { store.clear() }
        notify()
    }
}
