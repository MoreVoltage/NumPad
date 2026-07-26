import Foundation
import CryptoKit

struct ManagedProfileRequest: Equatable {
    enum Source: Equatable {
        case builtin(KeyboardProfile.Kind)
        case embedded(KeyboardProfile)
    }
    let source: Source
    let lockEditing: Bool
}

enum ManagedProfileError: Error, Equatable {
    case missing
    case invalid
    case unsupportedKind
}

enum ManagedProfileConfiguration {
    static let managedKey = "com.apple.configuration.managed"

    static func parse(_ dictionary: [String: Any]?) -> Result<ManagedProfileRequest, ManagedProfileError> {
        guard let dictionary = dictionary, !dictionary.isEmpty else {
            return .failure(.missing)
        }
        if dictionary["builtin_profile_kind"] != nil, dictionary["profile_json"] != nil {
            return .failure(.invalid)
        }
        let lock: Bool
        if let rawLock = dictionary["lock_profile_editing"] {
            guard let parsed = rawLock as? Bool else { return .failure(.invalid) }
            lock = parsed
        } else {
            lock = false
        }
        if let kindRaw = dictionary["builtin_profile_kind"] as? String {
            guard let kind = KeyboardProfile.Kind(rawValue: kindRaw),
                  kind != .custom else {
                return .failure(.unsupportedKind)
            }
            return .success(ManagedProfileRequest(source: .builtin(kind), lockEditing: lock))
        }
        if let json = dictionary["profile_json"] as? String,
           let data = json.data(using: .utf8) {
            do {
                let profile = try KeyboardProfileDocument.decodeAndValidate(data)
                return .success(ManagedProfileRequest(source: .embedded(profile), lockEditing: lock))
            } catch {
                return .failure(.invalid)
            }
        }
        return .failure(.invalid)
    }

    /// SHA-256 over a JSON object encoded with sorted keys. The stored value is deterministic
    /// without retaining managed profile contents or names in app-group diagnostics.
    static func digest(_ dictionary: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(dictionary) else {
            throw ManagedProfileError.invalid
        }
        let canonical = try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.sortedKeys]
        )
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }
}
