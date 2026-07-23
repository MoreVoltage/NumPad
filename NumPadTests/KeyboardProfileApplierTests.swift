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

    private func entitled(
        pro: Bool = true,
        kiosk: Bool = true,
        custom: Bool = true,
        fullKeyboard: Bool = true,
        owned: Set<String> = Set(ProductCatalog.allPackProductIDs)
    ) -> ProfileEntitlements {
        ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: pro,
            kioskHeightEntitled: kiosk,
            customKeyboardEntitled: custom,
            fullKeyboardEntitled: fullKeyboard,
            ownedPackProductIDs: owned
        )
    }

    func test_applyWritesOnceAndNotifiesOnce() throws {
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        let profile = KeyboardProfileFactory.finance()
        let result = try applier.apply(profile, entitlements: entitled())
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
        let result = try applier.apply(profile, entitlements: entitled(kiosk: false))
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
        XCTAssertThrowsError(try applier.apply(profile, entitlements: entitled()))
        XCTAssertEqual(notifyCount, 0)
    }

    func test_nilCustomConfigClearsExistingCustomKeyboard() throws {
        var store = CustomKeyboardStore(defaults: defaults)
        store.onChange = {}
        store.save(CustomKeyboardConfig(topRow: ["a", "b"], column1: ["1"], column2: nil))
        XCTAssertNotNil(store.load())

        var profile = KeyboardProfileFactory.standard()
        profile.configuration.customKeyboardConfig = nil
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        _ = try applier.apply(profile, entitlements: entitled())
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())
        XCTAssertEqual(notifyCount, 1)
    }

    func test_alaCartePackEntitlements_allPacks() {
        let packs: [KeyboardType] = [.finance, .symbols, .programmer, .datetime, .units, .cooking]
        for pack in packs {
            guard let productID = ProductCatalog.packProductID(for: pack) else {
                XCTFail("Missing product ID for \(pack)")
                continue
            }
            // Owned only this pack, not Pro → unlocked.
            let ownedOnly = ProfileEntitlements(
                paywallEnabled: true,
                proEntitled: false,
                kioskHeightEntitled: false,
                customKeyboardEntitled: false,
                fullKeyboardEntitled: false,
                ownedPackProductIDs: [productID]
            )
            XCTAssertFalse(ownedOnly.isPackLocked(pack), "\(pack) should unlock via à-la-carte")
            for other in packs where other != pack {
                XCTAssertTrue(ownedOnly.isPackLocked(other), "\(other) should stay locked when only \(pack) owned")
            }
            // Pro unlocks all.
            let pro = entitled(pro: true, owned: [])
            XCTAssertFalse(pro.isPackLocked(pack))
        }
        // Base packs never locked.
        let none = entitled(pro: false, owned: [])
        XCTAssertFalse(none.isPackLocked(.default))
        XCTAssertFalse(none.isPackLocked(.math))
        XCTAssertTrue(none.isPackLocked(.custom))
    }

    func test_lockedPackFallsBackToDefault() throws {
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }
        let profile = KeyboardProfileFactory.finance()
        let result = try applier.apply(
            profile,
            entitlements: entitled(pro: false, owned: [])
        )
        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardType.rawValue), KeyboardType.default.rawValue)
        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardTheme.rawValue), KeyboardTheme.white.rawValue)
        XCTAssertEqual(
            result.fallbacks,
            [.packLocked(KeyboardType.finance.rawValue), .themePremiumToWhite(KeyboardTheme.teal.rawValue)]
        )
        XCTAssertEqual(profile.configuration.keyboardTypeRaw, KeyboardType.finance.rawValue)
    }
}

final class KeyboardProfileFactoryExactTests: XCTestCase {
    func test_standardDefaultsAreProductionNotTestFixture() {
        let config = KeyboardProfile.Configuration.defaults
        XCTAssertNotEqual(config, .testFixture, "Production defaults must not alias testFixture")
        XCTAssertEqual(config.keyboardTypeRaw, KeyboardType.default.rawValue)
        XCTAssertEqual(config.themeRaw, KeyboardTheme.white.rawValue)
        XCTAssertEqual(config.roundedCorners, false)
        XCTAssertEqual(config.qwertyAutocorrect, false)
        XCTAssertEqual(config.keyboardPageRaw, "numpad")
    }

