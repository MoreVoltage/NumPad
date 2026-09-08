import Darwin
import Foundation

/// One crash-safe aggregate counter file guarded by a POSIX advisory lock. `flock` coordinates
/// separate app and keyboard-extension processes (unlike `NSLock`), while `.atomic` replaces
/// the JSON only after a complete write. Failed operations remain in this store instance's
/// process-local pending bag and are merged by the next successful operation.
final class TypingQualityCounterStore: @unchecked Sendable {
    struct FileAccess {
        let createDirectory: (URL) throws -> Void
        let openLock: (String) -> Int32
        let lock: (Int32, Int32) -> Int32
        let unlock: (Int32) -> Void
        let close: (Int32) -> Void
        let read: (URL) throws -> Data
        let encode: ([String: Int]) throws -> Data
        let write: (Data, URL) throws -> Void

        init(
            createDirectory: @escaping (URL) throws -> Void = { url in
                try FileManager.default.createDirectory(
                    at: url, withIntermediateDirectories: true)
            },
            openLock: @escaping (String) -> Int32 = { path in
                Darwin.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            },
            lock: @escaping (Int32, Int32) -> Int32 = { descriptor, operation in
                flock(descriptor, operation)
            },
            unlock: @escaping (Int32) -> Void = { descriptor in
                _ = flock(descriptor, LOCK_UN)
            },
            close: @escaping (Int32) -> Void = { descriptor in
                _ = Darwin.close(descriptor)
            },
            read: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
            encode: @escaping ([String: Int]) throws -> Data = {
                try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])
            },
            write: @escaping (Data, URL) throws -> Void = { data, url in
                try data.write(to: url, options: Data.WritingOptions.atomic)
            }
        ) {
            self.createDirectory = createDirectory
            self.openLock = openLock
            self.lock = lock
            self.unlock = unlock
            self.close = close
            self.read = read
            self.encode = encode
            self.write = write
        }
    }

    let fileURL: URL
    private let lockURL: URL
    private let fileAccess: FileAccess
    private let pendingLock = NSLock()
    private var pending: [String: Int] = [:]
    private var flushScheduled = false
    private let persistenceQueue = DispatchQueue(
        label: "com.morevoltage.numpad.typing-counters", qos: .utility)
    private let flushInterval: TimeInterval

    init(fileURL: URL, fileAccess: FileAccess = FileAccess(),
         flushInterval: TimeInterval = 0.5) {
        self.fileURL = fileURL
        self.lockURL = fileURL.appendingPathExtension("lock")
        self.fileAccess = fileAccess
        self.flushInterval = max(0, flushInterval)
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

    private static let keyboardPrivate = TypingQualityCounterStore(
        fileURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Constants.typingQualityCounters.rawValue + ".json"))

    /// Without Full Access, aggregate keyboard diagnostics remain in the extension sandbox.
    static var active: TypingQualityCounterStore {
        let storage = KeyboardLocalStateStore.shared
        return storage.isKeyboard && !storage.allowsSharedWrites ? keyboardPrivate : appGroup
    }

    func increment(_ event: TypingQualityCounters.Event, by amount: Int) {
        guard amount > 0 else { return }
        pendingLock.lock()
        pending[event.rawValue, default: 0] += amount
        let shouldSchedule = !flushScheduled
        flushScheduled = true
        pendingLock.unlock()
        if shouldSchedule {
            persistenceQueue.asyncAfter(deadline: .now() + flushInterval) { [self] in
                _ = persistPending()
            }
        }
    }

    /// Explicit durability boundary for tests and app-side consumers. Never call on a key tap.
    @discardableResult
    func flushPending() -> Bool {
        persistenceQueue.sync { persistPending() }
    }

    /// Best-effort lifecycle flush; extension termination may lose the last small batch.
    /// Keeping the keyboard responsive takes precedence over durable usage counters.
    func requestFlush() {
        persistenceQueue.async { [self] in _ = persistPending() }
    }

    func snapshotAndSubtract() -> [String: Int] {
        persistenceQueue.sync {
            let pendingSnapshot = takePending()
            guard let snapshot: [String: Int] = coordinate({ persisted in
                merge(pendingSnapshot, into: &persisted)
                let result = persisted.filter { $0.value > 0 }
                persisted.removeAll()
                return result
            }) else {
                restorePending(pendingSnapshot)
                return [:]
            }
            return snapshot
        }
    }

    func restore(_ snapshot: [String: Int]) {
        let approved = Self.sanitize(snapshot, requirePositive: true)
        guard !approved.isEmpty else { return }
        restorePending(approved)
        _ = flushPending()
    }

    #if DEBUG
    /// Deterministic UI-test reset using the same stable advisory lock as every writer. Keeping the
    /// lock file and inode in place ensures a writer already holding that lock finishes before the
    /// empty transaction, rather than writing through an unlinked stale lock after reset.
    @discardableResult
    func resetForUITesting() -> Bool {
        persistenceQueue.sync {
            _ = takePending()
            return coordinate { persisted in persisted.removeAll() } != nil
        }
    }
    #endif

    @discardableResult
    private func persistPending() -> Bool {
        let snapshot = takePending()
        guard !snapshot.isEmpty else { return true }
        guard coordinate({ persisted in
            merge(snapshot, into: &persisted)
        }) != nil else {
            restorePending(snapshot)
            return false
        }
        return true
    }

    /// The input thread shares only this short in-memory critical section with persistence.
    /// In particular, no file lock or file access is performed while holding pendingLock.
    private func takePending() -> [String: Int] {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        let snapshot = pending
        pending.removeAll(keepingCapacity: true)
        flushScheduled = false
        return snapshot
    }

    private func restorePending(_ snapshot: [String: Int]) {
        pendingLock.lock()
        merge(snapshot, into: &pending)
        pendingLock.unlock()
    }

    /// Runs one read-modify-atomic-replace transaction while holding a stable sibling lock file.
    /// EINTR is a signal interruption, not a lock failure, so acquisition retries in place.
    private func coordinate<Result>(
        _ mutation: (inout [String: Int]) -> Result
    ) -> Result? {
        do {
            try fileAccess.createDirectory(fileURL.deletingLastPathComponent())
        } catch {
            return nil
        }

        let descriptor = fileAccess.openLock(lockURL.path)
        guard descriptor >= 0 else { return nil }
        defer { fileAccess.close(descriptor) }

        while fileAccess.lock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { return nil }
        }
        defer { fileAccess.unlock(descriptor) }

        var bag = load()
        let result = mutation(&bag)
        do {
            try fileAccess.write(fileAccess.encode(bag), fileURL)
            return result
        } catch {
            return nil
        }
    }

    private func load() -> [String: Int] {
        guard let data = try? fileAccess.read(fileURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return [:]
        }

        var bag: [String: Int] = [:]
        let approvedKeys = TypingQualityCounters.Event.approvedRawValues
        for (key, value) in dictionary where approvedKeys.contains(key) {
            guard let number = value as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.rounded(.towardZero) == number.doubleValue,
                  number.intValue >= 0 else { continue }
            bag[key] = number.intValue
        }
        return bag
    }

    private static func sanitize(_ snapshot: [String: Int],
                                 requirePositive: Bool) -> [String: Int] {
        let approvedKeys = TypingQualityCounters.Event.approvedRawValues
        return snapshot.filter {
            approvedKeys.contains($0.key) && (requirePositive ? $0.value > 0 : $0.value >= 0)
        }
    }

    private func merge(_ source: [String: Int], into destination: inout [String: Int]) {
        for (key, value) in source where value > 0 {
            destination[key, default: 0] += value
        }
    }

}

