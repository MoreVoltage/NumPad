//
//  CloudSync+Profiles.swift
//  NumPad
//
//  App-only: after CloudSync mirrors profile keys, validate and transactionally apply the
//  selected remote profile. Rolls back identity/blob on apply failure.
//

import Foundation

enum CloudSyncProfiles {
    /// Install once at app launch. Safe to call repeatedly (idempotent assignment).
    static func install() {
        CloudSync.afterPull = { priorActiveID, priorProfilesBlob in
            applyPulledProfile(
                priorActiveID: priorActiveID,
                priorProfilesBlob: priorProfilesBlob
            )
        }
    }

    static func applyPulledProfile(
        priorActiveID: String?,
        priorProfilesBlob: Data?,
        defaults: UserDefaults = .group
    ) {
        let activeChanged = defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue) != priorActiveID
        let blobChanged = defaults.data(forKey: Constants.keyboardProfiles.rawValue) != priorProfilesBlob
        guard activeChanged || blobChanged else { return }

        let store = KeyboardProfileStore(defaults: defaults)
        guard let active = store.activeProfile() else { return }
        do {
            _ = try KeyboardProfileApplier(defaults: defaults, store: store)
                .apply(active, entitlements: .live())
        } catch {
            if let priorProfilesBlob {
                defaults.set(priorProfilesBlob, forKey: Constants.keyboardProfiles.rawValue)
            } else {
                defaults.removeObject(forKey: Constants.keyboardProfiles.rawValue)
            }
            if let priorActiveID {
                defaults.set(priorActiveID, forKey: Constants.activeKeyboardProfileID.rawValue)
            } else {
                defaults.removeObject(forKey: Constants.activeKeyboardProfileID.rawValue)
            }
        }
    }
}
