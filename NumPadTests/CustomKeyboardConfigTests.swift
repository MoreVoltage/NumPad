import XCTest
@testable import NumPad

final class CustomKeyboardConfigTests: XCTestCase {

    func testHandednessDefaultIsRight() {
        XCTAssertEqual(Handedness.default, .right)
        XCTAssertEqual(Handedness.allCases, [.left, .right])
    }

    func testSectionEnabledSemantics() {
        let off = CustomKeyboardConfig()
        XCTAssertFalse(off.isTopRowEnabled)
        XCTAssertFalse(off.isColumn1Enabled)
        XCTAssertFalse(off.isColumn2Enabled)

        // [] == switch ON but no keys yet (distinct from nil == OFF).
        let onEmpty = CustomKeyboardConfig(topRow: [])
        XCTAssertTrue(onEmpty.isTopRowEnabled)
        XCTAssertEqual(onEmpty.topRowKeys, [])

        let onKeys = CustomKeyboardConfig(column1: ["a", "b"])
        XCTAssertTrue(onKeys.isColumn1Enabled)
        XCTAssertEqual(onKeys.column1Keys, ["a", "b"])
    }

    func testHasAnyKeys() {
        XCTAssertFalse(CustomKeyboardConfig().hasAnyKeys)
        XCTAssertFalse(CustomKeyboardConfig(column1: []).hasAnyKeys)         // enabled but empty
        XCTAssertFalse(CustomKeyboardConfig(column1: ["", ""]).hasAnyKeys)   // only blanks
        XCTAssertTrue(CustomKeyboardConfig(column1: ["", "x"]).hasAnyKeys)
        XCTAssertTrue(CustomKeyboardConfig(topRow: ["00"]).hasAnyKeys)
    }

    func testCodableRoundTrip() throws {
        let config = CustomKeyboardConfig(id: UUID(), name: "Mine",
                                          topRow: ["00", "000"],
                                          column1: [",", ".", CustomKeys.spaceToken],
                                          column2: ["+", "-"])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CustomKeyboardConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testCodablePreservesNilSectionsVsEmpty() throws {
        let config = CustomKeyboardConfig(topRow: nil, column1: [], column2: ["x"])
        let decoded = try JSONDecoder().decode(CustomKeyboardConfig.self,
                                               from: JSONEncoder().encode(config))
        XCTAssertNil(decoded.topRow)        // OFF stays OFF
        XCTAssertEqual(decoded.column1, []) // ON-but-empty survives the round trip
        XCTAssertEqual(decoded.column2, ["x"])
    }

    func testSeededFromExistingCustomization() {
        let config = CustomKeyboardConfig.seeded(
            customPackKeys: ["00", "000"],
            rightSlots: [",", ".", CustomKeys.spaceToken])
        XCTAssertEqual(config.topRow, ["00", "000"])                      // Custom Pack → Top Row
        XCTAssertEqual(config.column1, [",", ".", CustomKeys.spaceToken]) // slots → Column 1, tokens preserved
        XCTAssertNil(config.column2)                                      // new second column starts OFF
    }

    func testSeededWithEmptyPackLeavesTopRowOff() {
        let config = CustomKeyboardConfig.seeded(customPackKeys: [],
                                                 rightSlots: [",", ".", CustomKeys.spaceToken])
        XCTAssertNil(config.topRow)
        XCTAssertEqual(config.column1, [",", ".", CustomKeys.spaceToken])
    }
}
