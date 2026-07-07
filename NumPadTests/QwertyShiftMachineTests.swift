import XCTest
@testable import NumPad

final class QwertyShiftMachineTests: XCTestCase {

    // MARK: single tap toggles one-shot shift

    func testTapFromLowercaseEngagesShift() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        XCTAssertEqual(machine.state, .shifted)
    }

    func testTapFromShiftedDisengages() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: 10)
        XCTAssertEqual(machine.state, .lowercase)
    }

    // MARK: double-tap → caps lock (system parity: within the double-tap window)

    func testDoubleTapWithinWindowEngagesCapsLock() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: QwertyShiftMachine.doubleTapWindow - 0.01)
        XCTAssertEqual(machine.state, .capsLock)
    }

    func testSlowSecondTapDoesNotEngageCapsLock() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: QwertyShiftMachine.doubleTapWindow + 0.01)
        XCTAssertEqual(machine.state, .lowercase)
    }

    func testTapFromCapsLockReturnsToLowercase() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: 0.1)
        XCTAssertEqual(machine.state, .capsLock)
        machine.shiftTapped(at: 0.2)
        XCTAssertEqual(machine.state, .lowercase)
    }

    func testTapAfterCapsLockOffStartsAFreshSingleTap() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: 0.1)      // caps lock
        machine.shiftTapped(at: 0.15)     // off — must not immediately re-trigger caps lock
        XCTAssertEqual(machine.state, .lowercase)
        machine.shiftTapped(at: 0.2)
        XCTAssertEqual(machine.state, .shifted, "next tap is a fresh single tap")
    }

    func testDoubleTapFromAutocapEngagedShiftStillReachesCapsLock() {
        // System parity: at a sentence start (shift auto-engaged), double-tapping shift
        // engages caps lock — the first tap disengages, the second within the window locks.
        var machine = QwertyShiftMachine()
        machine.evaluateAutocap(shouldCapitalize: true)
        XCTAssertEqual(machine.state, .shifted)
        machine.shiftTapped(at: 0)
        XCTAssertEqual(machine.state, .lowercase)
        machine.shiftTapped(at: 0.1)
        XCTAssertEqual(machine.state, .capsLock)
    }

    // MARK: one-shot shift is consumed by insertion; caps lock is not

    func testInsertionConsumesOneShotShift() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.didInsertCharacter("A")
        XCTAssertEqual(machine.state, .lowercase)
    }

    func testInsertionDoesNotTouchCapsLock() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: 0.1)
        machine.didInsertCharacter("A")
        machine.didInsertCharacter("B")
        XCTAssertEqual(machine.state, .capsLock)
    }

    // MARK: autocap engagement (auto-engaged shift yields to the user, and never fights them)

    func testAutocapEngagesShiftFromLowercase() {
        var machine = QwertyShiftMachine()
        machine.evaluateAutocap(shouldCapitalize: true)
        XCTAssertEqual(machine.state, .shifted)
    }

    func testAutocapDisengagesOnlyWhatItEngaged() {
        var machine = QwertyShiftMachine()
        machine.evaluateAutocap(shouldCapitalize: true)
        machine.evaluateAutocap(shouldCapitalize: false)
        XCTAssertEqual(machine.state, .lowercase, "auto-engaged shift drops when the context changes")

        machine.shiftTapped(at: 0)
        machine.evaluateAutocap(shouldCapitalize: false)
        XCTAssertEqual(machine.state, .shifted, "user-engaged shift is never dropped by autocap")
    }

    func testAutocapNeverTouchesCapsLock() {
        var machine = QwertyShiftMachine()
        machine.shiftTapped(at: 0)
        machine.shiftTapped(at: 0.1)
        machine.evaluateAutocap(shouldCapitalize: false)
        XCTAssertEqual(machine.state, .capsLock)
        machine.evaluateAutocap(shouldCapitalize: true)
        XCTAssertEqual(machine.state, .capsLock)
    }

    func testUserDisengageIsNotFoughtByAutocap() {
        // ". " context: autocap engages, user taps shift off, autocap must not instantly re-engage.
        var machine = QwertyShiftMachine()
        machine.evaluateAutocap(shouldCapitalize: true)
        machine.shiftTapped(at: 0)
        XCTAssertEqual(machine.state, .lowercase)
        machine.evaluateAutocap(shouldCapitalize: true)
        XCTAssertEqual(machine.state, .lowercase, "user override holds until the next insertion")

        machine.didInsertCharacter("a")
        machine.evaluateAutocap(shouldCapitalize: true)
        XCTAssertEqual(machine.state, .shifted, "override clears once typing moves on")
    }

    // MARK: casing helper

    func testOutputCasingFollowsState() {
        var machine = QwertyShiftMachine()
        XCTAssertEqual(machine.output(for: QwertyKey(kind: .character("a", shifted: "A"), width: 1)), "a")
        machine.shiftTapped(at: 0)
        XCTAssertEqual(machine.output(for: QwertyKey(kind: .character("a", shifted: "A"), width: 1)), "A")
        machine.shiftTapped(at: 0.1)
        XCTAssertEqual(machine.output(for: QwertyKey(kind: .character("a", shifted: "A"), width: 1)), "A")
    }
}
