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
    static let editingLockedKey = "managedProfileEditingLocked"
    static let diagnosticKey = "managedProfileDiagnostic"
    static let stateDidChange = Notification.Name("managedProfileStateDidChange")

    private let managedDefaults: UserDefaults
    private let sharedDefaults: UserDefaults
    private let entitlements: () -> ProfileEntitlements
    private let notify: () -> Void

    init(
        managedDefaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults = .group,
        entitlements: @escaping () -> ProfileEntitlements = ProfileEntitlements.live,
        notify: @escaping () -> Void = { SettingsSync.post() }
    ) {
        self.managedDefaults = managedDefaults
        self.sharedDefaults = sharedDefaults
        self.entitlements = entitlements
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
                    ).utf8
                )
            )
        } catch {
            return reject()
        }

        if sharedDefaults.string(forKey: Self.lastGoodDigestKey) == digest,
           managedStateMatchesLastApplication() {
            return .unchanged
        }

        let profile: KeyboardProfile
        switch request.source {
        case .builtin(let kind):
            guard let builtIn = KeyboardProfileFactory.builtIns().first(where: { $0.kind == kind }) else {
                return reject()
            }
            profile = builtIn
        case .embedded(let embedded):
            profile = embedded
        }

        do {
            let store = KeyboardProfileStore(defaults: sharedDefaults)
            let applier = KeyboardProfileApplier(
                defaults: sharedDefaults,
                notify: notify,
                store: store
            )
            let appliedConfigurationDigest = try configurationDigest(
                applier.probe(profile, entitlements: currentEntitlements).appliedConfiguration
            )
            let result = try applier.apply(profile, entitlements: currentEntitlements)
            sharedDefaults.set(digest, forKey: Self.lastGoodDigestKey)
            sharedDefaults.set(profile.id.uuidString, forKey: Self.appliedProfileIDKey)
            sharedDefaults.set(
                appliedConfigurationDigest,
                forKey: Self.appliedConfigurationDigestKey
            )
            sharedDefaults.set(request.lockEditing, forKey: Self.editingLockedKey)
            sharedDefaults.removeObject(forKey: Self.diagnosticKey)
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

    private func managedStateMatchesLastApplication() -> Bool {
        guard
            sharedDefaults.string(forKey: Self.appliedProfileIDKey)
                == sharedDefaults.string(forKey: Constants.activeKeyboardProfileID.rawValue),
            let expected = sharedDefaults.string(forKey: Self.appliedConfigurationDigestKey),
            let actual = try? configurationDigest(
                KeyboardProfileFactory.snapshotCurrent(defaults: sharedDefaults).configuration
            )
        else { return false }
        return expected == actual
    }

    private func configurationDigest(_ configuration: KeyboardProfile.Configuration) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return hash(try encoder.encode(configuration))
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
