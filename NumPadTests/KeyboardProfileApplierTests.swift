//
//  KeyboardProfileApplierTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardProfileApplierTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var notifyCount = 0

    override func setUp() {
        super.setUp()
        suiteName = "profile-applier-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        notifyCount = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_applyWritesOnceAndNotifiesOnce() throws {
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        let profile = KeyboardProfileFactory.finance()
        let result = try applier.apply(
            profile,
            entitlements: ProfileEntitlements(pro: true, kioskHeight: true, financePack: true)
        )
        XCTAssertEqual(notifyCount, 1)
        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardType.rawValue), KeyboardType.finance.rawValue)
        XCTAssertTrue(result.changedKeys.contains(Constants.selectedKeyboardType.rawValue))
        XCTAssertTrue(result.fallbacks.isEmpty)
    }

    func test_kioskHeightFallsBackWithoutMutatingProfile() throws {
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        let profile = KeyboardProfileFactory.kiosk()
        XCTAssertEqual(profile.configuration.heightRaw, KeyboardHeightPreset.kiosk.rawValue)
        let result = try applier.apply(
            profile,
            entitlements: ProfileEntitlements(pro: true, kioskHeight: false, financePack: true)
        )
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(result.fallbacks, [.heightKioskToTall])
        XCTAssertEqual(profile.configuration.heightRaw, KeyboardHeightPreset.kiosk.rawValue)
        XCTAssertEqual(notifyCount, 1)
    }

    func test_invalidProfileDoesNotNotify() {
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        var profile = KeyboardProfile.testFixture
        profile.schemaVersion = 99
        XCTAssertThrowsError(try applier.apply(
            profile,
            entitlements: ProfileEntitlements(pro: true, kioskHeight: true, financePack: true)
        ))
        XCTAssertEqual(notifyCount, 0)
    }
}
