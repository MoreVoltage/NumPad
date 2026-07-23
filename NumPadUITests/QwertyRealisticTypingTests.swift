//
//  QwertyRealisticTypingTests.swift
//  NumPadUITests
//
//  Realistic-typing E2E scenarios for the QWERTY (NumPad Type) page — the automated half of
//  docs/plans/full-keyboard/2026-07-21-typing-test-protocol.md. Each test types a real
//  sentence key-by-key through the extension process and asserts the FINAL text, so the whole
//  pipeline (shift machine, autocap, boundary autocorrect, suggestion chips, revert) is
//  exercised the way a user exercises it. Two of these are regression nets for live device
//  bugs fixed on this branch:
//    - 1e60372b: QwertyKeyboardView.hitTest stole suggestion-bar touches (chip taps dead) —
//      see testSuggestionChipTapInsertsCandidate.
//    - 386b010b: autocap engaged on transiently-empty proxy context after replaceCurrentWord
//      bursts (phantom mid-sentence capitals) — see testAutocorrectRepairsDoubledLetters and
//      testFastTypingBurstNoPhantomCapitals.
//
//  Setup/navigation helpers are adapted from QwertyTypeSmokeTests (which first solved keyboard
//  enablement via Settings.app, either-page detection, and stable-label anchoring). Letter keys
//  are NEVER anchored by a fixed-case label — autocap relabels the whole grid — so typing taps
//  whichever case of a letter currently exists and the assertions judge the OUTPUT.
//
//  DETERMINISM / cross-run contamination: the personal dictionary persists in the app group and
//  protects a word from autocorrect after 3 recorded acceptances. The typo words these tests
//  rely on being CORRECTED ("teh", "helllo", "accomodate") must therefore never accumulate
//  acceptances: they are always either replaced at the boundary (no acceptance recorded), or —
//  in the literal-chip test — a DEDICATED typo ("fone") is used so its acceptances can't leak
//  into the correction-dependent tests. The revert test deliberately stops after the revert
//  (typing a boundary after it would record an acceptance of "teh").
//

import XCTest

final class QwertyRealisticTypingTests: XCTestCase {

    /// Settings.app enablement survives across tests in one runner process — drive it once and
    /// skip the (slow, flake-prone) Settings navigation for every later test in the run.
    private static var keyboardEnsuredThisProcess = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Page detection + raising (adapted from QwertyTypeSmokeTests)

