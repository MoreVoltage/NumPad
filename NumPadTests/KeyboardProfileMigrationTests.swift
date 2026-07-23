//
//  KeyboardProfileMigrationTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardProfileMigrationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "profile-migration-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_migrationIsIdempotent() throws {
        defaults.set(KeyboardType.symbols.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        defaults.set(KeyboardTheme.indigo.rawValue, forKey: Constants.selectedKeyboardTheme.rawValue)

        KeyboardProfileMigration.runIfNeeded(defaults: defaults)
        let first = defaults.data(forKey: Constants.keyboardProfiles.rawValue)
        let firstActive = defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue)
        XCTAssertEqual(defaults.integer(forKey: Constants.keyboardProfileMigrationVersion.rawValue), 1)
        XCTAssertNotNil(first)
        XCTAssertNotNil(firstActive)

        KeyboardProfileMigration.runIfNeeded(defaults: defaults)
        XCTAssertEqual(defaults.data(forKey: Constants.keyboardProfiles.rawValue), first)
        XCTAssertEqual(defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue), firstActive)

        let store = KeyboardProfileStore(defaults: defaults)
        let snap = store.load()
        XCTAssertEqual(snap.activeProfileID.map { id in snap.profiles.first { $0.id == id }?.name }, "My Current Setup")
        XCTAssertEqual(
            snap.profiles.first { $0.id == snap.activeProfileID }?.configuration.keyboardTypeRaw,
            KeyboardType.symbols.rawValue
        )
    }
}
