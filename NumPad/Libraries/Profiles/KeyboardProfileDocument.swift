import Foundation

struct KeyboardProfileDocument: Codable {
    static let currentEnvelopeVersion = 1
    static let maxBytes = 256 * 1024

    let envelopeVersion: Int
    let exportedAt: Date
    let profile: KeyboardProfile

    enum DocumentError: Error, Equatable {
        case tooLarge
        case unsupportedEnvelope
        case invalidProfile(String)
        case containsForbiddenKeys
    }

    static func encode(_ profile: KeyboardProfile) throws -> Data {
        let validated = try validatedProfile(profile)
        let doc = KeyboardProfileDocument(
            envelopeVersion: currentEnvelopeVersion,
            exportedAt: Date(),
            profile: validated
        )
        let data = try JSONEncoder().encode(doc)
        guard data.count <= maxBytes else { throw DocumentError.tooLarge }
        return data
    }

    static func decodeAndValidate(_ data: Data) throws -> KeyboardProfile {
        guard data.count <= maxBytes else { throw DocumentError.tooLarge }
        let root = try JSONSerialization.jsonObject(with: data)
        let forbidden: Set<String> = [
            "isProPurchased", "isGrandfathered", "isFinancePackPurchased",
            "ownedPackProductIDs", "qwertyPersonalDictionary", "qwertyTouchOffsets",
            "clipboardEntries", "clipboardHistory", "typingQualityCounters",
            "telemetry", "analytics", "diagnostics"
        ]
        if containsForbiddenKey(in: root, forbidden: forbidden) {
            throw DocumentError.containsForbiddenKeys
        }
        let doc = try JSONDecoder().decode(KeyboardProfileDocument.self, from: data)
        guard doc.envelopeVersion == currentEnvelopeVersion else {
            throw DocumentError.unsupportedEnvelope
        }
        return try validatedProfile(doc.profile)
    }

    private static func containsForbiddenKey(in value: Any, forbidden: Set<String>) -> Bool {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                if forbidden.contains(key)
                    || containsForbiddenKey(in: nested, forbidden: forbidden) {
                    return true
                }
            }
        } else if let array = value as? [Any] {
            return array.contains { containsForbiddenKey(in: $0, forbidden: forbidden) }
        }
        return false
    }

    private static func validatedProfile(_ profile: KeyboardProfile) throws -> KeyboardProfile {
        do {
            let validated = try profile.validated()
            if let custom = validated.configuration.customKeyboardConfig {
                try CustomKeyboardProfileValidation.validate(custom)
            }
            return validated
        } catch let error as CustomKeyboardProfileValidation.Error {
            throw DocumentError.invalidProfile(error.description)
        } catch {
            throw DocumentError.invalidProfile(String(describing: error))
        }
    }
}
