import XCTest
@testable import NumPad

final class KioskSessionPolicyTests: XCTestCase {
    func test_noResetBeforeTimeout() throws {
        let policy = try KeyboardProfileFactory.kiosk().kioskPolicy!
        let now = Date()
        let actions = KioskSessionPolicy.actions(policy: policy, lastInteraction: now, now: now.addingTimeInterval(10))
        XCTAssertTrue(actions.isEmpty)
    }

    func test_resetAfterTimeout() throws {
        let policy = try KeyboardProfileFactory.kiosk().kioskPolicy!
        let now = Date()
        let actions = KioskSessionPolicy.actions(
            policy: policy,
            lastInteraction: now.addingTimeInterval(-policy.inactivityTimeout - 1),
            now: now)
        XCTAssertTrue(actions.contains(.dismissOverlays))
        XCTAssertTrue(actions.contains(.resetPageAndPack))
    }
}

