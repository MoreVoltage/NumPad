import XCTest
@testable import NumPad

final class ManagedProfileCoordinatorTests: XCTestCase {
    private var standardDefaults: UserDefaults!
    private var sharedDefaults: UserDefaults!
    private var standardSuite: String!
    private var sharedSuite: String!
    private var notifyCount = 0

    override func setUp() {
        super.setUp()
        standardSuite = "ManagedProfileCoordinatorTests.standard.\(UUID().uuidString)"
        sharedSuite = "ManagedProfileCoordinatorTests.shared.\(UUID().uuidString)"
        standardDefaults = UserDefaults(suiteName: standardSuite)!
        sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        standardDefaults.removePersistentDomain(forName: standardSuite)
        sharedDefaults.removePersistentDomain(forName: sharedSuite)
        notifyCount = 0
    }

    override func tearDown() {
        standardDefaults.removePersistentDomain(forName: standardSuite)
        sharedDefaults.removePersistentDomain(forName: sharedSuite)
        super.tearDown()
    }

    private func makeCoordinator(
        entitlements: ProfileEntitlements = ProfileEntitlements(
            paywallEnabled: false,
            proEntitled: true,
            kioskHeightEntitled: true,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: true,
            ownedPackProductIDs: []
        )
    ) -> ManagedProfileCoordinator {
        ManagedProfileCoordinator(
            managedDefaults: standardDefaults,
            sharedDefaults: sharedDefaults,
            entitlements: { entitlements },
            notify: { [weak self] in self?.notifyCount += 1 }
        )
    }

