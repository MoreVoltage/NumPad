import Foundation

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
    static let editingLockedKey = "managedProfileEditingLocked"
    static let diagnosticKey = "managedProfileDiagnostic"

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

    @discardableResult
    func applyCurrentConfiguration() -> ManagedProfileApplicationResult {
        guard let dictionary = managedDefaults.dictionary(
            forKey: ManagedProfileConfiguration.managedKey
        ), !dictionary.isEmpty else {
            sharedDefaults.removeObject(forKey: Self.lastGoodDigestKey)
            sharedDefaults.removeObject(forKey: Self.diagnosticKey)
            sharedDefaults.set(false, forKey: Self.editingLockedKey)
            return .noConfiguration
        }

        let request: ManagedProfileRequest
        let digest: String
        do {
            switch ManagedProfileConfiguration.parse(dictionary) {
            case .success(let parsed):
                request = parsed
            case .failure:
                return reject()
            }
            digest = try ManagedProfileConfiguration.digest(dictionary)
        } catch {
            return reject()
        }

        if sharedDefaults.string(forKey: Self.lastGoodDigestKey) == digest {
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
            let result = try KeyboardProfileApplier(
                defaults: sharedDefaults,
                notify: notify,
                store: store
            ).apply(profile, entitlements: entitlements())
            sharedDefaults.set(digest, forKey: Self.lastGoodDigestKey)
            sharedDefaults.set(request.lockEditing, forKey: Self.editingLockedKey)
            sharedDefaults.removeObject(forKey: Self.diagnosticKey)
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
        return .rejected
    }
}
