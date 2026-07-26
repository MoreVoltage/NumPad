//
//  KeyboardProfileMigration.swift
//  NumPad
//

import Foundation

enum KeyboardProfileMigration {
    static let currentVersion = 1

    enum Outcome: Equatable {
        case alreadyMigrated
        case migrated(activeID: UUID)
        case failed(String)
    }

    /// Idempotent first-run migration. Snapshots current settings, seeds built-ins, activates
    /// the snapshot, and stamps the migration version **only after a successful save**.
    @discardableResult
    static func runIfNeeded(defaults: UserDefaults = .group) -> Outcome {
        let versionKey = Constants.keyboardProfileMigrationVersion.rawValue
        if defaults.integer(forKey: versionKey) >= currentVersion {
            return .alreadyMigrated
        }

        let store = KeyboardProfileStore(defaults: defaults)
        // Loading first preserves any undecodable pre-migration bytes before `save` replaces them.
        _ = store.load()
        let snapshot = KeyboardProfileFactory.snapshotCurrent(defaults: defaults)
        var profiles = KeyboardProfileFactory.builtIns()
        profiles.append(snapshot)

        let payload = ProfileStoreSnapshot(
            profiles: profiles,
            activeProfileID: snapshot.id,
            diagnostic: nil,
            hadCorruptData: false
        )
        do {
            try store.save(payload)
            defaults.set(currentVersion, forKey: versionKey)
            defaults.removeObject(forKey: Constants.keyboardProfileMigrationDiagnostic.rawValue)
            return .migrated(activeID: snapshot.id)
        } catch {
            // Leave migration version unset so the next launch retries. Preserve a diagnostic
            // marker for support without claiming success.
            defaults.set(
                "migration_failed",
                forKey: Constants.keyboardProfileMigrationDiagnostic.rawValue
            )
            return .failed(String(describing: error))
        }
    }
}
