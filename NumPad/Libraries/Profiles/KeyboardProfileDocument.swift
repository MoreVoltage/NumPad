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
        let json = String(decoding: data, as: UTF8.self)
        let forbidden = ["isProPurchased", "isGrandfathered", "qwertyPersonalDictionary", "qwertyTouchOffsets", "clipboardEntries"]
        for key in forbidden where json.contains(key) {
            throw DocumentError.containsForbiddenKeys
        }
        let doc = try JSONDecoder().decode(KeyboardProfileDocument.self, from: data)
        guard doc.envelopeVersion == currentEnvelopeVersion else {
            throw DocumentError.unsupportedEnvelope
        }
        return try validatedProfile(doc.profile)
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
