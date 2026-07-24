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
}
