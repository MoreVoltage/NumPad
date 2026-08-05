import XCTest
@testable import NumPad

final class EmojiKeyboardReducerTests: XCTestCase {
    private func reduce(
        _ mode: EmojiKeyboardMode,
        _ action: EmojiKeyboardAction
    ) -> (mode: EmojiKeyboardMode, effects: [EmojiKeyboardEffect]) {
        var nextMode = mode
        let effects = EmojiKeyboardReducer.reduce(mode: &nextMode, action: action)
        return (nextMode, effects)
    }

    private func assertReduction(
        _ mode: EmojiKeyboardMode,
        _ action: EmojiKeyboardAction,
        becomes expectedMode: EmojiKeyboardMode,
        effects expectedEffects: [EmojiKeyboardEffect],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = reduce(mode, action)
        XCTAssertEqual(result.mode, expectedMode, file: file, line: line)
        XCTAssertEqual(result.effects, expectedEffects, file: file, line: line)
    }

    private func assertNoHostInsert(
        _ effects: [EmojiKeyboardEffect],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(effects.contains { effect in
            if case .insertEmoji = effect { return true }
            return false
        }, file: file, line: line)
    }

    func testOpenEmojiLoadsBrowseOnlyFromTyping() {
        assertReduction(
            .typing,
            .openEmoji,
            becomes: .browse(category: .smileys, filter: nil),
            effects: [.loadBrowse]
        )
        assertReduction(
            .browse(category: .animals, filter: nil),
            .openEmoji,
            becomes: .browse(category: .animals, filter: nil),
            effects: []
        )
    }

    func testOpenSearchLoadsAnnotationsOnlyFromBrowse() {
        assertReduction(
            .browse(category: .animals, filter: nil),
            .openSearch,
            becomes: .search(query: ""),
            effects: [.loadSearch]
        )
        assertReduction(.typing, .openSearch, becomes: .typing, effects: [])
    }

    func testQueryTextAndBackspaceStayInternalToSearch() {
        var mode: EmojiKeyboardMode = .search(query: "wav")
        var effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryText("e"))
        XCTAssertEqual(mode, .search(query: "wave"))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)

        effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryText(" hand"))
        XCTAssertEqual(mode, .search(query: "wave hand"))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)

        effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryBackspace)
        XCTAssertEqual(mode, .search(query: "wave han"))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)

        mode = .search(query: "")
        effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryBackspace)
        XCTAssertEqual(mode, .search(query: ""))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)
    }

    func testReturnAndShowBrowseApplyFilterButNeverInsert() {
        var mode: EmojiKeyboardMode = .search(query: "wave")
        var effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryReturn)
        XCTAssertEqual(mode, .browse(category: .smileys, filter: "wave"))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)

        mode = .search(query: "hands")
        effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .showBrowse)
        XCTAssertEqual(mode, .browse(category: .smileys, filter: "hands"))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)

        mode = .search(query: "")
        effects = EmojiKeyboardReducer.reduce(mode: &mode, action: .queryReturn)
        XCTAssertEqual(mode, .browse(category: .smileys, filter: nil))
        XCTAssertEqual(effects, [])
        assertNoHostInsert(effects)
    }

    func testOnlyGlyphSelectionEmitsHostInsertion() {
        assertReduction(
            .browse(category: .people, filter: nil),
            .selectEmoji("👋🏻"),
            becomes: .browse(category: .people, filter: nil),
            effects: [.insertEmoji("👋🏻")]
        )
        assertReduction(
            .search(query: "wave"),
            .selectEmoji("👋"),
            becomes: .search(query: "wave"),
            effects: [.insertEmoji("👋")]
        )
        assertReduction(.typing, .selectEmoji("👋"), becomes: .typing, effects: [])
        assertReduction(
            .browse(category: .people, filter: nil),
            .selectEmoji(""),
            becomes: .browse(category: .people, filter: nil),
            effects: []
        )
    }

    func testBrowseBackspaceAndNextKeyboardAreModeBound() {
        assertReduction(
            .browse(category: .symbols, filter: nil),
            .browseBackspace,
            becomes: .browse(category: .symbols, filter: nil),
            effects: [.deleteBackward]
        )
        assertReduction(
            .search(query: "x"),
            .browseBackspace,
            becomes: .search(query: "x"),
            effects: []
        )
        assertReduction(.typing, .browseBackspace, becomes: .typing, effects: [])

        assertReduction(
            .browse(category: .flags, filter: nil),
            .nextKeyboard,
            becomes: .browse(category: .flags, filter: nil),
            effects: [.advanceToNextKeyboard]
        )
        assertReduction(
            .search(query: "flag"),
            .nextKeyboard,
            becomes: .search(query: "flag"),
            effects: [.advanceToNextKeyboard]
        )
        assertReduction(.typing, .nextKeyboard, becomes: .typing, effects: [])
    }

    func testShowTypingClearsStateAndRefreshesAtPublicBoundaryOnce() {
        assertReduction(
            .browse(category: .food, filter: "cake"),
            .showTyping,
            becomes: .typing,
            effects: [.refreshTypingIfPublic]
        )
        assertReduction(
            .search(query: "cake"),
            .showTyping,
            becomes: .typing,
            effects: [.refreshTypingIfPublic]
        )
        assertReduction(.typing, .showTyping, becomes: .typing, effects: [])
    }

    func testFailuresFailClosedWithoutInsertion() {
        var result = reduce(.browse(category: .travel, filter: nil), .catalogFailed)
        XCTAssertEqual(result.mode, .typing)
        XCTAssertEqual(result.effects, [.announceUnavailable])
        assertNoHostInsert(result.effects)

        result = reduce(.search(query: "car"), .catalogFailed)
        XCTAssertEqual(result.mode, .typing)
        XCTAssertEqual(result.effects, [.announceUnavailable])
        assertNoHostInsert(result.effects)

        result = reduce(.search(query: "car"), .searchFailed)
        XCTAssertEqual(result.mode, .browse(category: .smileys, filter: nil))
        XCTAssertEqual(result.effects, [.announceUnavailable])
        assertNoHostInsert(result.effects)

        assertReduction(.typing, .catalogFailed, becomes: .typing, effects: [])
        assertReduction(.typing, .searchFailed, becomes: .typing, effects: [])
    }

    func testEveryQueryKeyAndReturnTransitionHasNoHostInsertEffect() {
        let modes: [EmojiKeyboardMode] = [
            .typing,
            .browse(category: .smileys, filter: nil),
            .search(query: "wave"),
        ]
        let actions: [EmojiKeyboardAction] = [
            .queryText("x"),
            .queryText(" "),
            .queryBackspace,
            .queryReturn,
        ]

        for mode in modes {
            for action in actions {
                assertNoHostInsert(reduce(mode, action).effects)
            }
        }
    }

    func testUnsupportedTransitionsArePureNoOps() {
        let cases: [(EmojiKeyboardMode, [EmojiKeyboardAction])] = [
            (.typing, [.queryText("x"), .queryBackspace, .queryReturn, .showBrowse]),
            (
                .browse(category: .animals, filter: "cat"),
                [.queryText("x"), .queryBackspace, .queryReturn, .showBrowse, .searchFailed]
            ),
            (.search(query: "cat"), [.openEmoji, .openSearch]),
        ]

        for (mode, actions) in cases {
            for action in actions {
                assertReduction(mode, action, becomes: mode, effects: [])
            }
        }
    }
}
