import XCTest
@testable import NumPad

final class KeyTokenCodableTests: XCTestCase {
    private func roundTrip(_ token: KeyToken) throws -> KeyToken {
        let data = try JSONEncoder().encode(token)
        return try JSONDecoder().decode(KeyToken.self, from: data)
    }

    func testRoundTripsEveryCase() throws {
        let tokens: [KeyToken] = [
            .digit("7"), .op("+"), .decimalSeparator, .delete, .ret, .space,
            .tab, .hide, .calc, .cursor(.left), .snippet(UUID()),
            .pack("finance"), .overlay(.clipboard), .noop,
        ]
        for token in tokens {
            XCTAssertEqual(try roundTrip(token), token, "round-trip failed for \(token)")
        }
    }

    func testUnknownDiscriminatorDecodesToNoop() throws {
        // A token kind written by a FUTURE build must degrade to .noop, not throw.
        let futureJSON = #"{"kind":"hologram","value":"sparkle"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KeyToken.self, from: futureJSON)
        XCTAssertEqual(decoded, .noop)
    }
}
