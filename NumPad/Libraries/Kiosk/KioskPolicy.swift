//
//  KioskPolicy.swift
//  NumPad + Keyboard
//
//  Shared kiosk session policy (Codable). Lives outside KeyboardProfile so the
//  Keyboard extension can enforce inactivity reset without the full profile stack.
//

import Foundation

struct KioskPolicy: Codable, Equatable {
    var inactivityTimeout: TimeInterval
    var resetPageAndPack: Bool
    var dismissOverlays: Bool
    var clearResultTape: Bool
    var clearClipboardHistory: Bool
    var requireAdministratorAuthentication: Bool

    enum ValidationError: Error, Equatable {
        case invalidTimeout(TimeInterval)
    }

    func validated() throws {
        guard inactivityTimeout >= 30, inactivityTimeout <= 3600 else {
            throw ValidationError.invalidTimeout(inactivityTimeout)
        }
    }
}

struct KioskSessionConfiguration: Equatable {
    let policy: KioskPolicy
    let resetPage: String
    let resetPack: KeyboardType
    let activeProfileID: UUID
}

struct KioskResetDestination: Equatable {
    let page: String
    let pack: KeyboardType
}

struct KioskSessionEvaluation: Equatable {
    let actions: Set<KioskSessionPolicy.ResetAction>
    let resetPage: String
    let resetPack: KeyboardType
    let activeProfileID: UUID
}

struct KioskMonitorLifecycle {
    private(set) var permitsMonitorStart = false

    mutating func keyboardWillAppear() {
        permitsMonitorStart = true
    }

    mutating func keyboardWillDisappear() {
        permitsMonitorStart = false
    }
}

enum KioskSessionPolicy {
    enum ResetAction: Hashable {
        case dismissOverlays
        case resetPageAndPack
        case clearResultTape
        case clearClipboardHistory
    }

    static func actions(policy: KioskPolicy,
                        lastInteraction: Date,
                        now: Date) -> Set<ResetAction> {
        guard now.timeIntervalSince(lastInteraction) >= policy.inactivityTimeout else {
            return []
        }
        var actions: Set<ResetAction> = []
        if policy.dismissOverlays { actions.insert(.dismissOverlays) }
        if policy.resetPageAndPack { actions.insert(.resetPageAndPack) }
        if policy.clearResultTape { actions.insert(.clearResultTape) }
        if policy.clearClipboardHistory { actions.insert(.clearClipboardHistory) }
        return actions
    }

    /// Load and validate the active Kiosk profile's policy and authored reset destination.
    ///
    /// This shared resolver deliberately decodes only the non-personal subset the extension needs;
    /// the container app remains the sole writer through `KeyboardProfileStore`.
    static func activeConfiguration(
        defaults: UserDefaults = .group,
        qwertyAvailable: Bool = FeatureFlags.isQwertyPageAvailable,
        isPackLocked: (KeyboardType) -> Bool = { Monetization.isLocked(pack: $0) }
    ) -> KioskSessionConfiguration? {
        guard let idRaw = defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue),
              let id = UUID(uuidString: idRaw),
              let data = defaults.data(forKey: Constants.keyboardProfiles.rawValue),
              let profiles = try? JSONDecoder().decode([KioskProfilePolicyEnvelope].self, from: data),
              let match = profiles.first(where: { $0.id == id }),
              match.kind == "kiosk",
              let policy = match.kioskPolicy,
              (try? policy.validated()) != nil,
              match.configuration.keyboardPageRaw == "numpad"
                || match.configuration.keyboardPageRaw == "qwerty",
              let resetPack = KeyboardType(rawValue: match.configuration.keyboardTypeRaw),
              isSelectableResetPack(resetPack) else {
            return nil
        }
        let destination = resolveResetDestination(
            authoredPage: match.configuration.keyboardPageRaw,
            authoredPack: resetPack,
            qwertyAvailable: qwertyAvailable,
            isPackLocked: isPackLocked
        )
        return KioskSessionConfiguration(
            policy: policy,
            resetPage: destination.page,
            resetPack: destination.pack,
            activeProfileID: id
        )
    }

    /// Compatibility accessor for existing callers that only need the policy.
    static func activePolicy(defaults: UserDefaults = .group) -> KioskPolicy? {
        activeConfiguration(defaults: defaults)?.policy
    }

    /// Resolve the authored destination through the same live availability rules the keyboard
    /// applies on appearance. Kept pure so timeout behavior can be tested without StoreKit or
    /// Remote Config state.
    static func resolveResetDestination(
        authoredPage: String,
        authoredPack: KeyboardType,
        qwertyAvailable: Bool,
        isPackLocked: (KeyboardType) -> Bool
    ) -> KioskResetDestination {
        let page = authoredPage == "qwerty" && !qwertyAvailable ? "numpad" : authoredPage
        let pack: KeyboardType = isPackLocked(authoredPack) ? .default : authoredPack
        return KioskResetDestination(page: page, pack: pack)
    }

    private static func isSelectableResetPack(_ pack: KeyboardType) -> Bool {
        pack == .default || pack == .custom || KeyboardType.packs.contains(pack)
    }
}

/// Minimal shared decode envelope for the profile-store fields needed by kiosk enforcement.
private struct KioskProfilePolicyEnvelope: Codable {
    let id: UUID
    let kind: String
    let configuration: Configuration
    let kioskPolicy: KioskPolicy?

    struct Configuration: Codable {
        let keyboardTypeRaw: String
        let keyboardPageRaw: String
    }
}

/// App-group backed session clock. It stores one whole-second timestamp and no interaction
/// content. Every activity path evaluates the old timestamp first, then refreshes it.
struct KioskSessionClock {
    let defaults: UserDefaults
    let timestampKey: String
    let profileIDKey: String
    let now: () -> Date

    init(
        defaults: UserDefaults = .group,
        timestampKey: String = Constants.kioskLastActivity.rawValue,
        profileIDKey: String = Constants.kioskLastActivityProfileID.rawValue,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.timestampKey = timestampKey
        self.profileIDKey = profileIDKey
        self.now = now
    }

    func evaluateBeforeRecordingActivity(
        configuration: KioskSessionConfiguration
    ) -> KioskSessionEvaluation {
        let evaluation = evaluateWithoutRecordingActivity(configuration: configuration)
        recordActivity(for: configuration.activeProfileID)
        return evaluation
    }

    func evaluateWithoutRecordingActivity(
        configuration: KioskSessionConfiguration
    ) -> KioskSessionEvaluation {
        let actions: Set<KioskSessionPolicy.ResetAction>
        let storedProfileID = defaults.string(forKey: profileIDKey)
            .flatMap(UUID.init(uuidString:))
        if storedProfileID == configuration.activeProfileID,
           defaults.object(forKey: timestampKey) != nil {
            let lastInteraction = Date(
                timeIntervalSince1970: defaults.double(forKey: timestampKey)
            )
            actions = KioskSessionPolicy.actions(
                policy: configuration.policy,
                lastInteraction: lastInteraction,
                now: now()
            )
        } else {
            actions = []
        }
        return KioskSessionEvaluation(
            actions: actions,
            resetPage: configuration.resetPage,
            resetPack: configuration.resetPack,
            activeProfileID: configuration.activeProfileID
        )
    }

    func recordActivity(for activeProfileID: UUID) {
        defaults.set(
            floor(now().timeIntervalSince1970),
            forKey: timestampKey
        )
        defaults.set(activeProfileID.uuidString, forKey: profileIDKey)
    }
}
