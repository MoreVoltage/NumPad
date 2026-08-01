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
        // Autocorrect defaults OFF until a confidence policy clears measured gates.
        XCTAssertFalse((defaults.object(forKey: Constants.qwertyAutocorrectEnabled.rawValue) as? Bool) ?? false)
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

    func test_iPadLayoutPreferenceContractsUseRequiredDefaultsAndLegacyMappings() {
        XCTAssertEqual(NumpadWidthSize.allCases.map(\.fraction), [0.60, 0.70, 0.80, 0.90, 1.00])
        XCTAssertEqual(NumpadWidthSize.defaultValue, .full)
        XCTAssertEqual(IPadQwertyLayout.defaultValue, .standard)
        XCTAssertEqual(FullKeyboardNumpadSide.defaultValue, .right)
        XCTAssertEqual(NumpadWidthSize.migrated(from: .fullWidth), .full)
        // Soft landing: non-full legacy placements → Medium 80%, not Compact 60%.
        XCTAssertEqual(NumpadWidthSize.migrated(from: .automatic), .medium)
        XCTAssertEqual(NumpadWidthSize.migrated(from: .center), .medium)
        XCTAssertEqual(NumpadWidthSize.migrated(from: .left), .medium)
        XCTAssertEqual(NumpadWidthSize.migrated(from: .right), .medium)
        XCTAssertEqual(IPadQwertyLayout.migrated(from: .split), .standard)
    }

    func test_iPadLayoutPreferencesReadFreshNewAndLegacyDefaultsWithoutChangingHeight() {
        XCTAssertEqual(UserPrefs.readNumpadWidthSize(from: defaults), .full)
        XCTAssertEqual(UserPrefs.readIPadQwertyLayout(from: defaults), .standard)
        XCTAssertEqual(UserPrefs.readFullKeyboardNumpadSide(from: defaults), .right)

        defaults.set(NumpadWidthSize.wide.rawValue, forKey: Constants.numpadWidthSize.rawValue)
        defaults.set(IPadQwertyLayout.full.rawValue, forKey: Constants.iPadQwertyLayout.rawValue)
        defaults.set(FullKeyboardNumpadSide.left.rawValue, forKey: Constants.fullKeyboardNumpadSide.rawValue)
        XCTAssertEqual(UserPrefs.readNumpadWidthSize(from: defaults), .wide)
        XCTAssertEqual(UserPrefs.readIPadQwertyLayout(from: defaults), .full)
        XCTAssertEqual(UserPrefs.readFullKeyboardNumpadSide(from: defaults), .left)

        defaults.removeObject(forKey: Constants.numpadWidthSize.rawValue)
        defaults.removeObject(forKey: Constants.iPadQwertyLayout.rawValue)
        defaults.removeObject(forKey: Constants.fullKeyboardNumpadSide.rawValue)
        defaults.set(NumpadPlacement.fullWidth.rawValue, forKey: Constants.numpadPlacement.rawValue)
        defaults.set(QwertyLayoutMode.split.rawValue, forKey: Constants.qwertyLayoutMode.rawValue)
        defaults.set(KeyboardHeightPreset.tall.rawValue, forKey: Constants.heightPreset.rawValue)

        XCTAssertEqual(UserPrefs.readNumpadWidthSize(from: defaults), .full)
        XCTAssertEqual(UserPrefs.readIPadQwertyLayout(from: defaults), .standard)
        XCTAssertEqual(UserPrefs.readFullKeyboardNumpadSide(from: defaults), .right)
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
    }
}
