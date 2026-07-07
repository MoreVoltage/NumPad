import XCTest
@testable import NumPad

final class QwertyLayoutTests: XCTestCase {

    private func rows(_ layer: QwertyLayer,
                      periodComma: Bool = true,
                      globe: Bool = true,
                      dismiss: Bool = false) -> [QwertyRow] {
        QwertyLayout.rows(layer: layer,
                          options: QwertyLayoutOptions(periodCommaOnLetters: periodComma,
                                                       needsSwitchKey: globe,
                                                       needsDismissKey: dismiss))
    }

    private func outputs(_ row: QwertyRow) -> [String] {
        row.keys.compactMap {
            if case .character(let s, _) = $0.kind { return s }
            return nil
        }
    }

    // MARK: letter rows match the system keyboard exactly (parity §0.1)

    func testLetterRowsMatchSystemKeyboard() {
        let letters = rows(.letters)
        XCTAssertEqual(outputs(letters[0]), ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        XCTAssertEqual(outputs(letters[1]), ["a", "s", "d", "f", "g", "h", "j", "k", "l"])
        XCTAssertEqual(outputs(letters[2]), ["z", "x", "c", "v", "b", "n", "m"])
    }

    func testShiftedVariantsAreUppercased() {
        for row in rows(.letters) {
            for key in row.keys {
                if case .character(let base, let shifted) = key.kind, base.first!.isLetter {
                    XCTAssertEqual(shifted, base.uppercased(), "shifted variant of \(base)")
                }
            }
        }
    }

    func testHomeRowIsCenteredWithHalfKeyMargins() {
        let home = rows(.letters)[1]
        XCTAssertEqual(home.leadingMargin, 0.5)
        XCTAssertEqual(home.trailingMargin, 0.5)
    }

    func testShiftAndBackspaceFlankTheBottomLetterRow() {
        let row = rows(.letters)[2]
        XCTAssertEqual(row.keys.first?.kind, .shift)
        XCTAssertEqual(row.keys.last?.kind, .backspace)
    }

    // MARK: every row of every layer/option combination fills the unit width exactly

    func testEveryRowSumsToUnitWidth() {
        for layer in [QwertyLayer.letters, .symbols, .extendedSymbols] {
            for periodComma in [true, false] {
                for globe in [true, false] {
                    for dismiss in [true, false] {
                        let built = rows(layer, periodComma: periodComma, globe: globe,
                                         dismiss: dismiss)
                        for (i, row) in built.enumerated() {
                            let total = row.keys.reduce(0) { $0 + $1.width }
                                + row.leadingMargin + row.trailingMargin
                            XCTAssertEqual(total, QwertyLayout.rowUnitWidth, accuracy: 0.0001,
                                           "layer \(layer) row \(i) periodComma=\(periodComma) globe=\(globe) dismiss=\(dismiss)")
                        }
                    }
                }
            }
        }
    }

    // MARK: iPad — the native dismiss-keyboard key sits bottom-trailing on every layer

    func testDismissKeyPresenceFollowsNeedsDismissKey() {
        for layer in [QwertyLayer.letters, .symbols, .extendedSymbols] {
            for periodComma in [true, false] {
                for globe in [true, false] {
                    let with = rows(layer, periodComma: periodComma, globe: globe, dismiss: true)
                    XCTAssertEqual(with.last?.keys.last?.kind, .dismissKeyboard,
                                   "\(layer) bottom row must end with the dismiss key on iPad")
                    let without = rows(layer, periodComma: periodComma, globe: globe, dismiss: false)
                    XCTAssertFalse(without.flatMap { $0.keys }.contains { $0.kind == .dismissKeyboard },
                                   "\(layer) must not show a dismiss key on iPhone (system parity)")
                }
            }
        }
    }

    // MARK: period + comma on the letters layer — one switch, both together (owner decision §0.2)

    func testPeriodCommaOnFlanksSpaceOnBottomRow() {
        let bottom = rows(.letters, periodComma: true).last!
        let kinds = bottom.keys.map { $0.kind }
        guard let spaceIndex = kinds.firstIndex(of: .space) else {
            return XCTFail("bottom row must contain space")
        }
        XCTAssertEqual(kinds[spaceIndex - 1], .character(",", shifted: ","), "comma left of space")
        XCTAssertEqual(kinds[spaceIndex + 1], .character(".", shifted: "."), "period right of space")
    }

    func testPeriodCommaOffMatchesSystemBottomRow() {
        let bottom = rows(.letters, periodComma: false).last!
        XCTAssertEqual(bottom.keys.map { $0.kind },
                       [.layerSwitch(.symbols), .globe, .space, .ret])
    }

    func testPeriodCommaSwitchNeverTouchesLetterRows() {
        let on = rows(.letters, periodComma: true)
        let off = rows(.letters, periodComma: false)
        for i in 0...2 {
            XCTAssertEqual(on[i], off[i], "letter row \(i) must not change with the toggle")
        }
    }

    func testPeriodCommaSwitchDoesNotAffectSymbolLayers() {
        for layer in [QwertyLayer.symbols, .extendedSymbols] {
            XCTAssertEqual(rows(layer, periodComma: true), rows(layer, periodComma: false),
                           "\(layer) already has period/comma on its own rows")
        }
    }

    // MARK: globe key present exactly when the device needs one

    func testGlobeKeyPresenceFollowsNeedsSwitchKey() {
        for layer in [QwertyLayer.letters, .symbols, .extendedSymbols] {
            for periodComma in [true, false] {
                let with = rows(layer, periodComma: periodComma, globe: true).last!
                XCTAssertTrue(with.keys.contains { $0.kind == .globe },
                              "\(layer) must show globe when needed")
                let without = rows(layer, periodComma: periodComma, globe: false).last!
                XCTAssertFalse(without.keys.contains { $0.kind == .globe },
                               "\(layer) must hide globe when not needed")
            }
        }
    }

    // MARK: symbol layers match the system keyboard's US English layers

    func testSymbolsLayerMatchesSystem() {
        let symbols = rows(.symbols)
        XCTAssertEqual(outputs(symbols[0]), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        XCTAssertEqual(outputs(symbols[1]), ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
        XCTAssertEqual(outputs(symbols[2]), [".", ",", "?", "!", "'"])
        XCTAssertEqual(symbols[2].keys.first?.kind, .layerSwitch(.extendedSymbols))
        XCTAssertEqual(symbols[2].keys.last?.kind, .backspace)
    }

    func testExtendedSymbolsLayerMatchesSystem() {
        let extended = rows(.extendedSymbols)
        XCTAssertEqual(outputs(extended[0]), ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        XCTAssertEqual(outputs(extended[1]), ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"])
        XCTAssertEqual(outputs(extended[2]), [".", ",", "?", "!", "'"])
        XCTAssertEqual(extended[2].keys.first?.kind, .layerSwitch(.symbols))
    }

    func testSymbolLayersReturnToLettersViaABC() {
        for layer in [QwertyLayer.symbols, .extendedSymbols] {
            let bottom = rows(layer).last!
            XCTAssertEqual(bottom.keys.first?.kind, .layerSwitch(.letters),
                           "\(layer) bottom row leads with ABC")
        }
    }

    // MARK: top strip — numpad flip + swappable number row + pack switch (owner decision §0.3)

    func testTopStripNumbersHasFlipTenDigitsThenPackSwitch() {
        let keys = QwertyTopStrip.keys(for: .numbers)
        XCTAssertEqual(keys.first?.kind, .numpadFlip)
        XCTAssertEqual(keys.last?.kind, .packSwitch)
        let digits = keys.dropFirst().dropLast().compactMap { key -> String? in
            if case .character(let s, _) = key.kind { return s }
            return nil
        }
        XCTAssertEqual(digits, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
    }

    func testTopStripPackShowsContentBetweenFlipAndSwitch() {
        let keys = QwertyTopStrip.keys(for: .pack([.literal("—"), .literal("–"), .literal("…")]))
        XCTAssertEqual(keys.first?.kind, .numpadFlip)
        XCTAssertEqual(keys.last?.kind, .packSwitch)
        XCTAssertEqual(keys.count, 5)
        XCTAssertEqual(keys[1].kind, .character("—", shifted: "—"))
    }

    func testTopStripDateTimeContentRendersTokenKeys() {
        let keys = QwertyTopStrip.keys(for: .pack([.dateTime(token: "date", label: "Date")]))
        XCTAssertEqual(keys[1].kind, .dateTimeToken(label: "Date", token: "date"))
    }

    func testTopStripAlwaysSumsToUnitWidth() {
        let strips: [QwertyTopStrip] = [
            .numbers,
            .pack([.literal("a")]),
            .pack([.literal("a"), .literal("b"), .literal("c"), .literal("d"), .literal("e")]),
            .pack([]),
        ]
        for strip in strips {
            let total = QwertyTopStrip.keys(for: strip).reduce(0) { $0 + $1.width }
            XCTAssertEqual(total, QwertyLayout.rowUnitWidth, accuracy: 0.0001)
        }
    }

    func testTopStripEmptyPackKeepsFlipAndSwitchOnly() {
        let keys = QwertyTopStrip.keys(for: .pack([]))
        XCTAssertEqual(keys.map { $0.kind }, [.numpadFlip, .packSwitch])
    }
}
