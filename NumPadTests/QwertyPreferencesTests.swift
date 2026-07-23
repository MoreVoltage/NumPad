import XCTest
@testable import NumPad

final class QwertyPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "qwerty-prefs-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_newPreferencesDefaultTrueInIsolatedDefaults() {
        // Mirror the @UserDefault defaultValue contract used by UserPrefs.
        XCTAssertEqual(defaults.object(forKey: Constants.qwertyAutocorrectEnabled.rawValue) as? Bool, nil)
        XCTAssertEqual(defaults.object(forKey: Constants.qwertySuggestionsEnabled.rawValue) as? Bool, nil)
        XCTAssertEqual(defaults.object(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue) as? Bool, nil)
        XCTAssertTrue((defaults.object(forKey: Constants.qwertyAutocorrectEnabled.rawValue) as? Bool) ?? true)
        XCTAssertTrue((defaults.object(forKey: Constants.qwertySuggestionsEnabled.rawValue) as? Bool) ?? true)
        XCTAssertTrue((defaults.object(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue) as? Bool) ?? true)
    }

    func test_preferencesPersistInIsolatedDefaults() {
        defaults.set(false, forKey: Constants.qwertyAutocorrectEnabled.rawValue)
        defaults.set(false, forKey: Constants.qwertySuggestionsEnabled.rawValue)
        defaults.set(false, forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue)
        XCTAssertEqual(defaults.bool(forKey: Constants.qwertyAutocorrectEnabled.rawValue), false)
        XCTAssertEqual(defaults.bool(forKey: Constants.qwertySuggestionsEnabled.rawValue), false)
        XCTAssertEqual(defaults.bool(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue), false)
    }
}
