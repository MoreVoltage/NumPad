import XCTest
@testable import NumPad

final class CustomKeyboardStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.customkbstore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func sample() -> CustomKeyboardConfig {
        CustomKeyboardConfig(name: "A", topRow: ["00"], column1: [",", "."], column2: nil)
    }

    func testSaveLoadRoundTrip() {
        let config = sample()
        CustomKeyboardStore(defaults: defaults).save(config)
        XCTAssertEqual(CustomKeyboardStore(defaults: defaults).load(), config)
    }

    func testLoadNilWhenNothingStored() {
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())
    }

    func testLoadNilWhenCorrupt() {
        defaults.set(Data("not json".utf8), forKey: Constants.customKeyboardConfig.rawValue)
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())
    }

    func testSaveTriggersOnChange() {
        var count = 0
        CustomKeyboardStore(defaults: defaults, onChange: { count += 1 }).save(sample())
        XCTAssertEqual(count, 1)
    }

    func testClearRemovesAndTriggersOnChange() {
        CustomKeyboardStore(defaults: defaults).save(sample())
        var count = 0
        CustomKeyboardStore(defaults: defaults, onChange: { count += 1 }).clear()
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())
        XCTAssertEqual(count, 1)
    }
}
