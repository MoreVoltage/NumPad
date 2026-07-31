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

    func test_v1ProfileWithoutCurrentIPadLayoutFieldsDecodes() throws {
        let profile = KeyboardProfile.testFixture
        let encoded = try JSONEncoder().encode(profile)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var configuration = try XCTUnwrap(object["configuration"] as? [String: Any])
        configuration.removeValue(forKey: "numpadWidthSizeRaw")
        configuration.removeValue(forKey: "iPadQwertyLayoutRaw")
        configuration.removeValue(forKey: "fullKeyboardNumpadSideRaw")
        object["configuration"] = configuration

        let decoded = try JSONDecoder().decode(
            KeyboardProfile.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.configuration.numpadWidthSizeRaw)
        XCTAssertNil(decoded.configuration.iPadQwertyLayoutRaw)
        XCTAssertNil(decoded.configuration.fullKeyboardNumpadSideRaw)
    }

    func test_unknownCurrentIPadLayoutRawValuesFailValidationWhenPresent() {
        var profile = KeyboardProfile.testFixture
        profile.configuration.numpadWidthSizeRaw = "oversized"
        XCTAssertThrowsError(try profile.validated()) { error in
            XCTAssertEqual(
                error as? KeyboardProfile.ValidationError,
                .invalidNumpadWidthSize("oversized")
            )
        }

        profile = KeyboardProfile.testFixture
        profile.configuration.iPadQwertyLayoutRaw = "split"
        XCTAssertThrowsError(try profile.validated()) { error in
            XCTAssertEqual(
                error as? KeyboardProfile.ValidationError,
                .invalidIPadQwertyLayout("split")
            )
        }

        profile = KeyboardProfile.testFixture
        profile.configuration.fullKeyboardNumpadSideRaw = "center"
        XCTAssertThrowsError(try profile.validated()) { error in
            XCTAssertEqual(
                error as? KeyboardProfile.ValidationError,
                .invalidFullKeyboardNumpadSide("center")
            )
        }
    }

    func test_numpadPackRejectsLegacyDecodeOnlyAndQwertyOnlyFamilies() {
        let invalid: [KeyboardType] = [
            .tax, .scientific, .business, .international, .programmerPlus,
            .grammar, .punctuation, .snippets
        ]
        for pack in invalid {
            var profile = KeyboardProfile.testFixture
            profile.configuration.keyboardTypeRaw = pack.rawValue
            XCTAssertThrowsError(try profile.validated(), "Expected \(pack.rawValue) rejection")
        }
        for pack in [KeyboardType.default, .custom] + KeyboardType.packs {
            var profile = KeyboardProfile.testFixture
            profile.configuration.keyboardTypeRaw = pack.rawValue
            XCTAssertNoThrow(try profile.validated(), "Expected \(pack.rawValue) acceptance")
        }
    }

    func test_primaryQwertyPackAcceptsOnlyCrossoverFamily() {
        for pack in [KeyboardType.math, .tax, .scientific, .units] {
            var profile = KeyboardProfile.testFixture
            profile.configuration.qwertyPrimaryPackRaw = pack.rawValue
            XCTAssertThrowsError(try profile.validated(), "Expected \(pack.rawValue) rejection")
        }
        for pack in QwertyPackFamily.members {
            var profile = KeyboardProfile.testFixture
            profile.configuration.qwertyPrimaryPackRaw = pack.rawValue
            XCTAssertNoThrow(try profile.validated(), "Expected \(pack.rawValue) acceptance")
        }
    }

    func test_editorOptionPolicyMatchesProductionAvailability() {
        let entitlements = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )
        let numpad = ProfileEditorOptionPolicy.numpadPacks(
            enabledPacks: [.math, .finance, .scientific],
            entitlements: entitlements
        )
        XCTAssertEqual(numpad, [.default, .math])

        let qwerty = ProfileEditorOptionPolicy.qwertyPacks(
            entitlements: entitlements,
            hasCustomKeys: false,
            hasSnippets: false
        )
        XCTAssertFalse(qwerty.contains(.custom))
        XCTAssertFalse(qwerty.contains(.snippets))
        XCTAssertTrue(qwerty.allSatisfy(QwertyPackFamily.members.contains))
    }

    func test_kioskKindAndPolicyMustRemainCoupled() {
        var customWithPolicy = KeyboardProfileFactory.kiosk()
        customWithPolicy.kind = .custom
        XCTAssertThrowsError(try customWithPolicy.validated()) { error in
            XCTAssertEqual(
                error as? KeyboardProfile.ValidationError,
                .kioskPolicyKindMismatch
            )
        }

        var kioskWithoutPolicy = KeyboardProfileFactory.kiosk()
        kioskWithoutPolicy.kioskPolicy = nil
        XCTAssertThrowsError(try kioskWithoutPolicy.validated()) { error in
            XCTAssertEqual(
                error as? KeyboardProfile.ValidationError,
                .kioskPolicyKindMismatch
            )
        }
    }
}
