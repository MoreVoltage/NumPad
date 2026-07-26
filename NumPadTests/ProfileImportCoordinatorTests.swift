import XCTest
@testable import NumPad

final class ProfileImportCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProfileImportCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_importUsesSecurityScopeAndStoresValidatedCustomProfile() throws {
        let url = URL(fileURLWithPath: "/tmp/profile.numpadprofile")
        let data = try KeyboardProfileDocument.encode(.testFixture)
        var starts = 0
        var stops = 0
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults),
            makeUUID: { UUID(uuidString: "11111111-2222-4333-8444-555555555555")! },
            startSecurityScope: { scopedURL in
                XCTAssertEqual(scopedURL, url)
                starts += 1
                return true
            },
            stopSecurityScope: { scopedURL in
                XCTAssertEqual(scopedURL, url)
                stops += 1
            },
            loadData: { loadedURL in
                XCTAssertEqual(loadedURL, url)
                return data
            }
        )

        let imported = try coordinator.importProfile(at: url)

        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(imported.id, KeyboardProfile.testFixture.id)
        XCTAssertEqual(imported.kind, .custom)
        XCTAssertTrue(
            KeyboardProfileStore(defaults: defaults).load().profiles.contains(where: { $0.id == imported.id })
        )
    }

    func test_duplicateUUIDGetsFreshIDAndLocalizedCopyNameWithoutOverwrite() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var existing = KeyboardProfile.testFixture
        existing.name = "Existing"
        try store.save(ProfileStoreSnapshot(
            profiles: KeyboardProfileFactory.builtIns() + [existing],
            activeProfileID: nil,
            diagnostic: nil,
            hadCorruptData: false
        ))
        let freshID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let coordinator = ProfileImportCoordinator(store: store, makeUUID: { freshID })

        let imported = try coordinator.importProfile(data: KeyboardProfileDocument.encode(.testFixture))
        let snapshot = store.load()

        XCTAssertEqual(imported.id, freshID)
        XCTAssertEqual(imported.name, "Test Profile Copy")
        XCTAssertEqual(snapshot.profiles.first(where: { $0.id == existing.id })?.name, "Existing")
        XCTAssertEqual(snapshot.profiles.first(where: { $0.id == freshID })?.name, "Test Profile Copy")
    }

    func test_rejectsOversizedAndForbiddenDocumentsWithoutStorageMutation() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        let before = store.load()
        let coordinator = ProfileImportCoordinator(store: store)

        XCTAssertThrowsError(
            try coordinator.importProfile(
                data: Data(repeating: 0x41, count: KeyboardProfileDocument.maxBytes + 1)
            )
        )
        let valid = try KeyboardProfileDocument.encode(.testFixture)
        var forbiddenRoot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        forbiddenRoot["telemetry"] = ["typed": "secret"]
        let forbidden = try JSONSerialization.data(withJSONObject: forbiddenRoot)
        XCTAssertThrowsError(try coordinator.importProfile(data: forbidden)) { error in
            XCTAssertEqual(
                error as? ProfileDocumentUserError,
                .invalidDocument
            )
        }
        XCTAssertEqual(store.load().profiles, before.profiles)
    }

    func test_exportIsValidatedAndCanBeReimportedWithoutPrivateStores() throws {
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        )
        let exported = try coordinator.exportData(for: .testFixture)
        let json = String(decoding: exported, as: UTF8.self)

        XCTAssertFalse(json.contains("isProPurchased"))
        XCTAssertFalse(json.contains("clipboardEntries"))
        XCTAssertFalse(json.contains("telemetry"))
        XCTAssertFalse(json.contains("qwertyPersonalDictionary"))
        let imported = try coordinator.importProfile(data: exported)
        XCTAssertEqual(imported.configuration, KeyboardProfile.testFixture.configuration)
    }

    func test_preparationDoesNotStoreUntilConfirmationCommit() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        let coordinator = ProfileImportCoordinator(store: store)
        let prepared = try coordinator.prepareImport(
            data: KeyboardProfileDocument.encode(.testFixture)
        )

        XCTAssertFalse(store.load().profiles.contains(where: { $0.id == prepared.id }))

        let stored = try coordinator.storePreparedProfile(prepared)
        XCTAssertTrue(store.load().profiles.contains(where: { $0.id == stored.id }))
        XCTAssertNil(store.load().activeProfileID, "Import must never auto-activate")
    }

    func test_activityExportCreatesNamedValidatedProfileDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileImportCoordinatorTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        )

        let url = try coordinator.makeExportFile(for: .testFixture, in: directory)

        XCTAssertEqual(url.pathExtension, "numpadprofile")
        XCTAssertEqual(
            try KeyboardProfileDocument.decodeAndValidate(Data(contentsOf: url)),
            KeyboardProfile.testFixture
        )
    }

    func test_hostileInvalidTokenMapsToBoundedLocalizedUserError() throws {
        var profile = KeyboardProfile.testFixture
        let attackerText = String(repeating: "ATTACKER", count: 2_000)
        profile.configuration.customKeyboardConfig = CustomKeyboardConfig(topRow: [attackerText])
        let raw = try JSONEncoder().encode(KeyboardProfileDocument(
            envelopeVersion: KeyboardProfileDocument.currentEnvelopeVersion,
            exportedAt: Date(),
            profile: profile
        ))
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        )

        XCTAssertThrowsError(try coordinator.prepareImport(data: raw)) { error in
            let userError = error as? ProfileDocumentUserError
            XCTAssertEqual(userError, .invalidDocument)
            XCTAssertLessThan(userError?.localizedDescription.count ?? .max, 160)
            XCTAssertFalse(userError?.localizedDescription.contains(attackerText) == true)
        }
    }

    func test_providerPathErrorMapsToGenericUnreadableMessage() {
        let secretPath = "/private/provider/customer-secret/Fleet.numpadprofile"
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults),
            loadData: { _ in
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileReadNoPermissionError,
                    userInfo: [NSFilePathErrorKey: secretPath]
                )
            }
        )

        XCTAssertThrowsError(
            try coordinator.prepareImport(at: URL(fileURLWithPath: secretPath))
        ) { error in
            XCTAssertEqual(error as? ProfileDocumentUserError, .unreadableDocument)
            XCTAssertFalse(error.localizedDescription.contains(secretPath))
        }
    }

    func test_exportArtifactCleanupIsDeterministic() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileArtifact-\(UUID().uuidString)")
        var artifact: ProfileExportArtifact? = try ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        ).makeExportArtifact(for: .testFixture, in: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact!.fileURL.path))

        artifact?.cleanup()
        artifact = nil

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func test_defaultReaderNeverLoadsPastDocumentLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileBoundedRead-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Oversized.numpadprofile")
        try Data(
            repeating: 0x41,
            count: KeyboardProfileDocument.maxBytes * 4
        ).write(to: url)
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults),
            startSecurityScope: { _ in false }
        )

        XCTAssertThrowsError(try coordinator.prepareImport(at: url)) { error in
            XCTAssertEqual(error as? ProfileDocumentUserError, .tooLarge)
        }
    }

    func test_abandonedExportArtifactCleansDirectoryOnRelease() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileAbandonedArtifact-\(UUID().uuidString)")
        var artifact: ProfileExportArtifact? = try ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        ).makeExportArtifact(for: .testFixture, in: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact!.fileURL.path))

        artifact = nil

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func test_importedKioskRetainsEnforceableSemanticKind() throws {
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.id = UUID()
        kiosk.name = "Imported Kiosk"
        let coordinator = ProfileImportCoordinator(
            store: KeyboardProfileStore(defaults: defaults)
        )

        let imported = try coordinator.importProfile(
            data: KeyboardProfileDocument.encode(kiosk)
        )

        XCTAssertEqual(imported.kind, .kiosk)
        XCTAssertEqual(imported.kioskPolicy, kiosk.kioskPolicy)
    }
}
