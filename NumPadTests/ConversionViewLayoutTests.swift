import XCTest
import UIKit
@testable import NumPad

/// Regression guard for the "converter cut off at default keyboard height" bug (2.1.1).
///
/// The keyboard presents `ConversionView` (Math pack → long-press "=") in a top band that is
/// `overlayBandFraction` (50%) of the keyboard's height, inset 10pt on each side
/// (`KeyboardViewController.installOverlayAbove`). At the default iPhone height (300pt) that band is
/// only 150pt tall, and the old stacked layout (~290pt of content) hid From/To, Insert and Close
/// below the fold, so a conversion could not be completed. These tests lay out the *real* view at
/// that size and require every control a conversion needs to be fully visible without scrolling.
///
/// `ConversionView.swift` is compiled into the app target as well as the Keyboard target purely so
/// it can be exercised here (the Keyboard extension has no unit-test target).
final class ConversionViewLayoutTests: XCTestCase {

    /// Mirrors `KeyboardViewController.overlayBandFraction` (private to the Keyboard target).
    private static let overlayBandFraction: CGFloat = 0.5
    /// Mirrors the 10pt leading/trailing inset `installOverlayAbove` applies to the band.
    private static let bandHorizontalInset: CGFloat = 10

    /// Portrait widths of every iPhone class supported on iOS 16+ (SE/mini → Pro Max).
    private static let iPhoneWidths: [CGFloat] = [375, 390, 393, 402, 414, 428, 430, 440]

    private static var defaultBandHeight: CGFloat {
        KeyboardHeightPreset.regular.baseHeight(idiom: .phone) * overlayBandFraction
    }

    private func makeLaidOutView(width: CGFloat,
                                 height: CGFloat = defaultBandHeight,
                                 entitled: Set<NumPad.UnitConverter.Category> = Set(NumPad.UnitConverter.Category.allCases)) -> ConversionView {
        let view = ConversionView(frame: CGRect(x: 0, y: 0,
                                                width: width - 2 * Self.bandHorizontalInset,
                                                height: height),
                                  entitledCategories: entitled)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    private func allSubviews(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(allSubviews(of:))
    }

    private func button(titled title: String, in view: UIView) -> UIButton? {
        allSubviews(of: view).compactMap { $0 as? UIButton }.first { $0.title(for: .normal) == title }
    }

    /// Asserts `control` lies entirely within the overlay's visible (unscrolled, unclipped) area.
    private func assertFullyVisible(_ control: UIView?, named name: String,
                                    in overlay: ConversionView, width: CGFloat,
                                    file: StaticString = #filePath, line: UInt = #line) {
        guard let control else {
            XCTFail("\(name) not found in ConversionView", file: file, line: line)
            return
        }
        guard let scroll = allSubviews(of: overlay).compactMap({ $0 as? UIScrollView }).first else {
            XCTFail("ConversionView scroll container not found", file: file, line: line)
            return
        }
        let visible = scroll.frame.intersection(overlay.bounds)
        let frame = control.convert(control.bounds, to: overlay)
        XCTAssertFalse(frame.isEmpty, "\(name) has an empty frame at width \(width)", file: file, line: line)
        XCTAssertTrue(visible.insetBy(dx: -0.5, dy: -0.5).contains(frame),
                      "\(name) \(frame) is clipped outside the visible area \(visible) at width \(width) × default height",
                      file: file, line: line)
    }

    // MARK: - The bug

    func testEveryConversionControlIsVisibleAtDefaultKeyboardHeight() {
        for width in Self.iPhoneWidths {
            let overlay = makeLaidOutView(width: width)
            let segmented = allSubviews(of: overlay).compactMap { $0 as? UISegmentedControl }
            let fields = allSubviews(of: overlay).compactMap { $0 as? UITextField }

            XCTAssertEqual(segmented.count, 3, "expected category, from and to controls")
            assertFullyVisible(fields.first, named: "Amount field", in: overlay, width: width)
            for (index, control) in segmented.enumerated() {
                assertFullyVisible(control, named: "Segmented control #\(index)", in: overlay, width: width)
            }
            assertFullyVisible(button(titled: "Insert", in: overlay), named: "Insert button", in: overlay, width: width)
            assertFullyVisible(button(titled: "Close", in: overlay), named: "Close button", in: overlay, width: width)
        }
    }

    func testContentNeedsNoScrollingAtDefaultKeyboardHeight() {
        for width in Self.iPhoneWidths {
            let overlay = makeLaidOutView(width: width)
            guard let scroll = allSubviews(of: overlay).compactMap({ $0 as? UIScrollView }).first else {
                return XCTFail("ConversionView scroll container not found")
            }
            XCTAssertLessThanOrEqual(scroll.contentSize.height, scroll.bounds.height + 0.5,
                                     "converter content overflows its band at width \(width) × default height")
        }
    }

    // MARK: - Unchanged behavior

    func testActionButtonsKeepMinimumTapTarget() {
        let overlay = makeLaidOutView(width: 402)
        XCTAssertGreaterThanOrEqual(button(titled: "Insert", in: overlay)?.frame.height ?? 0, 44)
        XCTAssertGreaterThanOrEqual(button(titled: "Close", in: overlay)?.frame.height ?? 0, 44)
    }

    func testTitleStillShown() {
        let overlay = makeLaidOutView(width: 402)
        let titles = allSubviews(of: overlay).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(titles.contains("Convert"), "the 'Convert' title is what the UI test keys off")
    }

    /// Shorter-than-default bands (e.g. landscape) still keep the scroll fallback so every control
    /// stays reachable even when it can't all fit at once.
    func testShortBandStillScrollsToReachEverything() {
        let overlay = makeLaidOutView(width: 402, height: 80)
        guard let scroll = allSubviews(of: overlay).compactMap({ $0 as? UIScrollView }).first else {
            return XCTFail("ConversionView scroll container not found")
        }
        XCTAssertTrue(scroll.isScrollEnabled)
        let close = button(titled: "Close", in: overlay)
        let insert = button(titled: "Insert", in: overlay)
        for control in [close, insert].compactMap({ $0 }) {
            let frame = control.convert(control.bounds, to: scroll)
            XCTAssertLessThanOrEqual(frame.maxY, scroll.contentSize.height + 0.5,
                                     "a control lies beyond the scrollable content")
        }
    }

    func testInsertComputesConversionThroughDelegate() {
        final class Spy: ConversionViewDelegate {
            var computed: String?
            func conversionView(_ view: ConversionView, didCompute value: String) { computed = value }
            func conversionViewDidRequestClose(_ view: ConversionView) {}
            func conversionViewDidSelectLockedCategory(_ view: ConversionView) {}
        }
        let overlay = makeLaidOutView(width: 402)
        let spy = Spy()
        overlay.delegate = spy
        overlay.append("1")
        overlay.append("0")
        overlay.apply()
        // Default Length pair is cm → in: 10 cm = 3.937… in.
        XCTAssertEqual(spy.computed, Calculator.format(NumPad.UnitConverter.convert(10, from: "cm", to: "in")!))
    }
}
