import Foundation
import XCTest

final class EmojiPageHostSourceContractTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func section(
        _ source: String,
        from start: String,
        through end: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let startRange = try XCTUnwrap(source.range(of: start), file: file, line: line)
        let endRange = try XCTUnwrap(
            source.range(of: end, range: startRange.upperBound..<source.endIndex),
            file: file,
            line: line
        )
        return String(source[startRange.lowerBound..<endRange.upperBound])
    }

    func testOrdinaryQwertyInitializationStoresButDoesNotInvokeEmojiFactory() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        XCTAssertTrue(host.contains("private let emojiLoaderFactory: () -> EmojiResourceLoading"))
        XCTAssertTrue(host.contains("self.emojiLoaderFactory = emojiLoaderFactory"))
        let initializer = try section(host, from: "init(hostViewController:", through: "deinit {")
        XCTAssertFalse(initializer.contains("self.emojiLoader = emojiLoaderFactory()"))
        XCTAssertFalse(initializer.contains("EmojiKeyboardView(items:"))
    }

    func testSmileySearchAndResultsRouteThroughReducerWithoutQueryHostInsertion() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        XCTAssertTrue(host.contains("EmojiKeyboardReducer.reduce"))
        XCTAssertTrue(host.contains("dispatchEmoji(.openEmoji)"))
        XCTAssertTrue(host.contains("dispatchEmoji(.openSearch)"))
        XCTAssertTrue(host.contains("dispatchEmoji(.selectEmoji(sequence))"))

        let routing = try section(
            host,
            from: "private func routeEmojiSearchKey",
            through: "private func applyEmojiEffects"
        )
        for action in [".queryText(", ".queryBackspace", ".queryReturn", ".showBrowse", ".selectEmoji("] {
            XCTAssertTrue(routing.contains(action), "missing internal route \(action)")
        }
        XCTAssertFalse(routing.contains("textDocumentProxy.insertText"))
        XCTAssertTrue(host.contains("index.allResults(for: filter)"))
        XCTAssertTrue(host.contains("search.results(for: query)"))
    }

    func testOnlyEmojiEffectInsertionRecordsMRUAndTouchesHostDocument() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        let effects = try section(
            host,
            from: "private func applyEmojiEffects",
            through: "private func loadEmojiBrowse"
        )
        XCTAssertTrue(effects.contains("case .insertEmoji(let sequence):"))
        XCTAssertTrue(effects.contains("textDocumentProxy.insertText(sequence)"))
        XCTAssertTrue(effects.contains("emojiRecents.record(sequence"))
        XCTAssertTrue(effects.contains("emojiRecentsStore.save(emojiRecents)"))
        XCTAssertTrue(effects.contains("case .deleteBackward:"))
        XCTAssertTrue(effects.contains("textDocumentProxy.deleteBackward()"))
        XCTAssertTrue(effects.contains("case .advanceToNextKeyboard:"))
        XCTAssertTrue(effects.contains("advanceToNextInputMode()"))
    }

    func testTypingRestoreUsesPublicBoundaryAndFailuresFailClosed() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        XCTAssertTrue(host.contains("case .refreshTypingIfPublic:"))
        XCTAssertTrue(host.contains("textDidChange(nil)"))
        XCTAssertTrue(host.contains("dispatchEmoji(.catalogFailed)"))
        XCTAssertTrue(host.contains("dispatchEmoji(.searchFailed)"))
        XCTAssertTrue(host.contains("UIAccessibility.post(notification: .announcement"))
        XCTAssertTrue(host.contains("guard emojiMode == .typing else { return }"))
    }

    func testModeTransitionsMoveVoiceOverFocusDeliberately() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        let keyboard = try source("Keyboard/Views/QwertyKeyboardView.swift")
        XCTAssertTrue(host.contains("moveEmojiAccessibilityFocus(for: action)"))
        XCTAssertTrue(host.contains("argument: view.headingLabel"))
        XCTAssertTrue(host.contains("argument: header"))
        XCTAssertTrue(host.contains("keyboardView.emojiModeButton()"))
        XCTAssertTrue(keyboard.contains("func emojiModeButton() -> QwertyKeyButton?"))
    }

    func testSearchModeDisablesCursorAndGlideAndRestoresNormalSurface() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        let keyboard = try source("Keyboard/Views/QwertyKeyboardView.swift")
        XCTAssertTrue(host.contains("guard case .typing = emojiMode else { return }"))
        XCTAssertTrue(host.contains("keyboardView.setEmojiSearchModeActive(true)"))
        XCTAssertTrue(host.contains("keyboardView.setEmojiSearchModeActive(false)"))
        XCTAssertTrue(keyboard.contains("private(set) var emojiSearchModeIsActive = false"))
        XCTAssertTrue(keyboard.contains("&& !emojiSearchModeIsActive"))
    }

    func testMemoryWarningBridgeAndTeardownAreExplicit() throws {
        let host = try source("Keyboard/Libraries/QwertyPageHost.swift")
        let controller = try source("Keyboard/KeyboardViewController.swift")
        XCTAssertTrue(host.contains("func handleMemoryWarning()"))
        XCTAssertTrue(host.contains("emojiView?.dismissModifierChooser()"))
        XCTAssertTrue(host.contains("emojiLoader?.handleMemoryWarning(isEmojiActive:"))
        XCTAssertTrue(controller.contains("override func didReceiveMemoryWarning()"))
        XCTAssertTrue(controller.contains("qwertyPageHost?.handleMemoryWarning()"))
    }

    func testEnglishEmojiChromeLocalizationInventoryIsCompleteAndValid() throws {
        let requiredKeys = [
            "ABC", "Activities", "Animals", "Choose skin tone", "Delete", "Emoji",
            "Emoji are unavailable right now", "Emoji search", "Flags", "Food", "Letters",
            "Next keyboard", "No emoji found", "Objects", "People", "Recent", "Results",
            "Results for %@", "Search emoji", "Smileys", "Symbols", "Travel",
            "Variants available",
        ]
        let tableURL = repositoryRoot.appendingPathComponent(
            "Keyboard/en.lproj/Localizable.strings"
        )
        let table = try XCTUnwrap(NSDictionary(contentsOf: tableURL) as? [String: String])

        for key in requiredKeys {
            let value = try XCTUnwrap(table[key], "Missing emoji chrome key \(key)")
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertEqual(
                value.components(separatedBy: "%@").count,
                key.components(separatedBy: "%@").count,
                "Placeholder mismatch for \(key)"
            )
        }
    }
}
