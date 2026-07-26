import Foundation
import CryptoKit

enum ManagedProfileApplicationResult: Equatable {
    case noConfiguration
    case unchanged
    case applied(ApplyResult)
    case rejected
}

/// Applies MDM/AppConfig profile requests at process launch and each foreground transition.
/// Only a fully parsed, validated and successfully applied request advances the last-good digest.
final class ManagedProfileCoordinator {
    static let lastGoodDigestKey = "managedProfileLastGoodDigest"
    static let appliedProfileIDKey = "managedProfileAppliedProfileID"
    static let appliedConfigurationDigestKey = "managedProfileAppliedConfigurationDigest"
    static let appliedProfileDigestKey = "managedProfileAppliedProfileDigest"
    static let editingLockedKey = "managedProfileEditingLocked"
    static let diagnosticKey = "managedProfileDiagnostic"
    static let stateDidChange = Notification.Name("managedProfileStateDidChange")

    private let managedDefaults: UserDefaults
    private let sharedDefaults: UserDefaults
    private let entitlements: () -> ProfileEntitlements
    private let qwertyRemoteEnabled: () -> Bool
    private let notify: () -> Void

    init(
        managedDefaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults = .group,
        entitlements: @escaping () -> ProfileEntitlements = ProfileEntitlements.live,
        qwertyRemoteEnabled: @escaping () -> Bool = { FeatureFlags.fullKeyboardRemoteEnabled },
        notify: @escaping () -> Void = { SettingsSync.post() }
    ) {
        self.managedDefaults = managedDefaults
        self.sharedDefaults = sharedDefaults
        self.entitlements = entitlements
        self.qwertyRemoteEnabled = qwertyRemoteEnabled
        self.notify = notify
    }

    static func isEditingLocked(defaults: UserDefaults = .group) -> Bool {
        defaults.bool(forKey: editingLockedKey)
    }

    static func hasManagedOwnership(defaults: UserDefaults = .group) -> Bool {
        defaults.string(forKey: lastGoodDigestKey) != nil
    }

    @discardableResult
    func applyCurrentConfiguration() -> ManagedProfileApplicationResult {
        guard let dictionary = managedDefaults.dictionary(
            forKey: ManagedProfileConfiguration.managedKey
        ), !dictionary.isEmpty else {
            let changed = Self.hasManagedOwnership(defaults: sharedDefaults)
                || sharedDefaults.bool(forKey: Self.editingLockedKey)
                || sharedDefaults.object(forKey: Self.diagnosticKey) != nil
            sharedDefaults.removeObject(forKey: Self.lastGoodDigestKey)
            sharedDefaults.removeObject(forKey: Self.appliedProfileIDKey)
            sharedDefaults.removeObject(forKey: Self.appliedConfigurationDigestKey)
            sharedDefaults.removeObject(forKey: Self.appliedProfileDigestKey)
            sharedDefaults.removeObject(forKey: Self.diagnosticKey)
            sharedDefaults.set(false, forKey: Self.editingLockedKey)
            if changed {
                NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
            }
            return .noConfiguration
        }

        let request: ManagedProfileRequest
        let digest: String
        let currentEntitlements = entitlements()
        // Sample Remote Config once. The same bit drives the reconciliation fingerprint and the
        // eventual apply, so a mid-pass update cannot make metadata describe a different result.
        let currentQwertyRemoteEnabled = qwertyRemoteEnabled()
        do {
            switch ManagedProfileConfiguration.parse(dictionary) {
            case .success(let parsed):
                request = parsed
            case .failure:
                return reject()
            }
            digest = hash(
                Data(
                    (
                        try ManagedProfileConfiguration.digest(dictionary)
                            + "|" + currentEntitlements.reconciliationFingerprint
                            + "|qwertyRemote=" + String(currentQwertyRemoteEnabled)
                    ).utf8
                )
            )
        } catch {
            return reject()
        }

        if sharedDefaults.string(forKey: Self.lastGoodDigestKey) == digest,
           managedStateMatchesLastApplication(expectedLock: request.lockEditing) {
            return .unchanged
        }

        let requestedProfile: KeyboardProfile
        switch request.source {
        case .builtin(let kind):
            guard let builtIn = KeyboardProfileFactory.builtIns().first(where: { $0.kind == kind }) else {
                return reject()
            }
            requestedProfile = builtIn
        case .embedded(let embedded):
            requestedProfile = embedded
        }

        do {
            let profile = try normalizedManagedProfile(requestedProfile, source: request.source)
            let store = KeyboardProfileStore(defaults: sharedDefaults)
            var applier = KeyboardProfileApplier(
                defaults: sharedDefaults,
                notify: notify,
                store: store
            )
            applier.qwertyRemoteEnabled = { currentQwertyRemoteEnabled }
            let appliedProfileDigest = try profileDigest(profile)
            let result = try applier.apply(profile, entitlements: currentEntitlements)
            let appliedConfigurationDigest = try configurationDigest(
                result.appliedConfiguration
            )

            // Metadata and user-visible state are persisted first. The digest is the commit
            // marker and must be last so an interrupted write can never look reconciled.
            sharedDefaults.removeObject(forKey: Self.lastGoodDigestKey)
            sharedDefaults.synchronize()
            sharedDefaults.set(profile.id.uuidString, forKey: Self.appliedProfileIDKey)
            sharedDefaults.set(
                appliedConfigurationDigest,
                forKey: Self.appliedConfigurationDigestKey
            )
            sharedDefaults.set(appliedProfileDigest, forKey: Self.appliedProfileDigestKey)
            sharedDefaults.set(request.lockEditing, forKey: Self.editingLockedKey)
            sharedDefaults.removeObject(forKey: Self.diagnosticKey)
            sharedDefaults.synchronize()
            sharedDefaults.set(digest, forKey: Self.lastGoodDigestKey)
            sharedDefaults.synchronize()
            NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
            return .applied(result)
        } catch {
            return reject()
        }
    }

