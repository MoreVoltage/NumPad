import XCTest
@testable import NumPad

final class KeyboardProfileDocumentTests: XCTestCase {
    func test_roundTrip() throws {
        let data = try KeyboardProfileDocument.encode(.testFixture)
        let decoded = try KeyboardProfileDocument.decodeAndValidate(data)
        XCTAssertEqual(decoded.name, KeyboardProfile.testFixture.name)
    }

    func test_rejectsForbiddenKeys() {
        let json = Data("{\"envelopeVersion\":1,\"exportedAt\":0,\"profile\":{\"isProPurchased\":true}}".utf8)
        XCTAssertThrowsError(try KeyboardProfileDocument.decodeAndValidate(json)) { error in
            XCTAssertEqual(
                error as? KeyboardProfileDocument.DocumentError,
                .containsForbiddenKeys
            )
        }
    }

    func test_rejectsForbiddenNestedTelemetryAndPersonalContentKeys() throws {
        let forbiddenKeys = [
            "telemetry", "typingQualityCounters", "qwertyPersonalDictionary",
            "qwertyTouchOffsets", "clipboardEntries", "isProPurchased"
        ]
        let encoded = try KeyboardProfileDocument.encode(.testFixture)
        let validRoot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        for key in forbiddenKeys {
            var root = validRoot
            root["unexpected"] = ["nested": [key: true]]
            let json = try JSONSerialization.data(
                withJSONObject: root,
                options: [.sortedKeys]
            )
            XCTAssertThrowsError(
                try KeyboardProfileDocument.decodeAndValidate(json),
                "Expected \(key) to be rejected"
            ) { error in
                XCTAssertEqual(
                    error as? KeyboardProfileDocument.DocumentError,
                    .containsForbiddenKeys
                )
            }
        }
    }

    func test_rejectsHugeDocuments() {
        let huge = Data(repeating: 0x41, count: KeyboardProfileDocument.maxBytes + 1)
        XCTAssertThrowsError(try KeyboardProfileDocument.decodeAndValidate(huge))
    }

    func test_exportRejectsStructurallyInvalidCustomLayout() {
        var profile = KeyboardProfile.testFixture
        profile.configuration.customKeyboardConfig = CustomKeyboardConfig(
            topRow: Array(repeating: "1", count: CustomKeyboardEditorModel.topRowCapacity + 1)
        )

        XCTAssertThrowsError(try KeyboardProfileDocument.encode(profile)) { error in
            guard case KeyboardProfileDocument.DocumentError.invalidProfile = error else {
                return XCTFail("Expected invalidProfile, got \(error)")
            }
        }
    }
}
