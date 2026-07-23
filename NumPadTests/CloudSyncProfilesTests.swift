import XCTest
@testable import NumPad

final class CloudSyncProfilesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var notifyCount = 0

    override func setUp() {
        super.setUp()
        suiteName = "cloud-sync-profiles-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        notifyCount = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private var entitlements: ProfileEntitlements {
        ProfileEntitlements(
            paywallEnabled: false,
            proEntitled: true,
            kioskHeightEntitled: true,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: true,
            ownedPackProductIDs: Set(ProductCatalog.allPackProductIDs)
        )
    }

    private var lockedEntitlements: ProfileEntitlements {
        ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )
    }

    private func seedPriorState() throws -> (
        synced: [String: Any?],
        live: [String: Any?]
    ) {
        var profile = KeyboardProfile.testFixture
        profile.name = "Prior"
        profile.configuration.grid = true
        profile.configuration.themeRaw = KeyboardTheme.indigo.rawValue
        profile.configuration.customKeyboardConfig = CustomKeyboardConfig(topRow: ["1", "2"])
        var storeSnapshot = KeyboardProfileStore(defaults: defaults).load()
        storeSnapshot.profiles.append(profile)
        storeSnapshot.activeProfileID = profile.id
        try KeyboardProfileStore(defaults: defaults).save(storeSnapshot)
        _ = try KeyboardProfileApplier(defaults: defaults, notify: {})
            .apply(profile, entitlements: entitlements)

        defaults.set(["prior snippet"], forKey: Constants.snippets.rawValue)
        defaults.set(["prior pack"], forKey: Constants.customPackKeys.rawValue)
        defaults.set(["prior slot"], forKey: Constants.customKeySlots.rawValue)

        return (
            snapshot(keys: CloudSync.syncedKeys),
            snapshot(keys: KeyboardProfileApplier.liveSettingKeys)
        )
    }

    private func snapshot(keys: [String]) -> [String: Any?] {
        Dictionary(uniqueKeysWithValues: keys.map {
            ($0, defaults.object(forKey: $0))
        })
    }

    private func installRemoteMarkers() {
        for (index, key) in CloudSync.syncedKeys.enumerated() {
            defaults.set("remote-\(index)", forKey: key)
        }
    }

    private func assertRestored(
        synced: [String: Any?],
        live: [String: Any?],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for key in CloudSync.syncedKeys {
            let expected = synced[key] ?? nil
            XCTAssertEqual(
                defaults.object(forKey: key) as? NSObject,
                expected as? NSObject,
                "Synced key was not rolled back: \(key)",
                file: file,
                line: line
            )
        }
        for key in KeyboardProfileApplier.liveSettingKeys {
            let expected = live[key] ?? nil
            XCTAssertEqual(
                defaults.object(forKey: key) as? NSObject,
                expected as? NSObject,
                "Live key was not rolled back: \(key)",
                file: file,
                line: line
            )
        }
        XCTAssertEqual(notifyCount, 0, file: file, line: line)
    }

    func test_missingActiveUUIDRestoresEverySyncedAndLiveValue() throws {
        let prior = try seedPriorState()
        installRemoteMarkers()
        let remote = KeyboardProfileFactory.finance()
        defaults.set(try JSONEncoder().encode([remote]), forKey: Constants.keyboardProfiles.rawValue)
        defaults.set(UUID().uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: entitlements,
            notify: { self.notifyCount += 1 }
        )

        XCTAssertFalse(succeeded)
        assertRestored(synced: prior.synced, live: prior.live)
        XCTAssertEqual(
            defaults.string(forKey: Constants.keyboardProfileSyncDiagnostic.rawValue),
            "cloud_profile_pull_failed"
        )
    }

    func test_corruptBlobRestoresEverySyncedAndLiveValue() throws {
        let prior = try seedPriorState()
        installRemoteMarkers()
        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: Constants.keyboardProfiles.rawValue)
        defaults.set(
            KeyboardProfileFactory.BuiltInID.finance.uuidString,
            forKey: Constants.activeKeyboardProfileID.rawValue
        )

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: entitlements,
            notify: { self.notifyCount += 1 }
        )

        XCTAssertFalse(succeeded)
        assertRestored(synced: prior.synced, live: prior.live)
    }

    func test_invalidCustomLayoutRestoresEverySyncedAndLiveValue() throws {
        let prior = try seedPriorState()
        installRemoteMarkers()
        var invalid = KeyboardProfile.testFixture
        invalid.id = UUID()
        invalid.configuration.customKeyboardConfig = CustomKeyboardConfig(
            topRow: Array(repeating: "1", count: CustomKeyboardEditorModel.topRowCapacity + 1)
        )
        defaults.set(try JSONEncoder().encode([invalid]), forKey: Constants.keyboardProfiles.rawValue)
        defaults.set(invalid.id.uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: entitlements,
            notify: { self.notifyCount += 1 }
        )

        XCTAssertFalse(succeeded)
        assertRestored(synced: prior.synced, live: prior.live)
    }

    func test_applicationErrorRestoresEverySyncedAndLiveValue() throws {
        let prior = try seedPriorState()
        installRemoteMarkers()
        var remote = KeyboardProfile.testFixture
        remote.id = UUID()
        defaults.set(try JSONEncoder().encode([remote]), forKey: Constants.keyboardProfiles.rawValue)
        defaults.set(remote.id.uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: entitlements,
            notify: { self.notifyCount += 1 },
            apply: { _, _, _, _ in
                self.defaults.set(false, forKey: Constants.grid.rawValue)
                throw ProfileApplyError.persistence("injected")
            }
        )

        XCTAssertFalse(succeeded)
        assertRestored(synced: prior.synced, live: prior.live)
    }

    func test_lockedProfileFallbackRejectsPullAndRestoresEverySyncedAndLiveValue() throws {
        let prior = try seedPriorState()
        installRemoteMarkers()
        let remote = KeyboardProfileFactory.finance()
        defaults.set(try JSONEncoder().encode([remote]), forKey: Constants.keyboardProfiles.rawValue)
        defaults.set(remote.id.uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: lockedEntitlements,
            notify: { self.notifyCount += 1 }
        )

        XCTAssertFalse(succeeded)
        assertRestored(synced: prior.synced, live: prior.live)
        XCTAssertEqual(
            defaults.string(forKey: Constants.keyboardProfileSyncDiagnostic.rawValue),
            "cloud_profile_pull_failed"
        )
    }

    func test_successUsesProductionApplierPersistsSelectedProfileAndNotifiesOnce() throws {
        let prior = try seedPriorState()
        var remote = KeyboardProfile.testFixture
        remote.id = UUID()
        remote.name = "Remote"
        remote.configuration.keyboardTypeRaw = KeyboardType.symbols.rawValue
        remote.configuration.themeRaw = KeyboardTheme.black.rawValue
        remote.configuration.heightRaw = KeyboardHeightPreset.tall.rawValue
        remote.configuration.grid = false
        remote.configuration.customKeyboardConfig = CustomKeyboardConfig(
            name: "Remote Custom",
            topRow: ["1", "2", "3"]
        )
        let remoteBlob = try JSONEncoder().encode([remote])
        let remoteCustomData = try JSONEncoder().encode(remote.configuration.customKeyboardConfig)
        let remoteValues: [String: Any] = [
            Constants.snippets.rawValue: ["remote snippet"],
            Constants.customPackKeys.rawValue: ["remote pack"],
            Constants.customKeySlots.rawValue: ["remote slot"],
            Constants.selectedKeyboardTheme.rawValue: remote.configuration.themeRaw,
            Constants.heightPreset.rawValue: remote.configuration.heightRaw,
            Constants.customKeyboardConfig.rawValue: remoteCustomData,
            Constants.handedness.rawValue: remote.configuration.handednessRaw,
            Constants.keyboardProfiles.rawValue: remoteBlob,
            Constants.activeKeyboardProfileID.rawValue: remote.id.uuidString
        ]
        for (key, value) in remoteValues {
            defaults.set(value, forKey: key)
        }

        let succeeded = CloudSyncProfiles.applyPulledProfile(
            priorSnapshot: prior.synced,
            defaults: defaults,
            entitlements: entitlements,
            notify: { self.notifyCount += 1 }
        )

        XCTAssertTrue(succeeded)
        XCTAssertEqual(notifyCount, 1)
        let stored = KeyboardProfileStore(defaults: defaults).load()
        XCTAssertEqual(stored.activeProfileID, remote.id)
        XCTAssertEqual(stored.profiles.first(where: { $0.id == remote.id }), remote)
        XCTAssertEqual(
            defaults.string(forKey: Constants.selectedKeyboardType.rawValue),
            remote.configuration.keyboardTypeRaw
        )
        XCTAssertEqual(
            defaults.string(forKey: Constants.selectedKeyboardTheme.rawValue),
            remote.configuration.themeRaw
        )
        XCTAssertEqual(
            defaults.string(forKey: Constants.heightPreset.rawValue),
            remote.configuration.heightRaw
        )
        XCTAssertEqual(
            defaults.bool(forKey: Constants.grid.rawValue),
            remote.configuration.grid
        )
        XCTAssertEqual(
            CustomKeyboardStore(defaults: defaults).load(),
            remote.configuration.customKeyboardConfig
        )
        XCTAssertEqual(defaults.stringArray(forKey: Constants.snippets.rawValue), ["remote snippet"])
        XCTAssertEqual(defaults.stringArray(forKey: Constants.customPackKeys.rawValue), ["remote pack"])
        XCTAssertEqual(defaults.stringArray(forKey: Constants.customKeySlots.rawValue), ["remote slot"])
    }
}
