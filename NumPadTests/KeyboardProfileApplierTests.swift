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

    func test_profileApplicationStartsFreshKioskClock() throws {
        defaults.set(12_345, forKey: Constants.kioskLastActivity.rawValue)
        defaults.set(
            UUID().uuidString,
            forKey: Constants.kioskLastActivityProfileID.rawValue
        )
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.notify = { self.notifyCount += 1 }

        _ = try applier.apply(KeyboardProfileFactory.kiosk(), entitlements: entitled())

        XCTAssertNil(defaults.object(forKey: Constants.kioskLastActivity.rawValue))
        XCTAssertNil(defaults.object(forKey: Constants.kioskLastActivityProfileID.rawValue))
        XCTAssertEqual(notifyCount, 1)
    }

    func test_probeReportsQwertyFallbackWhenRemoteKillSwitchIsOffForEntitledUser() throws {
        var profile = KeyboardProfileFactory.kiosk()
        profile.configuration.keyboardPageRaw = "qwerty"
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.qwertyRemoteEnabled = { false }

        let result = try applier.probe(profile, entitlements: entitled(fullKeyboard: true))

        XCTAssertEqual(result.appliedConfiguration.keyboardPageRaw, "numpad")
        XCTAssertTrue(result.fallbacks.contains(.qwertyPageLocked))
    }

    func test_failedProfilePersistenceRestoresBothKioskClockKeys() throws {
        var invalidStoredProfile = KeyboardProfile.testFixture
        invalidStoredProfile.id = UUID()
        invalidStoredProfile.name = "Invalid stored profile"
        invalidStoredProfile.configuration.keyboardPageRaw = "invalid"
        defaults.set(
            try JSONEncoder().encode([invalidStoredProfile]),
            forKey: Constants.keyboardProfiles.rawValue
        )
        defaults.set(12_345, forKey: Constants.kioskLastActivity.rawValue)
        let priorProfileID = UUID()
        defaults.set(
            priorProfileID.uuidString,
            forKey: Constants.kioskLastActivityProfileID.rawValue
        )
        let applier = KeyboardProfileApplier(
            defaults: defaults,
            store: KeyboardProfileStore(defaults: defaults)
        )

        XCTAssertThrowsError(
            try applier.apply(KeyboardProfileFactory.standard(), entitlements: entitled())
        )

        XCTAssertEqual(defaults.double(forKey: Constants.kioskLastActivity.rawValue), 12_345)
        XCTAssertEqual(
            defaults.string(forKey: Constants.kioskLastActivityProfileID.rawValue),
            priorProfileID.uuidString
        )
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

    func test_replaceAndApplyRestoresStoredProfileAndEveryLiveKeyWhenApplicationFails() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var original = KeyboardProfile.testFixture
        original.configuration.grid = true
        var initial = store.load()
        initial.profiles.append(original)
        initial.activeProfileID = original.id
        try store.save(initial)

        var applier = KeyboardProfileApplier(defaults: defaults, notify: {}, store: store)
        _ = try applier.apply(original, entitlements: entitled())
        let previous = store.load()
        let previousBlob = defaults.data(forKey: Constants.keyboardProfiles.rawValue)
        let liveKeys = [
            Constants.selectedKeyboardType.rawValue,
            Constants.selectedKeyboardTheme.rawValue,
            Constants.automaticDarkMode.rawValue,
            Constants.heightPreset.rawValue,
            Constants.reversedMode.rawValue,
            Constants.roundedCorners.rawValue,
            Constants.grid.rawValue,
            Constants.customKeyboardConfig.rawValue,
            Constants.handedness.rawValue,
            Constants.hapticsEnabled.rawValue,
            Constants.soundEnabled.rawValue,
            Constants.repurposeNextKey.rawValue,
            Constants.clipboardHistoryEnabled.rawValue,
            Constants.inlineCalculatorEnabled.rawValue,
            Constants.liveMathPreviewEnabled.rawValue,
            Constants.cursorControlsEnabled.rawValue,
            Constants.smartPackDefaultingEnabled.rawValue,
            Constants.lastResultTapeEnabled.rawValue,
            Constants.keyboardPage.rawValue,
            Constants.qwertyPrimaryPack.rawValue,
            Constants.packDisplayBehavior.rawValue,
            Constants.qwertyPeriodComma.rawValue,
            Constants.qwertyAutocorrectEnabled.rawValue,
            Constants.qwertySuggestionsEnabled.rawValue,
            Constants.qwertyDoubleSpacePeriodEnabled.rawValue,
            Constants.qwertyLayoutMode.rawValue,
            Constants.numpadPlacement.rawValue,
            Constants.activeKeyboardProfileID.rawValue
        ]
        let priorLive = Dictionary(uniqueKeysWithValues: liveKeys.map {
            ($0, defaults.object(forKey: $0) as? NSObject)
        })

        var edited = original
        edited.name = "Edited"
        edited.configuration.grid = false
        edited.configuration.customKeyboardConfig = CustomKeyboardConfig(
            topRow: Array(repeating: "1", count: CustomKeyboardEditorModel.topRowCapacity + 1)
        )

        XCTAssertThrowsError(
            try store.replaceAndApply(
                edited,
                previous: previous,
                applier: applier,
                entitlements: entitled()
            )
        )

        XCTAssertEqual(defaults.data(forKey: Constants.keyboardProfiles.rawValue), previousBlob)
        XCTAssertEqual(store.load(), previous)
        for key in liveKeys {
            XCTAssertEqual(
                defaults.object(forKey: key) as? NSObject,
                priorLive[key] ?? nil,
                "Live key changed despite failed active edit: \(key)"
            )
        }
    }
}

