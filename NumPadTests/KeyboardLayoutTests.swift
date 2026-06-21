import XCTest
@testable import NumPad

final class KeyDefinitionTests: XCTestCase {
    func testConvenienceInitDefaults() {
        let key = KeyDefinition(primary: .digit("5"))
        XCTAssertNil(key.longPress)
        XCTAssertNil(key.label)
        XCTAssertNil(key.colorHex)
        XCTAssertEqual(key.columnSpan, 1)
    }

    func testRoundTrips() throws {
        let key = KeyDefinition(primary: .op("+"), longPress: .calc, label: "plus",
                                colorHex: "#FF0000", columnSpan: 2)
        let data = try JSONEncoder().encode(key)
        XCTAssertEqual(try JSONDecoder().decode(KeyDefinition.self, from: data), key)
    }
}

final class KeyboardLayoutTests: XCTestCase {
    private func primaryTokens(_ layout: KeyboardLayout) -> [KeyToken] {
        layout.rows.flatMap { $0 }.map { $0.primary }
    }

    private func row(_ tokens: [KeyToken]) -> [KeyDefinition] {
        tokens.map { KeyDefinition(primary: $0) }
    }

    func testRoundTrips() throws {
        let layout = KeyboardLayout(name: "Work", rows: [row([.digit("1"), .digit("2")])], keyScale: 1.2)
        let data = try JSONEncoder().encode(layout)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardLayout.self, from: data), layout)
    }

    func testSchemaVersionDefaultsToCurrent() {
        XCTAssertEqual(KeyboardLayout(name: "x", rows: []).schemaVersion, KeyboardLayout.currentSchema)
    }

    func testRepairedAddsMissingEssentials() {
        // Missing digit 5, delete, and return.
        let present: [KeyToken] = [.digit("0"), .digit("1"), .digit("2"), .digit("3"), .digit("4"),
                                   .digit("6"), .digit("7"), .digit("8"), .digit("9")]
        let repaired = KeyboardLayout(name: "broken", rows: [row(present)]).repaired()
        for essential in KeyboardLayout.essentialTokens {
            XCTAssertTrue(primaryTokens(repaired).contains(essential), "repaired() still missing \(essential)")
        }
    }

    func testRepairedLeavesCompleteLayoutTokensIntact() {
        let layout = KeyboardLayout(name: "ok", rows: [row(KeyboardLayout.essentialTokens)])
        XCTAssertEqual(primaryTokens(layout.repaired()), KeyboardLayout.essentialTokens)
    }

    func testRepairedDoesNotMutateSource() {
        let layout = KeyboardLayout(name: "broken", rows: [row([.digit("0")])])
        _ = layout.repaired()
        XCTAssertEqual(primaryTokens(layout), [.digit("0")])  // source unchanged
    }
}
