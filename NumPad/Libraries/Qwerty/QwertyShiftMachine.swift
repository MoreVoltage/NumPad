import Foundation

/// Shift/caps-lock state for the QWERTY keyboard, matching system behavior: a single tap
/// engages one-shot shift, a second tap within `doubleTapWindow` engages caps lock (including
/// from an autocap-engaged shift), inserting a character consumes one-shot shift, and caps
/// lock only ever changes on an explicit shift tap.
///
/// Pure and clock-injected — timestamps are parameters — so every transition is unit-testable.
struct QwertyShiftMachine: Equatable {
    enum State: Equatable {
        case lowercase
        case shifted
        case capsLock
    }

    /// System double-tap-for-caps-lock window.
    static let doubleTapWindow: TimeInterval = 0.3

    private(set) var state: State = .lowercase
    /// Whether the current one-shot shift was engaged by autocap — autocap may only ever
    /// drop what it engaged, never a shift the user chose.
    private var shiftEngagedByAutocap = false
    /// Set when the user explicitly disengages shift; autocap must not fight the user until
    /// the next insertion moves the context on.
    private var userOverrodeAutocap = false
    private var lastShiftTap: TimeInterval?

    mutating func shiftTapped(at time: TimeInterval) {
        let isDoubleTap = lastShiftTap.map { time - $0 <= Self.doubleTapWindow } ?? false
        switch state {
        case .capsLock:
            // Leaving caps lock starts fresh — the disengaging tap must not pair with the
            // next one into an instant re-lock.
            state = .lowercase
            shiftEngagedByAutocap = false
            userOverrodeAutocap = true
            lastShiftTap = nil
            return
        case .lowercase:
            state = isDoubleTap ? .capsLock : .shifted
            shiftEngagedByAutocap = false
            userOverrodeAutocap = false
        case .shifted:
            state = isDoubleTap ? .capsLock : .lowercase
            shiftEngagedByAutocap = false
            if state == .lowercase { userOverrodeAutocap = true }
        }
        lastShiftTap = time
    }

    /// Call after every text insertion: consumes one-shot shift (caps lock is untouched) and
    /// clears any user override so the next boundary re-evaluates autocap fresh.
    mutating func didInsertCharacter(_ text: String) {
        userOverrodeAutocap = false
        guard state == .shifted else { return }
        state = .lowercase
        shiftEngagedByAutocap = false
    }

    /// Call whenever the document context changes, with `QwertyAutocap.shouldCapitalize`'s
    /// verdict. Engages/disengages one-shot shift on autocap's behalf without ever fighting
    /// an explicit user choice or touching caps lock.
    mutating func evaluateAutocap(shouldCapitalize: Bool) {
        switch state {
        case .capsLock:
            return
        case .lowercase:
            if shouldCapitalize && !userOverrodeAutocap {
                state = .shifted
                shiftEngagedByAutocap = true
            }
        case .shifted:
            if !shouldCapitalize && shiftEngagedByAutocap {
                state = .lowercase
                shiftEngagedByAutocap = false
            }
        }
    }

    /// The text a character key inserts under the current shift state.
    func output(for key: QwertyKey) -> String? {
        guard case .character(let base, let shifted) = key.kind else { return nil }
        return state == .lowercase ? base : shifted
    }
}
