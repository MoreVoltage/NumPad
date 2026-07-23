//
//  KeyboardProfileStoreTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardProfileStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "profile-store-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_emptyStoreReturnsBuiltIns() {
        let store = KeyboardProfileStore(defaults: defaults)
        let snap = store.load()
        XCTAssertEqual(snap.profiles.filter { $0.kind != .custom }.count, 7)
        XCTAssertFalse(snap.hadCorruptData)
    }

    func test_corruptDataPreservesBytesAndReturnsBuiltIns() {
        let junk = Data("not-json".utf8)
        defaults.set(junk, forKey: Constants.keyboardProfiles.rawValue)
        let store = KeyboardProfileStore(defaults: defaults)
        let snap = store.load()
        XCTAssertTrue(snap.hadCorruptData)
        XCTAssertEqual(defaults.data(forKey: Constants.keyboardProfilesCorruptBackup.rawValue), junk)
        XCTAssertEqual(defaults.data(forKey: Constants.keyboardProfiles.rawValue), junk)
        XCTAssertEqual(snap.profiles.filter { $0.kind != .custom }.count, 7)
    }

    func test_saveAndReloadRoundTrip() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var snap = store.load()
        let custom = KeyboardProfile.testFixture
        snap.profiles.append(custom)
        snap.activeProfileID = custom.id
        try store.save(snap)
        let reloaded = store.load()
        XCTAssertTrue(reloaded.profiles.contains(where: { $0.id == custom.id }))
        XCTAssertEqual(reloaded.activeProfileID, custom.id)
    }
}
