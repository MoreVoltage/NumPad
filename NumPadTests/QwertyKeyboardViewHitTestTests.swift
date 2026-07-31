import UIKit
import XCTest
@testable import NumPad

final class QwertyKeyboardViewHitTestTests: XCTestCase {

    private enum Canvas {
        static let size = CGSize(width: 375, height: 260)
    }

    /// A laid-out letters-layer keyboard with a digit top strip — the same shape the page
    /// host renders on iPhone.
    private func makeLaidOutView() -> QwertyKeyboardView {
        let view = QwertyKeyboardView(frame: CGRect(origin: .zero, size: Canvas.size))
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            QwertyKey(kind: .character($0, shifted: $0), width: 1)
        }
        view.configure(rows: QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions()),
                       topStrip: digits)
        view.layoutIfNeeded()
        return view
    }

    private func makeLaidOutPadView(mode: QwertyLayoutMode) -> QwertyKeyboardView {
        let previous = UserPrefs.qwertyLayoutMode
        UserPrefs.qwertyLayoutMode = mode
        defer { UserPrefs.qwertyLayoutMode = previous }

        let host = UIViewController()
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceIdiom: .pad),
                UITraitCollection(horizontalSizeClass: .regular),
            ]),
            forChild: child
        )
        let view = QwertyKeyboardView(
            frame: CGRect(x: 0, y: 0, width: 1024, height: Canvas.size.height)
        )
        child.view.addSubview(view)
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            QwertyKey(kind: .character($0, shifted: $0), width: 1)
        }
        view.configure(rows: QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions()),
                       topStrip: digits)
        view.layoutIfNeeded()
        return view
    }

    // MARK: - Suggestion-bar protection
    // The suggestion bar sits directly above the keyboard (`QwertyPageHost` pins
    // keyboardView.top to suggestionBar.bottom) and the container hit-tests the keyboard
    // first. A bar touch converts to a negative-y point in keyboard coordinates; the
    // keyboard must decline it so the touch falls through to the bar's chips.

    func testPointWellAboveTopEdgeIsNotClaimed() {
        let view = makeLaidOutView()
        XCTAssertNil(view.hitTest(CGPoint(x: view.bounds.midX, y: -10), with: nil),
                     "a suggestion-bar touch must never be routed to a top-row key")
    }

    // MARK: - Zero-dead-zone routing inside the keyboard is unchanged

    func testInBoundsGapPointStillRoutesToAKey() {
        let view = makeLaidOutView()
        // y = 2 is inside bounds but above the first row of keycaps (top inset is 6pt):
        // a gap point `super.hitTest` resolves to the container itself.
        let result = view.hitTest(CGPoint(x: view.bounds.midX, y: 2), with: nil)
        XCTAssertTrue(result is QwertyKeyButton,
                      "an in-bounds gap touch must still resolve to a key")
    }

    func testPointAHairBelowBottomEdgeStillRoutes() {
        let view = makeLaidOutView()
        // Real touch events near an edge can report a hair outside bounds; within the slop
        // the keyboard still claims them (no sibling sits below to steal from).
        let result = view.hitTest(CGPoint(x: view.bounds.midX, y: view.bounds.height + 2),
                                  with: nil)
        XCTAssertTrue(result is QwertyKeyButton,
                      "an edge touch within the slop must still resolve to a key")
    }

    func testIPadStandardUsesItsFullPaneWithoutLegacySplitRouting() {
        let previousLayout = UserPrefs.iPadQwertyLayout
        let previousLegacyMode = UserPrefs.qwertyLayoutMode
        UserPrefs.iPadQwertyLayout = .standard
        UserPrefs.qwertyLayoutMode = .split
        defer {
            UserPrefs.iPadQwertyLayout = previousLayout
            UserPrefs.qwertyLayoutMode = previousLegacyMode
        }

        let view = makeLaidOutPadView(mode: .split)

        XCTAssertEqual(view.layoutContentFrame, view.bounds)
        XCTAssertNil(view.layoutSplitGap)
        XCTAssertTrue(view.hitTest(CGPoint(x: view.bounds.midX, y: view.bounds.midY), with: nil)
            is QwertyKeyButton)
    }

    func testLegacyCenteredSettingDoesNotCreateABlankMarginInStandardPane() {
        let view = makeLaidOutPadView(mode: .centered)
        let result = view.hitTest(
            CGPoint(x: 20, y: view.bounds.midY),
            with: nil
        )
        XCTAssertTrue(
            result is QwertyKeyButton,
            "Standard must route across its entire host-provided pane despite a legacy preference"
        )
    }

    func testPersonalizationOffsetsAreDenormalizedAgainstTransformedPadFrames() throws {
        let view = makeLaidOutPadView(mode: .compactRight)
        view.rebuildTouchOffsets { base in
            base.lowercased() == "q" ? (dx: 0.5, dy: -0.25) : nil
        }
        let qButton = try XCTUnwrap(view.subviews.compactMap { $0 as? QwertyKeyButton }.first {
            if case .character(let base, _) = $0.key.kind {
                return base.lowercased() == "q"
            }
            return false
        })
        let vector = try XCTUnwrap(view.touchOffsets.values.first)

        XCTAssertEqual(vector.dx, qButton.frame.width * 0.5, accuracy: 0.001)
        XCTAssertEqual(vector.dy, qButton.frame.height * -0.25, accuracy: 0.001)
        XCTAssertEqual(view.layoutContentFrame, view.bounds)
    }

    func testLegacySplitSettingKeepsTheStandardPaneCenterRoutable() {
        let view = makeLaidOutPadView(mode: .split)
        let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        XCTAssertNil(view.layoutSplitGap)
        XCTAssertTrue(view.hitTest(point, with: nil) is QwertyKeyButton)
        XCTAssertNotNil(view.glideKeyIndex(at: point))
    }

    func testLegacySplitSettingDoesNotCreateAGlideDeadZone() {
        let view = makeLaidOutPadView(mode: .split)
        let centerPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        XCTAssertTrue(view.isGlideOriginPoint(centerPoint))

        let recognizer = QwertyGlideGestureRecognizer()
        recognizer.keyIndexAt = { view.glideKeyIndex(at: $0) }
        recognizer.recordSample(at: centerPoint)
        XCTAssertTrue(
            !recognizer.points.isEmpty,
            "a Standard pane must not retain the legacy split gap's glide dead zone"
        )
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
