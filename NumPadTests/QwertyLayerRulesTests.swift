import XCTest
@testable import NumPad

final class QwertyLayerRulesTests: XCTestCase {

    func testIPadCompositionsAlwaysForceVisibleNumberStrip() {
        XCTAssertTrue(IPadKeyboardCompositionGeometry.shouldForceNumberStrip(
            idiom: .pad,
            layout: .standard
        ))
        XCTAssertTrue(IPadKeyboardCompositionGeometry.shouldForceNumberStrip(
            idiom: .pad,
            layout: .full
        ))
        XCTAssertFalse(IPadKeyboardCompositionGeometry.shouldForceNumberStrip(
            idiom: .phone,
            layout: .standard
        ))
    }

    // MARK: apostrophe bounces back to letters (system parity, HIGH confidence)

    func testApostropheOnSymbolsReturnsToLetters() {
        XCTAssertEqual(QwertyLayerRules.layer(afterInserting: "'", on: .symbols), .letters)
        XCTAssertEqual(QwertyLayerRules.layer(afterInserting: "'", on: .extendedSymbols), .letters)
    }

    // MARK: space bounces back to letters (system parity — flagged for device verification)

    func testSpaceOnSymbolLayersReturnsToLetters() {
        XCTAssertEqual(QwertyLayerRules.layer(afterInserting: " ", on: .symbols), .letters)
        XCTAssertEqual(QwertyLayerRules.layer(afterInserting: " ", on: .extendedSymbols), .letters)
    }

    // MARK: everything else stays put

    func testDigitsAndPunctuationStayOnSymbolLayers() {
        for layer in [QwertyLayer.symbols, .extendedSymbols] {
            for text in ["5", ".", ",", "?", "!", "$", "(", "…", "[", "#", "^", "€"] {
                XCTAssertEqual(QwertyLayerRules.layer(afterInserting: text, on: layer), layer,
                               "'\(text)' must not bounce \(layer) — users type runs like $5.99")
            }
        }
    }

    func testLettersLayerIsAlwaysStable() {
        for text in ["a", " ", "'", "."] {
            XCTAssertEqual(QwertyLayerRules.layer(afterInserting: text, on: .letters), .letters)
        }
    }
}
