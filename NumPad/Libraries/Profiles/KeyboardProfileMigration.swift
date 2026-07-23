//
//  KeyboardProfileMigration.swift
//  NumPad
//

import Foundation

enum KeyboardProfileMigration {
    static let currentVersion = 1

    /// Idempotent first-run migration. Snapshots current settings, seeds built-ins, activates
    /// the snapshot, and stamps the migration version. Re-running with the same defaults leaves
    /// profile state byte-equivalent.
    static func runIfNeeded(defaults: UserDefaults = .group) {
        let versionKey = Constants.keyboardProfileMigrationVersion.rawValue
        if defaults.integer(forKey: versionKey) >= currentVersion {
            return
        }

        let store = KeyboardProfileStore(defaults: defaults)
        let snapshot = KeyboardProfileFactory.snapshotCurrent(defaults: defaults)
        var profiles = KeyboardProfileFactory.builtIns()
        profiles.append(snapshot)

        let payload = ProfileStoreSnapshot(
            profiles: profiles,
            activeProfileID: snapshot.id,
            diagnostic: nil,
            hadCorruptData: false
        )
        try? store.save(payload)
        defaults.set(currentVersion, forKey: versionKey)
    }
}
