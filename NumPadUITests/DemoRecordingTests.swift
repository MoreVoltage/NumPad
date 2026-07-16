//
//  DemoRecordingTests.swift
//  NumPadUITests
//
//  MARKETING VIDEO CAPTURE — not a correctness suite. Each test drives exactly one demo "clip"
//  at human-watchable pacing while an external `simctl io recordVideo` session films the
//  simulator (see marketing/video/captures-2.0/record_clips.sh). The test's only job is to make
//  the right pixels happen in the right order, slowly enough to read; pass/fail matters less
//  than the footage, so every step degrades gracefully with an attached note instead of
//  aborting the recording mid-scene.
//
//  Same conventions as ScreenshotCaptureTests: each test is independent (own launch, own
//  entitlement debug routes), keyboard raising/switching comes from UITestSupport.swift, and
//  real key taps (never `typeText`) drive `textDocumentProxy.insertText` so text-change
//  features (the Live Math Preview chip) fire exactly as they do for a real user.
//

import XCTest

final class DemoRecordingTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true // footage over failure: keep rolling
    }

    // MARK: - Pacing

    /// Watchable-tap cadence. 0.45s reads as deliberate typing on video without dragging.
    private let keyPause: TimeInterval = 0.45
    /// Scene beats: settle before the action starts / hold after it ends so the encoded clip
    /// has clean lead-in/lead-out frames to cut on.
    private func leadIn()  { Thread.sleep(forTimeInterval: 1.5) }
    private func holdShot(_ seconds: TimeInterval = 2.0) { Thread.sleep(forTimeInterval: seconds) }

    /// Taps each NumPad key by its button label at demo pace. Missing keys attach a note and
    /// stop the sequence rather than failing the clip outright.
    private func tapKeysPaced(_ keys: [String], in app: XCUIApplication) {
        for key in keys {
            let button = app.buttons[key]
            guard button.waitForExistence(timeout: 5) else {
                attachNote("key '\(key)' not found — stopping tap sequence", name: "tap-sequence")
                return
            }
            button.tap()
            Thread.sleep(forTimeInterval: keyPause)
        }
    }

    private func attachNote(_ text: String, name: String) {
        let note = XCTAttachment(string: text)
        note.name = name
        note.lifetime = .keepAlways
        add(note)
    }

    /// Home → Keyboard Packs → row named `pack`. Selection persists via the shared app group,
    /// so the follow-up typing-surface launch inherits it (same trick as ScreenshotCaptureTests).
    private func selectPack(named pack: String, in app: XCUIApplication) {
        guard tapRow(in: app, labeled: "Keyboard Packs") else {
            attachNote("'Keyboard Packs' row never appeared", name: "select-pack")
            return
        }
        if !tapRow(in: app, labeled: pack) {
            attachNote("'\(pack)' pack row never appeared", name: "select-pack")
        }
        Thread.sleep(forTimeInterval: 0.8)
    }

    // MARK: - Clip 01: Live Math Preview — type 84.50*1.18, chip computes, tap to insert

    func testClip01_mathPreview() throws {
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=0"])
        selectPack(named: "Math", in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=0"]) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        guard numPadActive else {
            attachNote("NumPad never became the active keyboard", name: "01-outcome")
            return
        }
        leadIn()
        tapKeysPaced(["8", "4", ".", "5", "0", "*", "1", ".", "1", "8"], in: app)

        // CRITICAL: no XCUITest queries AT ALL after typing. Accessibility snapshotting blocks
        // the extension's run loop and the chip's element identity churns between queries (a
        // v3 run proved `.exists` passes but a follow-up `.tap()` re-query misses). The clip
        // simply ends on the chip showing the computed answer — that's the money shot; a pure
        // sleep guarantees it stays undisturbed on camera.
        Thread.sleep(forTimeInterval: 5.5)
        attachNote("typed expression + quiet hold for chip (no queries)", name: "01-outcome")
    }

    // MARK: - Clip 02: Pack switching — cycle the specialized top rows

    func testClip02_packSwitching() throws {
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=1"])
        selectPack(named: "Math", in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=1"]) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        guard numPadActive else {
            attachNote("NumPad never became the active keyboard", name: "02-outcome")
            return
        }
        leadIn()
        let packSwitch = app.buttons["Switch pack"]
        guard packSwitch.waitForExistence(timeout: 5) else {
            attachNote("'Switch pack' key not on the bottom row for this configuration", name: "02-outcome")
            holdShot()
            return
        }
        for _ in 0..<6 { // 6 taps ≈ full cycle through the pack lineup
            packSwitch.tap()
            Thread.sleep(forTimeInterval: 1.1) // long enough to register each new key row
        }
        attachNote("cycled packs via 'Switch pack' × 6", name: "02-outcome")
        holdShot()
    }

    // MARK: - Clip 03: TAX/TIP overlay — long-press "%"

    func testClip03_taxTip() throws {
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=0"])
        selectPack(named: "Math", in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=0"]) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        guard numPadActive else {
            attachNote("NumPad never became the active keyboard", name: "03-outcome")
            return
        }
        leadIn()
        tapKeysPaced(["8", "6", ".", "5", "0"], in: app)

        let percentKey = app.buttons["%"]
        guard percentKey.waitForExistence(timeout: 5) else {
            attachNote("'%' key not found (pack row may not include it)", name: "03-outcome")
            holdShot()
            return
        }
        percentKey.press(forDuration: 0.7)
        holdShot(1.5) // overlay slides in

        // Drive whatever quick-percent buttons the overlay exposes, at demo pace. Labels are
        // best-effort: tapping 1–2 of them is plenty for the clip; absence just holds the shot.
        for label in ["8.25%", "15%", "18%", "20%"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 2), button.isHittable {
                button.tap()
                Thread.sleep(forTimeInterval: 1.2)
            }
        }
        attachNote("tax/tip overlay driven (best-effort quick buttons)", name: "03-outcome")
        holdShot(2.5)
    }

    // MARK: - Clip 04: Conversion overlay — long-press "=" (Pro reach)

    func testClip04_conversion() throws {
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=1"])
        selectPack(named: "Math", in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=1"]) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        guard numPadActive else {
            attachNote("NumPad never became the active keyboard", name: "04-outcome")
            return
        }
        leadIn()
        tapKeysPaced(["1", "2"], in: app)

        let equalsKey = app.buttons["="]
        guard equalsKey.waitForExistence(timeout: 5) else {
            attachNote("'=' key not found on the keyboard", name: "04-outcome")
            holdShot()
            return
        }
        equalsKey.press(forDuration: 0.7)

        let convertTitle = app.staticTexts["Convert"]
        if convertTitle.waitForExistence(timeout: 5) {
            attachNote("Conversion overlay appeared", name: "04-outcome")
        } else {
            attachNote("Conversion overlay did not appear", name: "04-outcome")
        }
        holdShot(3.0) // linger on the converter — the money shot of this clip
    }

    // MARK: - Clip 05: Custom Keyboard editor — Key Library + live preview (Pro)

    func testClip05_customKeyboardEditor() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "editor"])
        let keyLibraryHeader = app.staticTexts["Key Library"]
        guard keyLibraryHeader.waitForExistence(timeout: 20) else {
            XCTFail("Key Library palette section never appeared")
            return
        }
        leadIn()
        holdShot(2.0)
        // No swipes here — a swipe was observed to dismiss the editor sheet mid-clip. Toggle the
        // section checkboxes instead: the live preview visibly restructures, which IS the demo.
        for label in ["Column 1", "Column 2", "Row 1"] {
            let toggle = app.staticTexts[label].firstMatch
            if toggle.waitForExistence(timeout: 3), toggle.isHittable {
                toggle.tap()
                Thread.sleep(forTimeInterval: 1.5)
                toggle.tap() // toggle back on so the clip ends on the full layout
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        attachNote("editor section toggles driven", name: "05-outcome")
        holdShot(2.5)
    }

    // MARK: - Clip 06: Themes — picker tour ending on a premium look

    func testClip06_themes() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1"])
        guard tapRow(in: app, labeled: "Theme") else {
            XCTFail("Home row 'Theme' never appeared")
            return
        }
        let previewCaption = app.staticTexts["Preview"]
        guard previewCaption.waitForExistence(timeout: 10) else {
            XCTFail("Theme screen preview never appeared")
            return
        }
        leadIn()
        // The theme swatches are circles in a grid the query tree doesn't expose as cells
        // (first recording pass proved app.cells taps landed elsewhere). Tap them by normalized
        // window coordinates instead — grid geometry measured from a capture frame: 5 per row,
        // first row centers ≈ y 0.18, second ≈ y 0.26, columns ≈ x .115/.31/.50/.69/.885.
        let win = app.windows.firstMatch
        let swatches: [(CGFloat, CGFloat)] = [
            (0.31, 0.18),  // black
            (0.50, 0.18),  // red
            (0.885, 0.18), // purple
            (0.885, 0.26), // teal
            (0.115, 0.18), // back to white for the closing frame
        ]
        for (x, y) in swatches {
            win.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
            Thread.sleep(forTimeInterval: 1.6)
        }
        attachNote("theme swatch tour complete (coordinate taps)", name: "06-outcome")
        holdShot(2.5)
    }
}