    func test_appliesBuiltInThenSkipsUnchangedDigest() {
        standardDefaults.set([
            "builtin_profile_kind": "writing",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()

        guard case .applied(let first) = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Expected first application")
        }
        XCTAssertEqual(first.appliedConfiguration.keyboardPageRaw, "qwerty")
        XCTAssertTrue(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        XCTAssertEqual(notifyCount, 1)

        XCTAssertEqual(coordinator.applyCurrentConfiguration(), .unchanged)
        XCTAssertEqual(notifyCount, 1)
    }

    func test_changedDigestAppliesEmbeddedDocument() throws {
        standardDefaults.set(
            ["builtin_profile_kind": "standard"],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Expected initial application")
        }

        var embedded = KeyboardProfile.testFixture
        embedded.id = UUID()
        let json = String(decoding: try KeyboardProfileDocument.encode(embedded), as: UTF8.self)
        standardDefaults.set(
            ["profile_json": json, "lock_profile_editing": false],
            forKey: ManagedProfileConfiguration.managedKey
        )

        guard case .applied(let changed) = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Expected changed configuration application")
        }
        XCTAssertEqual(changed.appliedConfiguration.keyboardTypeRaw, embedded.configuration.keyboardTypeRaw)
        XCTAssertFalse(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        XCTAssertEqual(notifyCount, 2)
    }

    func test_invalidChangedPayloadPreservesLastGoodProfileDigestAndLock() {
        standardDefaults.set([
            "builtin_profile_kind": "standard",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Expected initial application")
        }
        let activeBefore = KeyboardProfileStore(defaults: sharedDefaults).load().activeProfileID
        let digestBefore = sharedDefaults.string(forKey: ManagedProfileCoordinator.lastGoodDigestKey)

        standardDefaults.set(
            ["profile_json": "{\"typed\":\"secret\"}", "lock_profile_editing": false],
            forKey: ManagedProfileConfiguration.managedKey
        )

        XCTAssertEqual(coordinator.applyCurrentConfiguration(), .rejected)
        XCTAssertEqual(KeyboardProfileStore(defaults: sharedDefaults).load().activeProfileID, activeBefore)
        XCTAssertEqual(sharedDefaults.string(forKey: ManagedProfileCoordinator.lastGoodDigestKey), digestBefore)
        XCTAssertTrue(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        let diagnostic = sharedDefaults.string(forKey: ManagedProfileCoordinator.diagnosticKey)
        XCTAssertEqual(diagnostic, "Managed profile configuration was not applied.")
        XCTAssertFalse(diagnostic?.contains("secret") == true)
    }

    func test_entitlementFallbackUsesApplierAndRecordsSuccessfulDigest() {
        standardDefaults.set(
            ["builtin_profile_kind": "kiosk"],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator(entitlements: ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        ))

        guard case .applied(let result) = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Expected managed profile with fallback")
        }
        XCTAssertTrue(result.fallbacks.contains(.heightKioskToTall))
        XCTAssertEqual(result.appliedConfiguration.heightRaw, KeyboardHeightPreset.tall.rawValue)
        XCTAssertNotNil(sharedDefaults.string(forKey: ManagedProfileCoordinator.lastGoodDigestKey))
    }

    func test_removingManagementUnlocksEditingWithoutChangingLastAppliedProfile() {
        standardDefaults.set([
            "builtin_profile_kind": "standard",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        let active = KeyboardProfileStore(defaults: sharedDefaults).load().activeProfileID
        standardDefaults.removeObject(forKey: ManagedProfileConfiguration.managedKey)

        XCTAssertEqual(coordinator.applyCurrentConfiguration(), .noConfiguration)
        XCTAssertFalse(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        XCTAssertEqual(KeyboardProfileStore(defaults: sharedDefaults).load().activeProfileID, active)
    }

    func test_profileEditorDeclaresEveryAuthoredConfigurationAndKioskField() {
        XCTAssertEqual(
            ProfileEditorViewController.editableFields,
            Set(ProfileEditorField.allCases)
        )
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.customLayout))
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.handedness))
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.qwertyLayoutMode))
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.numpadPlacement))
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.kioskTimeout))
        XCTAssertTrue(ProfileEditorViewController.editableFields.contains(.kioskAdministratorAuthentication))
    }

    func test_unchangedConfigurationRepairsActiveProfileDrift() {
        standardDefaults.set([
            "builtin_profile_kind": "writing",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        sharedDefaults.set(
            KeyboardProfileFactory.BuiltInID.finance.uuidString,
            forKey: Constants.activeKeyboardProfileID.rawValue
        )

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Digest match must still repair managed state drift")
        }
        XCTAssertEqual(
            KeyboardProfileStore(defaults: sharedDefaults).load().activeProfileID,
            KeyboardProfileFactory.BuiltInID.writing
        )
        XCTAssertEqual(notifyCount, 2)
    }

    func test_sameJSONReappliesWhenFallbackRelevantEntitlementsChange() {
        standardDefaults.set([
            "builtin_profile_kind": "kiosk",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        var liveEntitlements = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )
        let coordinator = ManagedProfileCoordinator(
            managedDefaults: standardDefaults,
            sharedDefaults: sharedDefaults,
            entitlements: { liveEntitlements },
            notify: { [weak self] in self?.notifyCount += 1 }
        )
        guard case .applied(let first) = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        XCTAssertEqual(first.appliedConfiguration.heightRaw, KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(coordinator.applyCurrentConfiguration(), .unchanged)

        liveEntitlements = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: true,
            kioskHeightEntitled: true,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: true,
            ownedPackProductIDs: Set(ProductCatalog.allPackProductIDs)
        )
        guard case .applied(let upgraded) = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Entitlement fingerprint change must reconcile")
        }
        XCTAssertEqual(upgraded.appliedConfiguration.heightRaw, KeyboardHeightPreset.kiosk.rawValue)
        XCTAssertEqual(notifyCount, 2)
    }

    func test_randomUUIDEmbeddedKioskPersistsResolvableIdentityAndPolicy() throws {
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.id = UUID()
        kiosk.name = "Fleet Kiosk"
        let json = String(decoding: try KeyboardProfileDocument.encode(kiosk), as: UTF8.self)
        standardDefaults.set(
            ["profile_json": json, "lock_profile_editing": true],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator()

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }

        XCTAssertEqual(KeyboardProfileStore(defaults: sharedDefaults).activeProfile(), kiosk)
        XCTAssertEqual(
            KioskSessionPolicy.activeConfiguration(defaults: sharedDefaults)?.activeProfileID,
            kiosk.id
        )
    }

    func test_editorSwitchMutationIsDeliveredBySave() throws {
        var profile = KeyboardProfile.testFixture
        profile.configuration.repurposeNextKey = true
        let editor = ProfileEditorViewController(profile: profile)
        let nav = UINavigationController(rootViewController: editor)
        editor.loadViewIfNeeded()
        _ = nav.view
        let cell = editor.tableView(
            editor.tableView,
            cellForRowAt: IndexPath(row: 0, section: 4)
        ) as! SwitchCell
        cell.switchView.setOn(false, animated: false)
        cell.switchView.sendActions(for: .valueChanged)
        var saved: KeyboardProfile?
        editor.onSave = {
            saved = $0
            return .failure(ProfileApplyError.persistence("keep visible"))
        }

        let save = try XCTUnwrap(editor.navigationItem.rightBarButtonItem)
        let action = try XCTUnwrap(save.action)
        UIApplication.shared.sendAction(
            action,
            to: save.target,
            from: save,
            for: nil
        )

        XCTAssertEqual(saved?.configuration.repurposeNextKey, false)
        XCTAssertTrue(nav.topViewController === editor, "Failed save must keep editor visible")
    }

    func test_managedApplicationAndRemovalPublishLiveStateChanges() {
        let changed = expectation(description: "managed state changed")
        changed.expectedFulfillmentCount = 2
        let observer = NotificationCenter.default.addObserver(
            forName: ManagedProfileCoordinator.stateDidChange,
            object: nil,
            queue: .main
        ) { _ in changed.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }
        standardDefaults.set(
            ["builtin_profile_kind": "standard"],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator()

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        standardDefaults.removeObject(forKey: ManagedProfileConfiguration.managedKey)
        XCTAssertEqual(coordinator.applyCurrentConfiguration(), .noConfiguration)

        wait(for: [changed], timeout: 1)
    }

    func test_commitMarkerMissingRepairsInterruptedMetadataWrite() {
        standardDefaults.set([
            "builtin_profile_kind": "writing",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        sharedDefaults.removeObject(forKey: ManagedProfileCoordinator.lastGoodDigestKey)
        sharedDefaults.set(false, forKey: ManagedProfileCoordinator.editingLockedKey)
        sharedDefaults.set("stale", forKey: ManagedProfileCoordinator.diagnosticKey)

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Missing commit marker must force full reconciliation")
        }

        XCTAssertNotNil(
            sharedDefaults.string(forKey: ManagedProfileCoordinator.lastGoodDigestKey)
        )
        XCTAssertTrue(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        XCTAssertNil(sharedDefaults.object(forKey: ManagedProfileCoordinator.diagnosticKey))
        XCTAssertEqual(notifyCount, 2)
    }

    func test_unchangedDigestRepairsLockAndDiagnosticDrift() {
        standardDefaults.set([
            "builtin_profile_kind": "standard",
            "lock_profile_editing": true
        ], forKey: ManagedProfileConfiguration.managedKey)
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        sharedDefaults.set(false, forKey: ManagedProfileCoordinator.editingLockedKey)
        sharedDefaults.set("partial-write", forKey: ManagedProfileCoordinator.diagnosticKey)

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Lock/diagnostic drift must invalidate unchanged reconciliation")
        }

        XCTAssertTrue(ManagedProfileCoordinator.isEditingLocked(defaults: sharedDefaults))
        XCTAssertNil(sharedDefaults.object(forKey: ManagedProfileCoordinator.diagnosticKey))
        XCTAssertEqual(notifyCount, 2)
    }

    func test_policyOnlyPersistedProfileDriftIsRepaired() throws {
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.id = UUID()
        kiosk.name = "Managed Policy"
        kiosk.kioskPolicy?.inactivityTimeout = 180
        kiosk.kioskPolicy?.resetPageAndPack = true
        let json = String(decoding: try KeyboardProfileDocument.encode(kiosk), as: UTF8.self)
        standardDefaults.set(
            ["profile_json": json, "lock_profile_editing": true],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator()
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }

        let store = KeyboardProfileStore(defaults: sharedDefaults)
        var drifted = store.load()
        let index = try XCTUnwrap(drifted.profiles.firstIndex(where: { $0.id == kiosk.id }))
        drifted.profiles[index].kioskPolicy?.inactivityTimeout = 900
        drifted.profiles[index].kioskPolicy?.resetPageAndPack = false
        try store.save(drifted)

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail("Policy-only profile drift must reconcile on foreground")
        }
        XCTAssertEqual(store.activeProfile()?.kioskPolicy, kiosk.kioskPolicy)
        XCTAssertEqual(
            KioskSessionPolicy.activeConfiguration(defaults: sharedDefaults)?.policy,
            kiosk.kioskPolicy
        )
    }

    func test_reservedFactoryUUIDEmbeddedKioskGetsStableManagedIdentity() throws {
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.name = "Customized Factory Identity"
        kiosk.kioskPolicy?.inactivityTimeout = 300
        kiosk.kioskPolicy?.clearClipboardHistory = false
        let json = String(decoding: try KeyboardProfileDocument.encode(kiosk), as: UTF8.self)
        standardDefaults.set(
            ["profile_json": json, "lock_profile_editing": true],
            forKey: ManagedProfileConfiguration.managedKey
        )
        let coordinator = makeCoordinator()

        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        let first = try XCTUnwrap(KeyboardProfileStore(defaults: sharedDefaults).activeProfile())
        XCTAssertNotEqual(first.id, KeyboardProfileFactory.BuiltInID.kiosk)
        XCTAssertEqual(first.name, kiosk.name)
        XCTAssertEqual(first.kind, .kiosk)
        XCTAssertEqual(first.configuration, kiosk.configuration)
        XCTAssertEqual(first.kioskPolicy, kiosk.kioskPolicy)
        XCTAssertEqual(
            KioskSessionPolicy.activeConfiguration(defaults: sharedDefaults)?.activeProfileID,
            first.id
        )

        sharedDefaults.removeObject(forKey: ManagedProfileCoordinator.lastGoodDigestKey)
        guard case .applied = coordinator.applyCurrentConfiguration() else {
            return XCTFail()
        }
        XCTAssertEqual(
            KeyboardProfileStore(defaults: sharedDefaults).activeProfile()?.id,
            first.id,
            "Managed identity remapping must be deterministic across reconciliation"
        )
    }

    func test_duplicatedKioskCanBeEditedSavedActivatedAndEnforced() throws {
        let copiedID = UUID()
        let copy = ProfileDuplicationPolicy.makeCopy(
            of: KeyboardProfileFactory.kiosk(),
            id: copiedID
        )
        XCTAssertEqual(copy.kind, .kiosk)
        XCTAssertNotNil(copy.kioskPolicy)

        let editor = ProfileEditorViewController(profile: copy)
        let navigation = UINavigationController(rootViewController: editor)
        editor.loadViewIfNeeded()
        _ = navigation.view
        let dismissCell = editor.tableView(
            editor.tableView,
            cellForRowAt: IndexPath(row: 3, section: 6)
        ) as! SwitchCell
        XCTAssertTrue(dismissCell.switchView.isEnabled)
        dismissCell.switchView.setOn(false, animated: false)
        dismissCell.switchView.sendActions(for: .valueChanged)
        var saved: KeyboardProfile?
        editor.onSave = {
            saved = $0
            return .failure(ProfileApplyError.persistence("keep visible"))
        }
        let save = try XCTUnwrap(editor.navigationItem.rightBarButtonItem)
        UIApplication.shared.sendAction(
            try XCTUnwrap(save.action),
            to: save.target,
            from: save,
            for: nil
        )
        let edited = try XCTUnwrap(saved)
        XCTAssertFalse(try XCTUnwrap(edited.kioskPolicy).dismissOverlays)

        _ = try KeyboardProfileApplier(
            defaults: sharedDefaults,
            notify: {},
            store: KeyboardProfileStore(defaults: sharedDefaults)
        ).apply(edited, entitlements: makeCoordinatorEntitlements())

        let active = try XCTUnwrap(
            KioskSessionPolicy.activeConfiguration(defaults: sharedDefaults)
        )
        XCTAssertEqual(active.activeProfileID, copiedID)
        XCTAssertFalse(active.policy.dismissOverlays)
    }

    func test_nonKioskEditorCannotAuthorUnenforceableKioskPolicy() {
        let editor = ProfileEditorViewController(profile: .testFixture)
        editor.loadViewIfNeeded()
        let enableCell = editor.tableView(
            editor.tableView,
            cellForRowAt: IndexPath(row: 0, section: 6)
        ) as! SwitchCell

        XCTAssertFalse(enableCell.switchView.isEnabled)
        XCTAssertFalse(enableCell.switchView.isOn)
    }

    private func makeCoordinatorEntitlements() -> ProfileEntitlements {
        ProfileEntitlements(
            paywallEnabled: false,
            proEntitled: true,
            kioskHeightEntitled: true,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: true,
            ownedPackProductIDs: []
        )
    }
}
