//
//  StudioSavedSetupPresentationTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioSavedSetupPresentationTests: XCTestCase {
    func test_builtInsUsePlainLanguageNamesDescriptionsAndStableFactoryIDs() {
        let items = StudioSavedSetupPresentation.builtIns(qwertyAvailable: true)

        XCTAssertEqual(
            items.map(\.name),
            [
                "Everyday numbers",
                "Calculator",
                "Prices & payments",
                "Measurements",
                "Writing",
                "Easy to see",
                "Kiosk"
            ]
        )
        XCTAssertEqual(
            items.map(\.detail),
            [
                "A clean NumPad for forms, codes, and ordinary number entry",
                "Math operators, calculator number order, regular-height keys",
                "Currency and finance keys",
                "Units and conversion keys",
                "Letters page and suggestions",
                "Taller, high-contrast keys with stronger sound and vibration",
                "Shared-use setup that clears session state after inactivity"
            ]
        )
        XCTAssertEqual(items.map(\.profile.id), KeyboardProfileFactory.builtIns().map(\.id))
    }

    func test_writingSetupIsOnlyVisibleWhenTheQwertyPageGatePermitsIt() {
        XCTAssertFalse(
            StudioSavedSetupPresentation.builtIns(qwertyAvailable: false)
                .contains { $0.profile.kind == .writing }
        )
        XCTAssertTrue(
            StudioSavedSetupPresentation.builtIns(qwertyAvailable: true)
                .contains { $0.profile.kind == .writing }
        )
    }

    func test_managedSettingsVisibilityUsesManagedOwnershipRatherThanEditingLock() {
        XCTAssertFalse(StudioAdvancedPresentation.showsManagedSettings(hasManagedOwnership: false))
        XCTAssertTrue(StudioAdvancedPresentation.showsManagedSettings(hasManagedOwnership: true))
    }

    func test_projectedSetupSummaryUsesProbeAndDoesNotWriteLiveSettings() throws {
        let suiteName = "saved-setup-presentation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(KeyboardType.default.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        let before = KeyboardProfileApplier.liveSettingKeys.reduce(into: [String: Any]()) { result, key in
            result[key] = defaults.object(forKey: key)
        }
        var applier = KeyboardProfileApplier(defaults: defaults, notify: {})
        applier.qwertyRemoteEnabled = { false }
        let locked = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )

        let summary = try StudioSavedSetupPresentation.projectedSummary(
            for: KeyboardProfileFactory.kiosk(),
            idiom: .phone,
            applier: applier,
            entitlements: locked
        )

        XCTAssertEqual(summary.preview.heightPreset, .tall)
        XCTAssertTrue(summary.changes.contains { $0.label == "Key height" && $0.value == "Tall" })
        XCTAssertTrue(summary.fallbacks.contains(.heightKioskToTall))
        let after = KeyboardProfileApplier.liveSettingKeys.reduce(into: [String: Any]()) { result, key in
            result[key] = defaults.object(forKey: key)
        }
        XCTAssertEqual(after as NSDictionary, before as NSDictionary)
    }

    func test_kioskModeGuardRequiresProOnlyForKioskSetups() {
        XCTAssertFalse(KioskModeAccess.allows(kind: .kiosk, proEntitled: false))
        XCTAssertTrue(KioskModeAccess.allows(kind: .kiosk, proEntitled: true))
        XCTAssertTrue(KioskModeAccess.allows(kind: .standard, proEntitled: false))
    }

    func test_unentitledKioskApplyDoesNotWriteAnyKeyboardOrPolicyState() throws {
        let suiteName = "saved-setup-kiosk-apply-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unchanged", forKey: Constants.selectedKeyboardType.rawValue)
        let before = KeyboardProfileApplier.transactionSettingKeys.reduce(into: [String: Any]()) { result, key in result[key] = defaults.object(forKey: key) }
        let unentitled = ProfileEntitlements(paywallEnabled: true, proEntitled: false, kioskHeightEntitled: false, customKeyboardEntitled: false, fullKeyboardEntitled: false, ownedPackProductIDs: [])

        XCTAssertThrowsError(try KeyboardProfileApplier(defaults: defaults, notify: {}).apply(KeyboardProfileFactory.kiosk(), entitlements: unentitled))

        let after = KeyboardProfileApplier.transactionSettingKeys.reduce(into: [String: Any]()) { result, key in result[key] = defaults.object(forKey: key) }
        XCTAssertEqual(after as NSDictionary, before as NSDictionary)
    }

    func test_entitledKioskApplyContinuesToWriteTheKioskSetup() throws {
        let suiteName = "saved-setup-kiosk-entitled-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entitled = ProfileEntitlements(paywallEnabled: true, proEntitled: true, kioskHeightEntitled: true, customKeyboardEntitled: true, fullKeyboardEntitled: true, ownedPackProductIDs: [])

        let result = try KeyboardProfileApplier(defaults: defaults, notify: {}).apply(KeyboardProfileFactory.kiosk(), entitlements: entitled)

        XCTAssertEqual(result.appliedConfiguration.heightRaw, KeyboardHeightPreset.kiosk.rawValue)
        XCTAssertEqual(defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue), KeyboardProfileFactory.kiosk().id.uuidString)
    }

    func test_unentitledKioskImportIsNotSaved() throws {
        let suiteName = "saved-setup-kiosk-import-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KeyboardProfileStore(defaults: defaults)
        let coordinator = ProfileImportCoordinator(store: store)
        let before = store.load()

        XCTAssertThrowsError(try coordinator.storePreparedProfile(KeyboardProfileFactory.kiosk(), proEntitled: false))

        XCTAssertEqual(store.load(), before)
    }
}
