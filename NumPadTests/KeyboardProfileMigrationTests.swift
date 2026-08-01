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

    func test_migrationSnapshotsLegacyIPadLayoutPreferencesIntoCurrentFields() throws {
        defaults.set(NumpadPlacement.center.rawValue, forKey: Constants.numpadPlacement.rawValue)
        defaults.set(QwertyLayoutMode.split.rawValue, forKey: Constants.qwertyLayoutMode.rawValue)

        let outcome = KeyboardProfileMigration.runIfNeeded(defaults: defaults)

        guard case .migrated(let activeID) = outcome else {
            return XCTFail("Expected migration to succeed, got \(outcome)")
        }
        let snapshot = try XCTUnwrap(
            KeyboardProfileStore(defaults: defaults).load().profiles.first { $0.id == activeID }
        )
        // Soft landing: legacy center (non-full) → medium 80%, not compact 60%.
        XCTAssertEqual(snapshot.configuration.numpadWidthSizeRaw, NumpadWidthSize.medium.rawValue)
        XCTAssertEqual(snapshot.configuration.iPadQwertyLayoutRaw, IPadQwertyLayout.standard.rawValue)
        XCTAssertEqual(snapshot.configuration.fullKeyboardNumpadSideRaw, FullKeyboardNumpadSide.right.rawValue)
    }

    func test_migrationPreservesExistingCorruptProfileBytesBeforeReplacingStore() {
        let corrupt = Data([0x00, 0xFF, 0x12, 0x34, 0x56])
        defaults.set(corrupt, forKey: Constants.keyboardProfiles.rawValue)

        let outcome = KeyboardProfileMigration.runIfNeeded(defaults: defaults)

        guard case .migrated = outcome else {
            return XCTFail("Expected migration to succeed, got \(outcome)")
        }
        XCTAssertEqual(
            defaults.data(forKey: Constants.keyboardProfilesCorruptBackup.rawValue),
            corrupt
        )
        XCTAssertNotEqual(defaults.data(forKey: Constants.keyboardProfiles.rawValue), corrupt)
    }

    func test_migrationFailureKeepsCorruptBytesSeparateFromDiagnostic() {
        let corrupt = Data([0xDE, 0xAD, 0xBE, 0xEF])
        defaults.set(corrupt, forKey: Constants.keyboardProfiles.rawValue)
        defaults.set("not-a-pack", forKey: Constants.selectedKeyboardType.rawValue)

        let outcome = KeyboardProfileMigration.runIfNeeded(defaults: defaults)

        guard case .failed = outcome else {
            return XCTFail("Expected migration failure, got \(outcome)")
        }
        XCTAssertEqual(
            defaults.data(forKey: Constants.keyboardProfilesCorruptBackup.rawValue),
            corrupt
        )
        XCTAssertNotNil(
            defaults.string(forKey: Constants.keyboardProfileMigrationDiagnostic.rawValue)
        )
    }
}
