import XCTest
@testable import NumPad

final class KioskReadinessTests: XCTestCase {
    func test_blockedWhenKeyboardDisabled() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: false, activeProfileIsKiosk: true, kioskConfigurationIsValid: true,
            fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(report.status, .blocked)
    }

    func test_standardProfileIsNeverKioskReady() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, activeProfileIsKiosk: false, kioskConfigurationIsValid: false,
            fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(
            report.status,
            .blocked,
            "A fully applicable Standard profile must not qualify as kiosk-ready"
        )
    }

    func test_readyOnlyForActiveKioskWithValidConfigurationAndSuccessfulProbe() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, activeProfileIsKiosk: true, kioskConfigurationIsValid: true,
            fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(report.status, .ready)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    func test_blockedWhenActiveKioskPolicyOrConfigurationIsInvalid() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, activeProfileIsKiosk: true, kioskConfigurationIsValid: false,
            fullAccessConfirmed: true, profileApplies: true,
            usedEntitlementFallback: false, tryItConfirmed: true, guidedAccessAcknowledged: true))
        XCTAssertEqual(report.status, .blocked)
        XCTAssertTrue(report.reasons.contains("Active Kiosk policy or configuration is invalid"))
    }

    func test_warningForUnconfirmedItems() {
        let report = KioskReadiness.evaluate(.init(
            keyboardEnabled: true, activeProfileIsKiosk: true, kioskConfigurationIsValid: true,
            fullAccessConfirmed: false, profileApplies: true,
            usedEntitlementFallback: true, tryItConfirmed: false, guidedAccessAcknowledged: false))
        XCTAssertEqual(report.status, .warning)
    }
}
