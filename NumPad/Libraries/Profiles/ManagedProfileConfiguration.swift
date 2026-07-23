import Foundation

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
        let lock = dictionary["lock_profile_editing"] as? Bool ?? false
        if let kindRaw = dictionary["builtin_profile_kind"] as? String {
            guard let kind = KeyboardProfile.Kind(rawValue: kindRaw) else {
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
}

