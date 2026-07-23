//
//  CloudSync+Profiles.swift
//  NumPad
//
//  App-only: after CloudSync mirrors portable keys, validate and transactionally apply the
//  selected remote profile. Rolls back the complete pre-pull snapshot on failure.
//

import Foundation

enum CloudSyncProfiles {
    typealias Apply = (
        KeyboardProfile,
        KeyboardProfileStore,
        ProfileEntitlements,
        () -> Void
    ) throws -> ApplyResult

    /// Install once at app launch. Safe to call repeatedly (idempotent assignment).
    static func install() {
        CloudSync.afterPull = { priorSnapshot in
            applyPulledProfile(
                priorSnapshot: priorSnapshot
            )
        }
    }

    @discardableResult
    static func applyPulledProfile(
        priorSnapshot: [String: Any?],
        defaults: UserDefaults = .group,
        entitlements: ProfileEntitlements = .live(),
        notify: @escaping () -> Void = {},
        apply injectedApply: Apply? = nil
    ) -> Bool {
        var rollback = Dictionary(uniqueKeysWithValues: KeyboardProfileApplier.liveSettingKeys.map {
            ($0, defaults.object(forKey: $0))
        })
        for key in CloudSync.syncedKeys {
            rollback[key] = priorSnapshot[key] ?? nil
        }

        do {
            let profilesKey = Constants.keyboardProfiles.rawValue
            let activeKey = Constants.activeKeyboardProfileID.rawValue
            let profilesChanged = !valuesEqual(
                defaults.object(forKey: profilesKey),
                priorSnapshot[profilesKey] ?? nil
            )
            let activeChanged = !valuesEqual(
                defaults.object(forKey: activeKey),
                priorSnapshot[activeKey] ?? nil
            )

            guard profilesChanged || activeChanged else {
                defaults.removeObject(forKey: Constants.keyboardProfileSyncDiagnostic.rawValue)
                notify()
                return true
            }

            guard
                let data = defaults.data(forKey: profilesKey),
                let activeRaw = defaults.string(forKey: activeKey),
                let activeID = UUID(uuidString: activeRaw)
            else {
                throw ProfileApplyError.persistence("invalid_pulled_profile_identity")
            }

            let decoded = try JSONDecoder().decode([KeyboardProfile].self, from: data)
            let validated = try decoded.map { profile -> KeyboardProfile in
                let profile = try profile.validated()
                if let custom = profile.configuration.customKeyboardConfig {
                    try CustomKeyboardProfileValidation.validate(custom)
                }
                return profile
            }
            guard let active = validated.first(where: { $0.id == activeID }) else {
                throw ProfileApplyError.persistence("missing_pulled_active_profile")
            }

            let store = KeyboardProfileStore(defaults: defaults)
            let apply = injectedApply ?? { profile, store, entitlements, notify in
                try KeyboardProfileApplier(defaults: defaults, notify: notify, store: store)
                    .apply(profile, entitlements: entitlements)
            }
            // Do not notify until the real apply result is accepted. Entitlement fallbacks are
            // safe for direct user activation, but a synced profile must be all-or-nothing.
            let result = try apply(active, store, entitlements, {})
            guard result.fallbacks.isEmpty else {
                throw ProfileApplyError.persistence("entitlement_fallback_rejected")
            }
            defaults.removeObject(forKey: Constants.keyboardProfileSyncDiagnostic.rawValue)
            notify()
            return true
        } catch {
            restore(rollback, defaults: defaults)
            defaults.set(
                "cloud_profile_pull_failed",
                forKey: Constants.keyboardProfileSyncDiagnostic.rawValue
            )
            return false
        }
    }

    private static func restore(_ values: [String: Any?], defaults: UserDefaults) {
        for (key, value) in values {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs as? NSObject, rhs as? NSObject) {
        case (nil, nil): return true
        case let (left?, right?): return left.isEqual(right)
        default: return false
        }
    }
}