    func test_builtInExactExpectedValues() {
        let standard = KeyboardProfileFactory.standard()
        XCTAssertEqual(standard.configuration, .defaults)
        XCTAssertEqual(standard.kind, .standard)
        XCTAssertNil(standard.kioskPolicy)

        let calculator = KeyboardProfileFactory.calculator()
        XCTAssertEqual(calculator.configuration.keyboardTypeRaw, KeyboardType.math.rawValue)
        XCTAssertEqual(calculator.configuration.reversedMode, true)
        XCTAssertEqual(calculator.configuration.heightRaw, KeyboardHeightPreset.regular.rawValue)

        let finance = KeyboardProfileFactory.finance()
        XCTAssertEqual(finance.configuration.keyboardTypeRaw, KeyboardType.finance.rawValue)
        XCTAssertEqual(finance.configuration.themeRaw, KeyboardTheme.teal.rawValue)

        let inventory = KeyboardProfileFactory.inventory()
        XCTAssertEqual(inventory.configuration.keyboardTypeRaw, KeyboardType.units.rawValue)
        XCTAssertEqual(inventory.configuration.grid, true)
        XCTAssertEqual(inventory.configuration.roundedCorners, true)

        let writing = KeyboardProfileFactory.writing()
        XCTAssertEqual(writing.configuration.keyboardPageRaw, "qwerty")
        XCTAssertEqual(writing.configuration.qwertySuggestions, true)
        XCTAssertEqual(writing.configuration.qwertyAutocorrect, false)
        XCTAssertEqual(writing.configuration.qwertyPeriodComma, true)

        let accessibility = KeyboardProfileFactory.accessibility()
        XCTAssertEqual(accessibility.configuration.heightRaw, KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(accessibility.configuration.roundedCorners, true)
        XCTAssertEqual(accessibility.configuration.grid, true)
        XCTAssertEqual(accessibility.configuration.themeRaw, KeyboardTheme.black.rawValue)
        XCTAssertEqual(accessibility.configuration.hapticsEnabled, true)
        XCTAssertEqual(accessibility.configuration.soundEnabled, true)

        let kiosk = KeyboardProfileFactory.kiosk()
        XCTAssertEqual(kiosk.configuration.heightRaw, KeyboardHeightPreset.kiosk.rawValue)
        XCTAssertEqual(kiosk.configuration.themeRaw, KeyboardTheme.black.rawValue)
        XCTAssertEqual(kiosk.configuration.numpadPlacementRaw, NumpadPlacement.center.rawValue)
        XCTAssertEqual(kiosk.configuration.roundedCorners, true)
        XCTAssertEqual(kiosk.configuration.grid, true)
        XCTAssertEqual(kiosk.configuration.keyboardPageRaw, "numpad")
        XCTAssertEqual(kiosk.configuration.clipboardHistoryEnabled, false)
        XCTAssertEqual(kiosk.configuration.resultTapeEnabled, true)
        XCTAssertEqual(kiosk.kioskPolicy?.inactivityTimeout, 120)
        XCTAssertEqual(kiosk.kioskPolicy?.resetPageAndPack, true)
        XCTAssertEqual(kiosk.kioskPolicy?.dismissOverlays, true)
        XCTAssertEqual(kiosk.kioskPolicy?.clearResultTape, true)
        XCTAssertEqual(kiosk.kioskPolicy?.clearClipboardHistory, true)
        XCTAssertEqual(kiosk.kioskPolicy?.requireAdministratorAuthentication, true)
    }
}

final class CustomKeyboardProfileValidationTests: XCTestCase {
    func test_rejectsOversizedTopRowAndBadTokens() {
        let tooMany = CustomKeyboardConfig(topRow: Array(repeating: "a", count: 11))
        XCTAssertThrowsError(try CustomKeyboardProfileValidation.validate(tooMany))

        let badToken = CustomKeyboardConfig(topRow: ["{nope}"])
        XCTAssertThrowsError(try CustomKeyboardProfileValidation.validate(badToken))

        let longLiteral = CustomKeyboardConfig(topRow: ["toolong"])
        XCTAssertThrowsError(try CustomKeyboardProfileValidation.validate(longLiteral))

        let ok = CustomKeyboardConfig(
            topRow: ["$", CustomKeys.spaceToken, DateTimeTokens.keyToken(for: "date")],
            column1: ["1", "2", "3"],
            column2: nil
        )
        XCTAssertNoThrow(try CustomKeyboardProfileValidation.validate(ok))
    }
}
