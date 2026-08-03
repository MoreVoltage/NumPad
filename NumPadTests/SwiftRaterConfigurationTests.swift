//
//  SwiftRaterConfigurationTests.swift
//  NumPadTests
//
//  Characterization: the automatic rating prompt path must be reachable under
//  SwiftRater 2.2.2's `.all` conditions mode.
//

import XCTest
import SwiftRater
@testable import NumPad

final class SwiftRaterConfigurationTests: XCTestCase {
    /// In pinned SwiftRater, `-1` is `SwiftRaterInvalid` and *skips* the significant-use
    /// assignment, leaving `significantUsesUntilPromptMet` at false. Under `.all` that
    /// permanently blocks the prompt. Threshold `0` is the correct "no significant-use
    /// requirement" value (always met without wiring increments).
    @MainActor
    func test_configure_setsSignificantUsesThresholdToZeroNotInvalidSentinel() {
        SwiftRater.configure()
        XCTAssertEqual(
            SwiftRater.significantUsesUntilPrompt,
            0,
            "significantUsesUntilPrompt must be 0 (always met), not -1 (SwiftRaterInvalid skip)"
        )
        XCTAssertNotEqual(
            SwiftRater.significantUsesUntilPrompt,
            -1,
            "-1 is the library sentinel that leaves the .all AND-chain permanently false"
        )
        XCTAssertEqual(SwiftRater.daysUntilPrompt, 7)
        XCTAssertEqual(SwiftRater.usesUntilPrompt, 10)
        XCTAssertEqual(SwiftRater.conditionsMetMode, .all)
    }

    /// Gate-level companion: values alone can go green after a pod change that renames
    /// sentinel semantics. Seed UsageDataManager's UserDefaults keys (library-private names
    /// mirrored from SwiftRater source) and assert `isMetConditions`.
    ///
    /// Note: do **not** call `appLaunched()` here — with `resetWhenAppUpdated` it can wipe
    /// first-use / counters mid-test. We seed the store the library actually reads.
    @MainActor
    func test_configure_isMetConditionsTrueAfterAgedInstallAndEnoughLaunches() {
        let ud = UserDefaults.standard
        let keys = [
            "keySwiftRaterFirstUseDate",
            "keySwiftRaterUseCount",
            "keySwiftRaterSignificantEventCount",
            "keySwiftRaterRateDone",
            "keySwiftRaterTrackingVersion",
            "keySwiftRaterReminderRequestDate"
        ]
        let before = keys.map { ($0, ud.object(forKey: $0)) }
        defer {
            for (key, value) in before {
                if let value { ud.set(value, forKey: key) } else { ud.removeObject(forKey: key) }
            }
        }
        keys.forEach { ud.removeObject(forKey: $0) }
        SwiftRater.configure()
        // First use 8+ days ago (daysUntilPrompt = 7); uses ≥ 10; not rate-done.
        ud.set(Date().addingTimeInterval(-8 * 24 * 3600).timeIntervalSince1970, forKey: "keySwiftRaterFirstUseDate")
        ud.set(10, forKey: "keySwiftRaterUseCount")
        ud.set(0, forKey: "keySwiftRaterSignificantEventCount") // significantUsesUntilPrompt = 0 → always met
        ud.set(false, forKey: "keySwiftRaterRateDone")
        ud.set(0.0, forKey: "keySwiftRaterReminderRequestDate")
        ud.synchronize()
        XCTAssertTrue(
            SwiftRater.isMetConditions,
            "With significantUses=0, days aged ≥7, uses≥10, and not rate-done, isMetConditions must be true"
        )
    }
}
