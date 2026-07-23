import XCTest
@testable import NumPad

final class QwertyPersonalizationContextTests: XCTestCase {
    func test_phoneAutomaticIsolatedFromPadSplit() {
        let phone = QwertyPersonalizationContext.phoneAutomatic
        let pad = QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)
        XCTAssertNotEqual(phone, pad)
    }

    func testLegacyBlobMigratesOnceToPhoneAutomaticOnly() {
        var legacy = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            legacy.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.25, dy: -0.1)
            )
        }

        let migrated = QwertyTouchPersonalizationEnvelope(data: legacy.encoded())
        XCTAssertTrue(migrated.requiresMigrationWrite)
        XCTAssertNotNil(migrated.model(for: .phoneAutomatic).offset(forKeyCharacter: "a"))
        XCTAssertNil(
            migrated.model(
                for: QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .centered)
            ).offset(forKeyCharacter: "a"),
            "legacy phone data must never influence an iPad context"
        )

        let decodedAgain = QwertyTouchPersonalizationEnvelope(data: migrated.encoded())
        XCTAssertFalse(decodedAgain.requiresMigrationWrite)
        XCTAssertNotNil(decodedAgain.model(for: .phoneAutomatic).offset(forKeyCharacter: "a"))
    }

    func testEnvelopePersistsIndependentModelsByResolvedContext() throws {
        let phone = QwertyPersonalizationContext.phoneAutomatic
        let pad = QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)
        var phoneModel = QwertyTouchPersonalization()
        var padModel = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            phoneModel.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.3, dy: 0)
            )
            padModel.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: -0.4, dy: 0)
            )
        }

        var envelope = QwertyTouchPersonalizationEnvelope()
        envelope.setModel(phoneModel, for: phone)
        envelope.setModel(padModel, for: pad)
        let restored = QwertyTouchPersonalizationEnvelope(data: envelope.encoded())

        let phoneOffset = try XCTUnwrap(
            restored.model(for: phone).offset(forKeyCharacter: "a")
        )
        let padOffset = try XCTUnwrap(
            restored.model(for: pad).offset(forKeyCharacter: "a")
        )
        XCTAssertEqual(phoneOffset.dx, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(padOffset.dx, -0.4, accuracy: 0.000_001)
    }
}
