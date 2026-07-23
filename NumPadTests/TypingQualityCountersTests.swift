import XCTest
@testable import NumPad

final class TypingQualityCountersTests: XCTestCase {
    func test_drainClearsAndReturnsIntegersOnly() {
        let suite = "tqc-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        TypingQualityCounters.increment(.keyTaps, defaults: defaults, by: 3)
        TypingQualityCounters.increment(.suggestionsShown, defaults: defaults)
        let drained = TypingQualityCounters.drain(defaults: defaults)
        XCTAssertEqual(drained["keyTaps"], 3)
        XCTAssertEqual(drained["suggestionsShown"], 1)
        XCTAssertTrue(TypingQualityCounters.drain(defaults: defaults).isEmpty)
        XCTAssertEqual(Set(TypingQualityCounters.Event.allCases.map { $0.rawValue }).count,
                       TypingQualityCounters.Event.allCases.count)
    }
}
