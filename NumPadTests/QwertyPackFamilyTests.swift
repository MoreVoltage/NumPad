import XCTest
@testable import NumPad

final class QwertyPackFamilyTests: XCTestCase {

    // MARK: crossover table (plan §2) — Grammar first; Units & Cooking stay numpad-only

    func testMembersFollowTheCrossoverTable() {
        XCTAssertEqual(QwertyPackFamily.members.first, .grammar, "Grammar ships first (§0.3)")
        XCTAssertTrue(QwertyPackFamily.members.contains(.symbols))
        XCTAssertTrue(QwertyPackFamily.members.contains(.finance))
        XCTAssertTrue(QwertyPackFamily.members.contains(.programmer))
        XCTAssertTrue(QwertyPackFamily.members.contains(.datetime))
        XCTAssertTrue(QwertyPackFamily.members.contains(.custom))
        XCTAssertFalse(QwertyPackFamily.members.contains(.units),
                       "the '=' converter overlay is the point of Units — numpad-only")
        XCTAssertFalse(QwertyPackFamily.members.contains(.cooking))
        XCTAssertFalse(QwertyPackFamily.members.contains(.math),
                       "math rows target numeric entry, not prose")
    }

    func testGrammarPackKeysMatchTheOwnerDecision() {
        // Em dash, en dash, curly double + single quotes, semicolon, ellipsis, degree, section.
        XCTAssertEqual(PackKeys.symbols(for: .grammar),
                       ["\u{2014}", "\u{2013}", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}",
                        ";", "\u{2026}", "\u{00B0}", "\u{00A7}"])
    }

    func testGrammarIsNotANumpadPackAndHasNoProductID() {
        XCTAssertFalse(KeyboardType.packs.contains(.grammar),
                       "grammar is QWERTY-side only — never in the numpad pack list or store")
        XCTAssertNil(ProductCatalog.packProductID(for: .grammar),
                     "no new SKU (plan §5) — grammar ships with NumPad Type")
    }

    // MARK: strip content

    func testGrammarContentIsLiteralKeys() {
        let content = QwertyPackFamily.content(for: .grammar, customKeys: [])
        XCTAssertEqual(content.count, 10)
        XCTAssertEqual(content.first, .literal("\u{2014}"))
    }

    func testDateTimeContentCarriesLiveTokens() {
        let content = QwertyPackFamily.content(for: .datetime, customKeys: [])
        XCTAssertEqual(content.count, DateTimeTokens.ordered.count)
        XCTAssertEqual(content.first, .dateTime(token: "date", label: "Date"),
                       "date/time keys insert live values at tap time, not labels")
    }

    func testCustomContentUsesInjectedKeysAndDropsEmpties() {
        let content = QwertyPackFamily.content(for: .custom, customKeys: ["00", "", "€"])
        XCTAssertEqual(content, [.literal("00"), .literal("€")])
    }

    // MARK: pack-switch cycling: number row → each entitled pack → back to the number row

    func testNextCyclesThroughEntitledPacksAndWrapsToNumbers() {
        let all: (KeyboardType) -> Bool = { _ in true }
        var current: KeyboardType? = nil
        var visited: [KeyboardType?] = []
        for _ in 0...(QwertyPackFamily.members.count) {
            current = QwertyPackFamily.next(after: current, entitled: all)
            visited.append(current)
        }
        XCTAssertEqual(visited.dropLast().compactMap { $0 }, QwertyPackFamily.members)
        XCTAssertNil(visited.last!, "after the last pack the strip returns to the number row")
    }

    func testNextSkipsUnentitledPacks() {
        let onlyGrammar: (KeyboardType) -> Bool = { $0 == .grammar }
        XCTAssertEqual(QwertyPackFamily.next(after: nil, entitled: onlyGrammar), .grammar)
        XCTAssertNil(QwertyPackFamily.next(after: .grammar, entitled: onlyGrammar))
    }

    func testNextWithNothingEntitledStaysOnNumbers() {
        XCTAssertNil(QwertyPackFamily.next(after: nil, entitled: { _ in false }))
    }

    func testNextFromStaleSelectionRestartsAtFirstEntitled() {
        // e.g. the persisted pack lost entitlement since it was last shown.
        let noCustom: (KeyboardType) -> Bool = { $0 != .custom }
        XCTAssertEqual(QwertyPackFamily.next(after: .custom, entitled: noCustom), .grammar)
    }

    // MARK: LAST-USED vs PRIMARY-SELECTED (owner decision §0.4)

    func testPackToShowFollowsBehavior() {
        XCTAssertEqual(QwertyPackFamily.packToShow(behavior: .lastUsed,
                                                   lastUsed: .finance,
                                                   primary: .grammar), .finance)
        XCTAssertEqual(QwertyPackFamily.packToShow(behavior: .primarySelected,
                                                   lastUsed: .finance,
                                                   primary: .grammar), .grammar)
        XCTAssertNil(QwertyPackFamily.packToShow(behavior: .lastUsed,
                                                 lastUsed: nil,
                                                 primary: .grammar),
                     "nil means the number row")
    }

    func testPackDisplayBehaviorDefaultsToLastUsed() {
        XCTAssertEqual(PackDisplayBehavior.default, .lastUsed)
        XCTAssertNil(PackDisplayBehavior(rawValue: "bogus"))
    }

    // MARK: numpad-canvas auto-swap — the number line and the numpad never display together

    func testStripPackOnQwertyCanvasHonorsSelection() {
        let all: (KeyboardType) -> Bool = { _ in true }
        XCTAssertNil(QwertyPackFamily.stripPack(selected: nil, numpadCanvas: false, entitled: all),
                     "number row is the QWERTY-canvas default")
        XCTAssertEqual(QwertyPackFamily.stripPack(selected: .finance, numpadCanvas: false, entitled: all),
                       .finance)
    }

    func testStripPackOnNumpadCanvasAutoSwapsAwayFromNumbers() {
        let all: (KeyboardType) -> Bool = { _ in true }
        XCTAssertEqual(QwertyPackFamily.stripPack(selected: nil, numpadCanvas: true, entitled: all),
                       .grammar,
                       "digits live on the flipped canvas — the strip swaps to the first pack")
        XCTAssertEqual(QwertyPackFamily.stripPack(selected: .finance, numpadCanvas: true, entitled: all),
                       .finance, "an explicit pack selection is kept")
    }

    func testStripPackOnNumpadCanvasWithNothingEntitledFallsBackToNumbers() {
        XCTAssertNil(QwertyPackFamily.stripPack(selected: nil, numpadCanvas: true,
                                                entitled: { _ in false }),
                     "degenerate case: duplicated digits beat an empty strip")
    }

    func testNextStripPackOnNumpadCanvasSkipsTheNumberRow() {
        let all: (KeyboardType) -> Bool = { _ in true }
        // Cycling from the last pack wraps straight to the first pack — never to numbers.
        XCTAssertEqual(QwertyPackFamily.nextStripPack(afterDisplayed: QwertyPackFamily.members.last,
                                                      numpadCanvas: true,
                                                      entitled: all),
                       .grammar)
        // On the QWERTY canvas the wrap still lands on the number row.
        XCTAssertNil(QwertyPackFamily.nextStripPack(afterDisplayed: QwertyPackFamily.members.last,
                                                    numpadCanvas: false,
                                                    entitled: all))
        XCTAssertEqual(QwertyPackFamily.nextStripPack(afterDisplayed: .grammar,
                                                      numpadCanvas: true,
                                                      entitled: all),
                       .symbols, "mid-family hops are canvas-independent")
    }
}
