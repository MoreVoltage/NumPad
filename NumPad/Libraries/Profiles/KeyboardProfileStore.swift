//
//  KeyboardProfileStore.swift
//  NumPad
//

import Foundation

struct ProfileStoreSnapshot: Equatable {
    var profiles: [KeyboardProfile]
    var activeProfileID: UUID?
    var diagnostic: String?
    var hadCorruptData: Bool
}

struct KeyboardProfileStore {
    let defaults: UserDefaults
    var profilesKey: String = Constants.keyboardProfiles.rawValue
    var activeIDKey: String = Constants.activeKeyboardProfileID.rawValue
    var corruptBackupKey: String = Constants.keyboardProfilesCorruptBackup.rawValue

    func load() -> ProfileStoreSnapshot {
        let builtIns = KeyboardProfileFactory.builtIns()
        guard let data = defaults.data(forKey: profilesKey) else {
            return ProfileStoreSnapshot(
                profiles: builtIns,
                activeProfileID: nil,
                diagnostic: nil,
                hadCorruptData: false
            )
        }

        do {
            let decoded = try JSONDecoder().decode([KeyboardProfile].self, from: data)
            var supported: [KeyboardProfile] = []
            var sawUnsupported = false
            for profile in decoded {
                if profile.schemaVersion == KeyboardProfile.currentSchemaVersion {
                    supported.append(profile)
                } else {
                    sawUnsupported = true
                }
            }
            // Factory identities are refreshed from code. Any other identity is user/MDM-authored
            // and must survive regardless of its semantic kind (for example an embedded kiosk).
            let builtInIDs = Set(builtIns.map(\.id))
            let authored = supported.filter { !builtInIDs.contains($0.id) }
            let profiles = builtIns + authored
            let activeRaw = defaults.string(forKey: activeIDKey).flatMap(UUID.init(uuidString:))
            return ProfileStoreSnapshot(
                profiles: profiles,
                activeProfileID: activeRaw,
                diagnostic: sawUnsupported ? "Ignored unsupported future profile schema(s)" : nil,
                hadCorruptData: false
            )
        } catch {
            defaults.set(data, forKey: corruptBackupKey)
            return ProfileStoreSnapshot(
                profiles: builtIns,
                activeProfileID: nil,
                diagnostic: "Corrupt profile store preserved; using built-ins",
                hadCorruptData: true
            )
        }
    }

    func save(_ snapshot: ProfileStoreSnapshot) throws {
        // Persist customs + any edited copies; built-ins are always re-merged on load.
        let toEncode = snapshot.profiles.filter { profile in
            profile.kind == .custom || !KeyboardProfileFactory.builtIns().map(\.id).contains(profile.id)
        } + snapshot.profiles.filter { $0.kind != .custom }
        // Encode full list the UI knows about (built-ins + customs) for stable round-trips.
        let encoded = try JSONEncoder().encode(snapshot.profiles)
        // Validate every profile before committing.
        for profile in snapshot.profiles {
            _ = try profile.validated()
        }
        defaults.set(encoded, forKey: profilesKey)
        if let active = snapshot.activeProfileID {
            defaults.set(active.uuidString, forKey: activeIDKey)
        } else {
            defaults.removeObject(forKey: activeIDKey)
        }
        _ = toEncode // silence if unused — keep intentional filter for future pruning
    }

    func activeProfile() -> KeyboardProfile? {
        let snapshot = load()
        guard let id = snapshot.activeProfileID else { return nil }
        return snapshot.profiles.first { $0.id == id }
    }

    func replaceAndApply(
        _ profile: KeyboardProfile,
        previous: ProfileStoreSnapshot,
        applier: KeyboardProfileApplier,
        entitlements: ProfileEntitlements
    ) throws -> ApplyResult {
        let transactionKeys = Set(
            KeyboardProfileApplier.liveSettingKeys + [profilesKey, activeIDKey]
        )
        let priorValues = Dictionary(uniqueKeysWithValues: transactionKeys.map {
            ($0, defaults.object(forKey: $0))
        })

        do {
            var proposed = previous
            if let index = proposed.profiles.firstIndex(where: { $0.id == profile.id }) {
                proposed.profiles[index] = profile
            } else {
                proposed.profiles.append(profile)
            }
            try save(proposed)
            return try applier.apply(profile, entitlements: entitlements)
        } catch {
            applier.restore(priorValues)
            throw error
        }
    }
}
