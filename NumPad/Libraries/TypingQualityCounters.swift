import Darwin
import Foundation

/// One crash-safe aggregate counter file guarded by a POSIX advisory lock. `flock` coordinates
/// separate app and keyboard-extension processes (unlike `NSLock`), while `.atomic` replaces
/// the JSON only after a complete write. The file contains event names and integers only.
final class TypingQualityCounterStore: @unchecked Sendable {
    let fileURL: URL
    private let lockURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.lockURL = fileURL.appendingPathExtension("lock")
    }

    static let appGroup: TypingQualityCounterStore = {
        let fileManager = FileManager.default
        let directory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.morevoltage.numpad.container")
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return TypingQualityCounterStore(
            fileURL: directory.appendingPathComponent(
                Constants.typingQualityCounters.rawValue + ".json"))
    }()

    @discardableResult
    func increment(_ key: String, by amount: Int) -> Bool {
        guard amount != 0 else { return true }
        return update { bag in
            bag[key, default: 0] += amount
        }
    }

    func snapshotAndSubtract() -> [String: Int] {
        var snapshot: [String: Int] = [:]
        let persisted = update { bag in
            snapshot = bag.filter { $0.value > 0 }
            for (key, value) in snapshot {
                let remaining = (bag[key] ?? 0) - value
                if remaining > 0 {
                    bag[key] = remaining
                } else {
                    bag.removeValue(forKey: key)
                }
            }
        }
        return persisted ? snapshot : [:]
    }

    func restore(_ snapshot: [String: Int]) {
        _ = update { bag in
            for (key, value) in snapshot where value > 0 {
                bag[key, default: 0] += value
            }
        }
    }

    @discardableResult
    private func update(_ mutation: (inout [String: Int]) -> Void) -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            return false
        }

        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { return false }
        defer { flock(descriptor, LOCK_UN) }

        var bag = load()
        mutation(&bag)
        do {
            let data = try JSONSerialization.data(
                withJSONObject: bag, options: [.sortedKeys])
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func load() -> [String: Int] {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return [:] }
        var bag: [String: Int] = [:]
        for (key, value) in dictionary {
            if let integer = value as? Int {
                bag[key] = integer
            } else if let number = value as? NSNumber {
                bag[key] = number.intValue
            }
        }
        return bag
    }
}

/// Pure lifecycle helper used by the keyboard host. A short abandoned session contains one or
/// two typing actions; empty raises and sessions reaching three actions are not abandonment.
struct TypingQualitySession {
    static let shortSessionMaximumActions = 2

    private var active = false
    private var typingActions = 0

    mutating func activate() {
        guard !active else { return }
        active = true
        typingActions = 0
    }

    mutating func recordTypingAction() {
        guard active else { return }
        typingActions += 1
    }

    /// Returns true exactly once when the ending session meets the short-abandonment rule.
    mutating func finish() -> Bool {
        guard active else { return false }
        active = false
        return (1...Self.shortSessionMaximumActions).contains(typingActions)
    }
}

/// Privacy-safe typing counters shared across app + Keyboard extension.
enum TypingQualityCounters {
    enum Event: String, CaseIterable {
        case keyTaps
        case suggestionsShown
        case suggestionsAccepted
        case correctionsApplied
        case correctionReverts
        case backspaceTaps
        case backspaceRepeatSessions
        case pageSwitches
        case shortAbandonedSessions
    }

    static func increment(_ event: Event,
                          store: TypingQualityCounterStore = .appGroup,
                          by amount: Int = 1) {
        store.increment(event.rawValue, by: amount)
    }

    static func snapshotAndSubtract(
        store: TypingQualityCounterStore = .appGroup) -> [String: Int] {
        store.snapshotAndSubtract()
    }

    static func restore(_ snapshot: [String: Int],
                        store: TypingQualityCounterStore = .appGroup) {
        store.restore(snapshot)
    }

    static func drain(store: TypingQualityCounterStore = .appGroup) -> [String: Int] {
        snapshotAndSubtract(store: store)
    }

    static func flushIfNeeded(
        store: TypingQualityCounterStore = .appGroup,
        log: (_ name: String, _ attributes: [String: Any]) -> Void = { name, attrs in
            Analytics.logEvent(name: name, attributes: attrs)
        }) {
        let snapshot = snapshotAndSubtract(store: store)
        guard !snapshot.isEmpty else { return }
        let attributes = snapshot.reduce(into: [String: Any]()) {
            if $1.value > 0 { $0[$1.key] = $1.value }
        }
        guard !attributes.isEmpty else { return }
        log("typing_quality", attributes)
    }
}
