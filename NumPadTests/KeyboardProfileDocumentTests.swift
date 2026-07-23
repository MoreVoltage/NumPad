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
        XCTAssertThrowsError(try KeyboardProfileDocument.decodeAndValidate(json))
    }

    func test_rejectsHugeDocuments() {
        let huge = Data(repeating: 0x41, count: KeyboardProfileDocument.maxBytes + 1)
        XCTAssertThrowsError(try KeyboardProfileDocument.decodeAndValidate(huge))
    }
}