final class KeyboardProfileFactoryExactTests: XCTestCase {
    func test_cleanSnapshotMatchesTypedLiveDefaults() {
        let suiteName = "profile-factory-defaults-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let config = KeyboardProfileFactory.snapshotCurrent(defaults: defaults).configuration

        XCTAssertEqual(config.keyboardTypeRaw, KeyboardType.default.rawValue)
        XCTAssertEqual(config.themeRaw, KeyboardTheme.white.rawValue)
        XCTAssertEqual(config.automaticDarkMode, false)
        XCTAssertEqual(config.heightRaw, KeyboardHeightPreset.regular.rawValue)
        XCTAssertEqual(config.reversedMode, false)
        XCTAssertEqual(config.roundedCorners, false)
        XCTAssertEqual(config.grid, true)
        XCTAssertNil(config.customKeyboardConfig)
        XCTAssertEqual(config.handednessRaw, Handedness.default.rawValue)
        XCTAssertEqual(config.hapticsEnabled, true)
        XCTAssertEqual(config.soundEnabled, true)
        XCTAssertEqual(config.repurposeNextKey, true)
        XCTAssertEqual(config.clipboardHistoryEnabled, true)
        XCTAssertEqual(config.inlineCalculator, true)
        XCTAssertEqual(config.liveMathPreview, true)
        XCTAssertEqual(config.cursorControls, true)
        XCTAssertEqual(config.smartPackDefaulting, true)
        XCTAssertEqual(config.resultTapeEnabled, true)
        XCTAssertEqual(config.keyboardPageRaw, "numpad")
        XCTAssertNil(config.qwertyPrimaryPackRaw)
        XCTAssertEqual(config.packDisplayBehaviorRaw, PackDisplayBehavior.default.rawValue)
        XCTAssertEqual(config.qwertyPeriodComma, true)
        XCTAssertEqual(config.qwertyAutocorrect, false)
        XCTAssertEqual(config.qwertySuggestions, true)
        XCTAssertEqual(config.qwertyDoubleSpacePeriod, true)
        XCTAssertEqual(config.qwertyLayoutModeRaw, QwertyLayoutMode.automatic.rawValue)
        XCTAssertEqual(config.numpadPlacementRaw, NumpadPlacement.automatic.rawValue)
    }

    func test_standardDefaultsAreProductionNotTestFixture() {
        let config = KeyboardProfile.Configuration.productionDefaults
        XCTAssertNotEqual(config, .testFixture, "Production defaults must not alias testFixture")
        XCTAssertEqual(config.keyboardTypeRaw, KeyboardType.default.rawValue)
        XCTAssertEqual(config.themeRaw, KeyboardTheme.white.rawValue)
        XCTAssertEqual(config.roundedCorners, false)
        XCTAssertEqual(config.qwertyAutocorrect, false)
        XCTAssertEqual(config.keyboardPageRaw, "numpad")
    }

    func test_builtInExactExpectedValues() {
        let standard = KeyboardProfileFactory.standard()
        XCTAssertEqual(standard.configuration, .productionDefaults)
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
