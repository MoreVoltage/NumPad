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
}