    /// QWERTY page frontmost: its two unique utility keys carry stable accessibility labels.
    /// Letter keys can't anchor this (autocap relabels "q"/"Q"), and the number row can't
    /// either (a pack row may occupy the strip).
    private func isQwertyPageActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists && app.buttons["NumPad"].firstMatch.exists
    }

    /// NumPad keyboard (either page) frontmost — both pages carry the "Switch pack" key; no
    /// system keyboard has one.
    private func isNumPadKeyboardRaised(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists
    }

    /// Makes the NumPad keyboard active via the system globe's long-press picker (tap-cycle
    /// fallback). `includeAppButtons` stays false: the QWERTY page's own page-switch key is a
    /// button labeled exactly "NumPad" and must never be mistaken for a picker row.
    @discardableResult
    private func activateNumPadKeyboard(_ app: XCUIApplication) -> Bool {
        switchToKeyboard(app, named: "NumPad", includeAppButtons: false,
                         isActive: { self.isNumPadKeyboardRaised($0) })
    }

    /// Brings the QWERTY page frontmost. Unlike the smoke's goToQwertyPage, this does NOT force
    /// a numpad-page round trip when the keyboard restored straight onto QWERTY (last-used page
    /// persistence): these tests exercise typing, not the strip's numpad-context semantics, so
    /// the fast path is both sufficient and faster.
    @discardableResult
    private func ensureQwertyPage(_ app: XCUIApplication) -> Bool {
        if isQwertyPageActive(app) { return true }
        let letters = app.buttons["Letters"].firstMatch
        guard letters.waitForExistence(timeout: 5) else { return false }
        letters.tap()
        Thread.sleep(forTimeInterval: 0.8)
        return isQwertyPageActive(app)
    }

    /// Generic keyboard switch via the system globe's long-press picker (verbatim from
    /// QwertyTypeSmokeTests — see there for the picker-row label taxonomy on this runtime).
    @discardableResult
    private func switchToKeyboard(_ app: XCUIApplication, named name: String,
                                  includeAppButtons: Bool,
                                  isActive: (XCUIApplication) -> Bool) -> Bool {
        if isActive(app) { return true }
        let tutorialContinue = app.buttons["Continue"]
        if tutorialContinue.waitForExistence(timeout: 2) {
            tutorialContinue.tap()
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let globe = app.buttons["Next keyboard"].firstMatch
            guard globe.waitForExistence(timeout: 4) else { break }
            globe.press(forDuration: 1.2)
            let pickerRow = NSPredicate(
                format: "label == %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
                name, name + " \u{2014}", name + ",")
            var candidates = [app.cells.matching(pickerRow).firstMatch,
                              springboard.cells.matching(pickerRow).firstMatch,
                              springboard.staticTexts[name].firstMatch,
                              springboard.buttons[name].firstMatch]
            if includeAppButtons {
                candidates.append(app.staticTexts[name].firstMatch)
                candidates.append(app.buttons[name].firstMatch)
            }
            if let menuItem = candidates.first(where: { $0.waitForExistence(timeout: 2) }) {
                menuItem.tap()
            } else {
                // No picker appeared — treat the press as a plain tap-cycle step.
                globe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 1.5)
            if tutorialContinue.exists { tutorialContinue.tap() }
            if isActive(app) { return true }
        }
        return isActive(app)
    }

    /// Shared per-test entry: keyboard enabled (Settings driven at most once per process),
    /// app launched onto the debug typing surface with Pro + rollout flags, NumPad keyboard
    /// active, QWERTY page frontmost. Returns nil after its own XCTFail describing the step
    /// that didn't resolve.
    private func raiseQwertyTypingSurface() -> (app: XCUIApplication, field: XCUIElement)? {
        if !Self.keyboardEnsuredThisProcess {
            guard ensureKeyboardEnabled() else { return nil }
            Self.keyboardEnsuredThisProcess = true
        }
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "fullkeyboard?enabled=1", "typing"])
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 20) else {
            XCTFail("typing surface never appeared")
            return nil
        }
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            guard waitForAnyKeyboard(app, timeout: 10) else {
                XCTFail("no keyboard ever appeared on the typing surface")
                return nil
            }
        }
        guard activateNumPadKeyboard(app) else {
            attachScreenshot(named: "keyboard-switch-failed")
            XCTFail("could not make the NumPad keyboard active")
            return nil
        }
        guard ensureQwertyPage(app) else {
            attachScreenshot(named: "qwerty-page-failed")
            XCTFail("could not reach the QWERTY page")
            return nil
        }
        return (app, field)
    }

    // MARK: - Typing

    /// Types `text` key-by-key on the QWERTY page. Spaces tap the "space" bar; every other
    /// character is looked up by EITHER case of its label (autocap/shift relabel the whole
    /// letter grid, and exactly one casing of each letter key exists at any moment — for
    /// case-invariant keys like "." both queries are the same). The tap inserts whatever case
    /// the shift machine dictates, so autocap itself stays under test: callers assert the
    /// final text, never the tap sequence. No artificial delays — XCUITest's own pacing is
    /// the "fast typing" the burst test wants.
    private func typeOnQwerty(_ app: XCUIApplication, _ text: String) {
        for character in text {
            if character == " " {
                app.buttons["space"].firstMatch.tap()
                continue
            }
            tapKeyEitherCase(app, String(character))
        }
    }

    private func tapKeyEitherCase(_ app: XCUIApplication, _ character: String) {
        for _ in 0..<3 {
            let lower = app.buttons[character.lowercased()].firstMatch
            if lower.exists {
                lower.tap()
                return
            }
            let upper = app.buttons[character.uppercased()].firstMatch
            if upper.exists {
                upper.tap()
                return
            }
            Thread.sleep(forTimeInterval: 0.3)  // grid mid-relabel — retry with a fresh query
        }
        XCTFail("no key labeled '\(character)' in either case on the current layer")
    }

    /// Final-text read: one settle beat so the last extension-side edit lands in the field's
    /// accessibility value before judging it.
    private func settledText(of field: XCUIElement) -> String {
        Thread.sleep(forTimeInterval: 0.8)
        return (field.value as? String) ?? ""
    }

    // MARK: - 1. Clean sentence (phantom-capitals regression net, no-correction path)

    func testCleanSentenceTypesVerbatim() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        // Every word is correctly spelled — no boundary may rewrite anything. The trailing
        // space pushes the last word through its boundary pass too.
        typeOnQwerty(app, "the quick brown fox jumps over the lazy dog ")
        let text = settledText(of: field)
        attachScreenshot(named: "clean-sentence")
        // Full equality: exactly one capital (the autocap'd sentence start) and nothing else
        // changed. Any phantom mid-sentence capital or spurious "correction" fails here.
        XCTAssertEqual(text, "The quick brown fox jumps over the lazy dog ",
                       "clean sentence must land verbatim with only the autocap'd first letter")
    }

    // MARK: - 2. Boundary autocorrect repairs + lowercase continuation

    func testAutocorrectRepairsDoubledLetters() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        // "helllo" → doubling repair "hello" (typo-variant head slot, case-matched to the
        // autocap'd "Helllo"); "accomodate" → "accommodate" (checker guess). The words AFTER
        // each correction ("there", "them") are the phantom-capitals regression net: before
        // 386b010b the replaceCurrentWord delete/insert burst left a transiently-empty proxy
        // context that autocap read as a sentence start, capitalizing the next word.
        typeOnQwerty(app, "helllo there. i need to accomodate them ")
        let text = settledText(of: field)
        attachScreenshot(named: "doubled-letter-repairs")
        XCTAssertEqual(text, "Hello there. I need to accommodate them ",
                       "boundary corrections must land and the words following them stay lowercase")
    }

    // MARK: - 3. Suggestion chip tap inserts the candidate (hitTest regression net)

    func testSuggestionChipTapInsertsCandidate() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        typeOnQwerty(app, "teh")
        // The bar shows [literal “Teh” | candidates…] with "The" ranked first (the same
        // pipeline the smoke's autocorrect assert proves). Match the candidate chip
        // case-insensitively: the chip shows the checker's RAW guess (only decide() runs
        // matchCase), and guess casing is an OS-vocabulary detail, not ours to pin.
        let candidateChip = app.buttons.matching(
            NSPredicate(format: "label ==[c] 'the'")).firstMatch
        guard candidateChip.waitForExistence(timeout: 5) else {
            attachScreenshot(named: "chip-missing")
            return XCTFail("suggestion bar never offered a 'the' candidate chip for 'teh'")
        }
        // Regression net for 1e60372b: tap the chip near its BOTTOM edge (~6.6pt above the
        // key grid on the 44pt bar — outside the keyboard's 4pt hitTest slop). Before the fix
        // the keyboard's zero-dead-zone routing claimed every bar touch and a top-row letter
        // was inserted instead; this tap is the closest simulator reproduction of the dead
        // device chips.
        candidateChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        let text = settledText(of: field)
        attachScreenshot(named: "chip-candidate-tapped")
        // Case-insensitive on the SAME OS-casing grounds as the chip query; the length pins
        // everything else: replacement happened ("teh" gone), the chip's trailing space
        // landed, and — critically — no top-row letter was inserted (the pre-fix failure
        // left "Teh" + a stolen letter, which can never lowercase to "the ").
        XCTAssertEqual(text.lowercased(), "the ",
                       "chip tap must replace the word and append a space — never a top-row letter")
    }

    // MARK: - 4. Literal chip keeps the typed word (and blocks re-correction)

    func testChipLiteralKeepsTypedWord() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        // DEDICATED typo for this test: the literal-chip tap records a personal-dictionary
        // acceptance, so reusing "teh" here would eventually (3 acceptances persisted in the
        // app group) protect it from autocorrect and break the correction-dependent tests on
        // later runs. "fone" appears nowhere else; it becoming personally known only makes
        // this test's own expectation MORE certain.
        typeOnQwerty(app, "fone")
        // The literal slot is always first and shows the typed word in curly quotes.
        let literalChip = app.buttons["\u{201C}Fone\u{201D}"].firstMatch
        guard literalChip.waitForExistence(timeout: 5) else {
            attachScreenshot(named: "literal-chip-missing")
            return XCTFail("suggestion bar never offered the literal \u{201C}Fone\u{201D} chip")
        }
        literalChip.tap()
        // The literal tap accepts the word as typed (inserting the trailing space itself) and
        // registers a session-wide rejection — typing the same word again must survive its
        // boundary uncorrected.
        typeOnQwerty(app, "fone ")
        let text = settledText(of: field)
        attachScreenshot(named: "literal-chip-kept")
        XCTAssertEqual(text, "Fone fone ",
                       "literal chip must keep the typed form and block re-correction at later boundaries")
    }

    // MARK: - 5. Sentence punctuation autocap

    func testSentencePunctuationAutocap() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        // "." lives on the letters layer (period/comma flank space by default). The word after
        // ". " must get its capital ("And"); every mid-sentence word must not.
        typeOnQwerty(app, "this is one. and this is two.")
        let text = settledText(of: field)
        attachScreenshot(named: "sentence-autocap")
        XCTAssertEqual(text, "This is one. And this is two.",
                       "autocap must fire at the sentence start and after '. ' — nowhere else")
    }

    // MARK: - 6. Backspace reverts the last autocorrect

    func testBackspaceRevertsAutocorrect() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        typeOnQwerty(app, "teh ")
        // Precondition: the boundary correction fired (same assert as the smoke) — without it
        // there is nothing to revert and the failure should point here, not at the revert.
        XCTAssertEqual(settledText(of: field), "The ",
                       "boundary autocorrect must fire before the revert can be tested")
        // ACTUAL revert mechanics (QwertyAutocorrectHistory.consumeRevert +
        // QwertyPageHost.handleBackspace, pinned here): ONE backspace immediately after the
        // correction consumes the boundary character AND the corrected word, restoring the
        // typed original WITHOUT a trailing space — "The " becomes "Teh", not "Teh ". The
        // reverted word is also remembered (session reject list) so it won't re-correct.
        app.buttons["Delete"].firstMatch.tap()
        let text = settledText(of: field)
        attachScreenshot(named: "revert-after-backspace")
        XCTAssertEqual(text, "Teh",
                       "one backspace after the correction must restore the typed original (no trailing space)")
        // Deliberately END here: typing another boundary would record a personal-dictionary
        // acceptance of "teh" (kept-as-typed words are learned), and 3 persisted acceptances
        // would protect "teh" from autocorrect — silently breaking this test and the chip
        // test on later runs against the same simulator.
    }

    // MARK: - 7. Fast continuous burst — no phantom capitals

    func testFastTypingBurstNoPhantomCapitals() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        // 20 words typed continuously with no delays beyond XCUITest's own pacing — the
        // closest simulator approximation of the owner's real-world fast-typing report that
        // surfaced the phantom-capitals bug. Every word is correctly spelled so the expected
        // output is fully deterministic.
        let burst = "no word after the first one should ever get a stray capital letter while we type this long test line "
        typeOnQwerty(app, burst)
        let text = settledText(of: field)
        attachScreenshot(named: "fast-burst")
        // Targeted assert first so a phantom-capital failure names the regression directly.
        let strayCapitals = text.dropFirst().filter { $0.isUppercase }
        XCTAssertEqual(String(strayCapitals), "",
                       "phantom capitals appeared mid-burst: \(text)")
        XCTAssertEqual(text, "No word after the first one should ever get a stray capital letter while we type this long test line ",
                       "burst paragraph must land verbatim with only the leading autocap")
    }

    // MARK: - 8. Space tap/swipe/cursor interaction

    func testSpaceTapQuickSwipeAndHoldCursorInteraction() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        typeOnQwerty(app, "abc")

        let space = app.buttons["space"].firstMatch
        XCTAssertTrue(space.waitForExistence(timeout: 3))
        space.tap()

        // A sub-threshold swipe still means Space. Keep both coordinates inside the key so
        // this specifically tests gesture arbitration rather than UIControl hit slop.
        let quickStart = space.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        let quickEnd = space.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        quickStart.press(forDuration: 0.1, thenDragTo: quickEnd)
        XCTAssertEqual(settledText(of: field), "Abc  ",
                       "tap and quick swipe must each insert exactly one Space")

        typeOnQwerty(app, "de")
        let beforeCursorMove = settledText(of: field)
        let cursorStart = space.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        let cursorEnd = space.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        cursorStart.press(forDuration: 0.5, thenDragTo: cursorEnd)
        typeOnQwerty(app, "x")

        let text = settledText(of: field)
        attachScreenshot(named: "space-hold-cursor")
        XCTAssertEqual(text.count, beforeCursorMove.count + 1,
                       "cursor mode must not insert a Space when the hold ends")
        XCTAssertNotEqual(text, beforeCursorMove + "x",
                          "hold-then-drag must move the caret before the next insertion")
    }

    // MARK: - 9. Alternate callout release

    func testAlternateCalloutInsertsUppercaseSelectionOnRelease() throws {
        guard let (app, field) = raiseQwertyTypingSurface() else { return }
        let eKey = app.buttons["E"].firstMatch
        XCTAssertTrue(eKey.waitForExistence(timeout: 3))

        eKey.press(forDuration: 0.6)

        let text = settledText(of: field)
        attachScreenshot(named: "alternate-release")
        let uppercaseAlternates = Set(["È", "É", "Ê", "Ë", "Ē", "Ė", "Ę"])
        XCTAssertTrue(uppercaseAlternates.contains(text),
                      "release from the E callout must insert the highlighted uppercase alternate")
        XCTAssertEqual(app.sheets.count, 0,
                       "alternates must be an attached key callout, never an action sheet")
    }
}
