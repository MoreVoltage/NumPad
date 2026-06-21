import XCTest
@testable import NumPad

final class KeyboardLayoutRendererTests: XCTestCase {
    func testDigitAndOperatorInsert() {
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .digit("7")), .insert("7"))
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .op("+")), .insert("+"))
    }

    func testStandardSpecialKeys() {
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .decimalSeparator), .separator)
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .delete), .delete)
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .ret), .ret)
        XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: .space), .space)
    }

    func testUnsupportedV1TokensAreBlank() {
        let deferred: [KeyToken] = [.cursor(.left), .cursor(.up), .hide, .tab, .calc,
                                    .snippet(UUID()), .pack("finance"), .overlay(.clipboard), .noop]
        for token in deferred {
            XCTAssertEqual(KeyboardLayoutRenderer.renderKind(for: token), .blank, "\(token) should be .blank in v1")
        }
    }
}
