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
}