    private func reject() -> ManagedProfileApplicationResult {
        // Deliberately generic: never echo managed JSON, profile names, tokens, or parser errors.
        sharedDefaults.set(
            NSLocalizedString(
                "Managed profile configuration was not applied.",
                comment: "Non-sensitive managed profile failure diagnostic"
            ),
            forKey: Self.diagnosticKey
        )
        NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
        return .rejected
    }

    private func managedStateMatchesLastApplication(expectedLock: Bool) -> Bool {
        guard
            sharedDefaults.string(forKey: Self.appliedProfileIDKey)
                == sharedDefaults.string(forKey: Constants.activeKeyboardProfileID.rawValue),
            sharedDefaults.object(forKey: Self.editingLockedKey) as? Bool == expectedLock,
            sharedDefaults.object(forKey: Self.diagnosticKey) == nil,
            let expectedConfiguration = sharedDefaults.string(
                forKey: Self.appliedConfigurationDigestKey
            ),
            let actualConfiguration = try? configurationDigest(
                KeyboardProfileFactory.snapshotCurrent(defaults: sharedDefaults).configuration
            ),
            let expectedProfile = sharedDefaults.string(forKey: Self.appliedProfileDigestKey),
            let activeProfile = KeyboardProfileStore(defaults: sharedDefaults).activeProfile(),
            let actualProfile = try? profileDigest(activeProfile)
        else { return false }
        return expectedConfiguration == actualConfiguration && expectedProfile == actualProfile
    }

    private func configurationDigest(_ configuration: KeyboardProfile.Configuration) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return hash(try encoder.encode(configuration))
    }

    private func profileDigest(_ profile: KeyboardProfile) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return hash(try encoder.encode(profile))
    }

    private func normalizedManagedProfile(
        _ profile: KeyboardProfile,
        source: ManagedProfileRequest.Source
    ) throws -> KeyboardProfile {
        guard case .embedded = source else { return profile }
        let reserved = Set(KeyboardProfileFactory.builtIns().map(\.id))
        guard reserved.contains(profile.id) else { return profile }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = Array(SHA256.hash(data: try encoder.encode(profile)))
        var bytes = Array(digest.prefix(16))
        // RFC 4122 name-based shape. The content hash is the stable namespace input.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        var copy = profile
        copy.id = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return copy
    }

    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension ProfileEntitlements {
    var reconciliationFingerprint: String {
        [
            paywallEnabled,
            proEntitled,
            kioskHeightEntitled,
            customKeyboardEntitled,
            fullKeyboardEntitled
        ].map { $0 ? "1" : "0" }.joined()
            + "|" + ownedPackProductIDs.sorted().joined(separator: ",")
    }
}
