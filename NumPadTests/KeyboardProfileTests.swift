//
//  KeyboardProfileTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardProfileTests: XCTestCase {
    func test_profileRoundTripsWithoutPersonalContent() throws {
        let profile = KeyboardProfile.testFixture
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(KeyboardProfile.self, from: data)
        XCTAssertEqual(decoded, profile)

        let json = String(decoding: data, as: UTF8.self)
        // Preference flags like clipboardHistoryEnabled / resultTapeEnabled are allowed.
        // Forbidden keys are personal CONTENT and entitlement storage key names.
        let forbidden = [
            "\"snippets\"", "clipboardEntries", "resultTapeItems",
            "qwertyPersonalDictionary", "qwertyTouchOffsets",
            "isProPurchased", "isGrandfathered", "isFinancePackPurchased"
        ]
        for key in forbidden {
            XCTAssertFalse(json.contains(key), "Profile JSON unexpectedly contains '\(key)'")
        }
    }

    func test_kioskTimeoutBelowMinimumFailsValidation() {
        var profile = KeyboardProfile.testFixture
        profile.kind = .kiosk
        profile.kioskPolicy = KioskPolicy(
            inactivityTimeout: 10,
            resetPageAndPack: true,
            dismissOverlays: true,
            clearResultTape: true,
            clearClipboardHistory: true,
            requireAdministratorAuthentication: true
        )
        XCTAssertThrowsError(try profile.validated()) { error in
            XCTAssertEqual(error as? KeyboardProfile.ValidationError, .invalidKioskTimeout(10))
        }
    }

    func test_futureSchemaIsRejected() {
        var profile = KeyboardProfile.testFixture
        profile.schemaVersion = 99
        XCTAssertThrowsError(try profile.validated()) { error in
            XCTAssertEqual(error as? KeyboardProfile.ValidationError, .unsupportedSchema(99))
        }
    }

    func test_malformedEnumRawValuesFailValidation() {
        var profile = KeyboardProfile.testFixture
        profile.configuration.themeRaw = "not-a-theme"
        XCTAssertThrowsError(try profile.validated())
        profile = KeyboardProfile.testFixture
        profile.configuration.keyboardPageRaw = "emoji"
        XCTAssertThrowsError(try profile.validated())
    }

    func test_layoutPreferenceDefaultsAreAutomatic() {
        XCTAssertEqual(QwertyLayoutMode.automatic.rawValue, "automatic")
        XCTAssertEqual(NumpadPlacement.automatic.rawValue, "automatic")
    }
}
