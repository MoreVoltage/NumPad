import XCTest
@testable import NumPad

final class KioskReadinessTests: XCTestCase {
    func test_blockedWhenKeyboardDisabled() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: false, fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(report.status, .blocked)
    }

    func test_readyWhenAllSatisfied() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(report.status, .ready)
    }

    func test_warningForUnconfirmedItems() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, fullAccessConfirmed: false, profileApplies: true,
            usedEntitlementFallback: true, tryItConfirmed: false, guidedAccessAcknowledged: false))
        XCTAssertEqual(report.status, .warning)
    }
}

