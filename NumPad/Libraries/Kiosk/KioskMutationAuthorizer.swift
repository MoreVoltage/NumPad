//
//  KioskMutationAuthorizer.swift
//  NumPad
//

import Foundation
import LocalAuthentication

/// App-side gate for any mutation while an active Kiosk setup requests device authentication.
/// The keyboard extension never imports this type. Completion is always delivered on the main queue
/// when LocalAuthentication is involved, so callers can present errors safely.
final class KioskMutationAuthorizer {
    enum Result: Equatable {
        case authorized
        case denied
    }

    typealias Authentication = (@escaping (Swift.Result<Void, Error>) -> Void) -> Void
    private let requiresAuthentication: () -> Bool
    private let authenticate: Authentication

    init(
        defaults: UserDefaults = .group,
        requiresAuthentication: (() -> Bool)? = nil,
        authenticate: Authentication? = nil
    ) {
        self.requiresAuthentication = requiresAuthentication ?? {
            KeyboardProfileStore(defaults: defaults).activeProfile()?.kioskPolicy?.requireAdministratorAuthentication == true
        }
        self.authenticate = authenticate ?? Self.deviceAuthentication
    }

    func performIfAuthorized(
        _ mutation: @escaping () -> Void,
        completion: @escaping (Result) -> Void
    ) {
        guard requiresAuthentication() else {
            mutation()
            completion(.authorized)
            return
        }
        var hasResolved = false
        authenticate { outcome in
            DispatchQueue.main.async {
                guard !hasResolved else { return }
                hasResolved = true
                switch outcome {
                case .success:
                    mutation()
                    completion(.authorized)
                case .failure:
                    completion(.denied)
                }
            }
        }
    }

    private static func deviceAuthentication(
        completion: @escaping (Swift.Result<Void, Error>) -> Void
    ) {
        let context = LAContext()
        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            completion(.failure(error ?? LAError(.authenticationFailed)))
            return
        }
        context.evaluatePolicy(
            policy,
            localizedReason: NSLocalizedString(
                "Authenticate to change Kiosk mode settings.",
                comment: "Kiosk mutation authentication reason"
            )
        ) { success, evaluationError in
            success ? completion(.success(())) : completion(.failure(evaluationError ?? LAError(.authenticationFailed)))
        }
    }
}