/// Pure lifecycle helper used by the keyboard host. A short abandoned session contains one
/// through ten typing actions; empty raises and sessions reaching eleven actions are not abandonment.
struct TypingQualitySession {
    static let shortSessionMaximumActions = 10

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
    enum Event: CaseIterable {
        case keyTaps
        case suggestionsShown
        case suggestionsAccepted
        case correctionsApplied
        case correctionReverts
        case backspaceTaps
        case backspaceRepeatSessions
        case pageSwitches
        case shortAbandonedSessions

        var constant: Constants {
            switch self {
            case .keyTaps: return .typingQualityKeyTaps
            case .suggestionsShown: return .typingQualitySuggestionsShown
            case .suggestionsAccepted: return .typingQualitySuggestionsAccepted
            case .correctionsApplied: return .typingQualityCorrectionsApplied
            case .correctionReverts: return .typingQualityCorrectionReverts
            case .backspaceTaps: return .typingQualityBackspaceTaps
            case .backspaceRepeatSessions: return .typingQualityBackspaceRepeatSessions
            case .pageSwitches: return .typingQualityPageSwitches
            case .shortAbandonedSessions: return .typingQualityShortAbandonedSessions
            }
        }

        var rawValue: String { constant.rawValue }

        static var approvedRawValues: Set<String> {
            Set(allCases.map(\.rawValue))
        }
    }

    static func increment(_ event: Event,
                          store: TypingQualityCounterStore = .active,
                          by amount: Int = 1) {
        store.increment(event, by: amount)
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
