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
    /// stays reachable even when it can't all fit at once. Every control a conversion needs —
    /// including both unit selectors — must exist (no silent skips), and must be hit-testable once
    /// the scroll view brings it into view.
    func testShortBandsScrollToReachEveryControl() throws {
        // 80pt = 50% of the 160pt landscape clamp; 93.5pt is a landscape band measured in review.
        for (width, height) in [(CGFloat(402), CGFloat(80)), (667, 93.5)] {
            let overlay = makeLaidOutView(width: width, height: height)
            let scroll = try XCTUnwrap(allSubviews(of: overlay).compactMap { $0 as? UIScrollView }.first)
            XCTAssertTrue(scroll.isScrollEnabled)
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height,
                                 "a \(height)pt band should need scrolling, otherwise this test proves nothing")

            let controls = try segmentedControls(in: overlay)
            let required: [(String, UIView?)] = [
                ("Amount field", allSubviews(of: overlay).compactMap { $0 as? UITextField }.first),
                ("Insert button", button(titled: "Insert", in: overlay)),
                ("Close button", button(titled: "Close", in: overlay)),
                ("Category selector", controls.category),
                ("From selector", controls.from),
                ("To selector", controls.to)
            ]
            for (name, view) in required {
                let control = try XCTUnwrap(view, "\(name) missing at \(width)×\(height)")
                let frame = control.convert(control.bounds, to: scroll)
                let maxOffset = scroll.contentSize.height - scroll.bounds.height
                let offset = min(max(frame.midY - scroll.bounds.height / 2, 0), maxOffset)
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                overlay.layoutIfNeeded()

                let center = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: overlay)
                let target = overlay.hitTest(center, with: nil)
                XCTAssertTrue(target === control || target?.isDescendant(of: control) == true,
                              "\(name) isn't tappable after scrolling at \(width)×\(height)")
            }
        }
    }

    // MARK: - Unit labels never truncate (cm/km rendered as "…" on iPhone SE / iPad panel)

    /// Overlay widths that matter: iPhone SE/mini band (375pt screen − 2×10pt band inset) and the
    /// fixed 360pt iPad side panel (`KeyboardViewController.sidePanelWidth`, no extra inset).
    private static let narrowOverlayWidths: [CGFloat] = [375 - 2 * bandHorizontalInset, 360]

    func testUnitLabelsAreNeverTruncatedInNarrowOverlays() throws {
        for overlayWidth in Self.narrowOverlayWidths {
            for category in NumPad.UnitConverter.Category.allCases {
                let overlay = makeLaidOutView(width: overlayWidth + 2 * Self.bandHorizontalInset)
                try select(category, in: overlay)
                let controls = try segmentedControls(in: overlay)
                for (name, control) in [("From", controls.from), ("To", controls.to)] {
                    assertNoTruncatedSegments(control, named: "\(name) \(category)", width: overlayWidth)
                }
            }
        }
    }

    /// The narrow-width fix must not trade horizontal truncation for vertical clipping.
    func testNarrowOverlaysStillFitDefaultHeightWithoutScrolling() throws {
        for overlayWidth in Self.narrowOverlayWidths {
            let overlay = makeLaidOutView(width: overlayWidth + 2 * Self.bandHorizontalInset)
            let scroll = try XCTUnwrap(allSubviews(of: overlay).compactMap { $0 as? UIScrollView }.first)
            XCTAssertLessThanOrEqual(scroll.contentSize.height, scroll.bounds.height + 0.5,
                                     "content overflows the default band at overlay width \(overlayWidth)")
        }
    }

    // MARK: - Unit picker

    func testUnitSelectorsListTheCategoryUnitsWithDefaultPair() throws {
        for category in NumPad.UnitConverter.Category.allCases {
            let overlay = makeLaidOutView(width: 402)
            try select(category, in: overlay)
            let controls = try segmentedControls(in: overlay)
            XCTAssertEqual(titles(of: controls.from), category.units, "From units for \(category)")
            XCTAssertEqual(titles(of: controls.to), category.units, "To units for \(category)")
            XCTAssertEqual(controls.from.selectedSegmentIndex, 0, "default From for \(category)")
            XCTAssertEqual(controls.to.selectedSegmentIndex, 1, "default To for \(category)")
        }
    }

    func testChosenFromAndToUnitsDriveTheConversion() throws {
        let overlay = makeLaidOutView(width: 402)
        let spy = DelegateSpy()
        overlay.delegate = spy
        let controls = try segmentedControls(in: overlay)
        pick("km", in: controls.from)
        pick("mi", in: controls.to)
        overlay.append("5")
        overlay.apply()
        XCTAssertEqual(spy.computed, Calculator.format(NumPad.UnitConverter.convert(5, from: "km", to: "mi")!))

        // Swapping direction converts the other way (guards against From/To being wired backwards).
        pick("mi", in: controls.from)
        pick("km", in: controls.to)
        overlay.apply()
        XCTAssertEqual(spy.computed, Calculator.format(NumPad.UnitConverter.convert(5, from: "mi", to: "km")!))
    }

    func testSwitchingCategoryRebuildsUnitsAndConvertsInThatCategory() throws {
        let overlay = makeLaidOutView(width: 402)
        let spy = DelegateSpy()
        overlay.delegate = spy
        try select(.temperature, in: overlay)
        overlay.append("100")
        overlay.apply()
        XCTAssertEqual(spy.computed, Calculator.format(212))
    }

    func testLockedCategoryIsRefusedAndRoutedToDelegate() throws {
        let overlay = makeLaidOutView(width: 402, entitled: [.volume])
        let spy = DelegateSpy()
        overlay.delegate = spy
        let controls = try segmentedControls(in: overlay)
        // Opens on the first entitled category.
        XCTAssertEqual(titles(of: controls.from), NumPad.UnitConverter.Category.volume.units)

        let lengthIndex = try XCTUnwrap(NumPad.UnitConverter.Category.allCases.firstIndex(of: .length))
        controls.category.selectedSegmentIndex = lengthIndex
        controls.category.sendActions(for: .valueChanged)

        XCTAssertEqual(spy.lockedSelections, 1)
        XCTAssertNotEqual(controls.category.selectedSegmentIndex, lengthIndex, "segment must snap back")
        XCTAssertEqual(titles(of: controls.from), NumPad.UnitConverter.Category.volume.units,
                       "a locked category's units must never be revealed")
    }

    // MARK: - Direction arrow follows layout direction

    func testUnitArrowPointsFromSourceToTargetInBothLayoutDirections() throws {
        for direction in [UIUserInterfaceLayoutDirection.leftToRight, .rightToLeft] {
            let overlay = ConversionView(frame: CGRect(x: 0, y: 0, width: 382, height: Self.defaultBandHeight),
                                         entitledCategories: Set(NumPad.UnitConverter.Category.allCases))
            // Model each direction on a windowless view: trait overrides don't reach it here, but
            // forcing the semantic attribute drives the same stack-view ordering and image mirroring.
            // LTR is forced too, so the test holds when the host itself runs in an RTL language
            // (e.g. `-testLanguage ar`).
            let attribute: UISemanticContentAttribute = direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
            for view in [overlay] + allSubviews(of: overlay) { view.semanticContentAttribute = attribute }
            overlay.setNeedsLayout()
            overlay.layoutIfNeeded()

            let controls = try segmentedControls(in: overlay)
            let arrow = try XCTUnwrap(allSubviews(of: overlay).first { $0.accessibilityIdentifier == "conversion.unitArrow" }
                                      as? UIImageView, "unit arrow not found")
            let fromX = controls.from.convert(controls.from.bounds, to: overlay).midX
            let toX = controls.to.convert(controls.to.bounds, to: overlay).midX
            let arrowX = arrow.convert(arrow.bounds, to: overlay).midX

            XCTAssertTrue(min(fromX, toX) < arrowX && arrowX < max(fromX, toX), "arrow sits between From and To")
            XCTAssertEqual(arrow.effectiveUserInterfaceLayoutDirection, direction)
            XCTAssertEqual(arrow.image?.flipsForRightToLeftLayoutDirection, true,
                           "arrow must mirror in RTL so it keeps pointing From → To")
            if direction == .rightToLeft {
                XCTAssertGreaterThan(fromX, toX, "RTL puts From on the right, so the arrow must point left")
            } else {
                XCTAssertLessThan(fromX, toX)
            }
        }
    }

    func testInsertComputesConversionThroughDelegate() {
        let overlay = makeLaidOutView(width: 402)
        let spy = DelegateSpy()
        overlay.delegate = spy
        overlay.append("1")
        overlay.append("0")
        overlay.apply()
        // Default Length pair is cm → in: 10 cm = 3.937… in.
        XCTAssertEqual(spy.computed, Calculator.format(NumPad.UnitConverter.convert(10, from: "cm", to: "in")!))
    }

    // MARK: - Helpers

    private struct StructureError: Error {}

    private final class DelegateSpy: ConversionViewDelegate {
        var computed: String?
        var lockedSelections = 0
        func conversionView(_ view: ConversionView, didCompute value: String) { computed = value }
        func conversionViewDidRequestClose(_ view: ConversionView) {}
        func conversionViewDidSelectLockedCategory(_ view: ConversionView) { lockedSelections += 1 }
    }

    /// The view's three segmented controls in subview order: category, then From, then To.
    private func segmentedControls(in overlay: ConversionView,
                                   file: StaticString = #filePath, line: UInt = #line) throws
        -> (category: UISegmentedControl, from: UISegmentedControl, to: UISegmentedControl) {
        let all = allSubviews(of: overlay).compactMap { $0 as? UISegmentedControl }
        guard all.count == 3 else {
            XCTFail("expected category, from and to controls, found \(all.count)", file: file, line: line)
            throw StructureError()
        }
        return (all[0], all[1], all[2])
    }

    private func titles(of control: UISegmentedControl) -> [String] {
        (0..<control.numberOfSegments).compactMap { control.titleForSegment(at: $0) }
    }

    private func pick(_ unit: String, in control: UISegmentedControl,
                      file: StaticString = #filePath, line: UInt = #line) {
        guard let index = titles(of: control).firstIndex(of: unit) else {
            return XCTFail("\(unit) not offered", file: file, line: line)
        }
        control.selectedSegmentIndex = index
        control.sendActions(for: .valueChanged)
    }

    private func select(_ category: NumPad.UnitConverter.Category, in overlay: ConversionView) throws {
        let control = try segmentedControls(in: overlay).category
        let index = try XCTUnwrap(NumPad.UnitConverter.Category.allCases.firstIndex(of: category))
        control.selectedSegmentIndex = index
        control.sendActions(for: .valueChanged)
        overlay.setNeedsLayout()
        overlay.layoutIfNeeded()
    }

    /// Every segment title must render at its full intrinsic width (a narrower label draws "…").
    private func assertNoTruncatedSegments(_ control: UISegmentedControl, named name: String, width: CGFloat,
                                           file: StaticString = #filePath, line: UInt = #line) {
        control.layoutIfNeeded()
        let labels = allSubviews(of: control).compactMap { $0 as? UILabel }.filter { !($0.text ?? "").isEmpty }
        XCTAssertEqual(labels.count, control.numberOfSegments,
                       "\(name): couldn't find one title label per segment", file: file, line: line)
        for label in labels {
            XCTAssertGreaterThanOrEqual(label.bounds.width + 0.5, label.intrinsicContentSize.width,
                                        "\(name): '\(label.text ?? "")' truncated (\(label.bounds.width)pt < \(label.intrinsicContentSize.width)pt) at overlay width \(width)",
                                        file: file, line: line)
        }
    }
}

// MARK: - Category labels never truncate (e.g. "🔒 Temperature" on iPhone SE / iPad panel)

extension ConversionViewLayoutTests {

    /// Entitlement states the category row can be in. Locked segments carry the 🔒 prefix, so the
    /// widest realistic row is the Cooking-only buyer ("🔒 Length", "🔒 Mass", "🔒 Temperature",
    /// "Volume"); "nothing entitled" is the defensive worst case (every title prefixed).
    private static let categoryEntitlementCases: [(name: String, entitled: Set<NumPad.UnitConverter.Category>)] = [
        ("all entitled (Pro)", Set(NumPad.UnitConverter.Category.allCases)),
        ("Units pack only", [.length, .mass, .temperature]),
        ("Cooking pack only", [.volume]),
        ("nothing entitled", [])
    ]

    func testCategoryLabelsAreNeverTruncatedInNarrowOverlays() throws {
        for overlayWidth in Self.narrowOverlayWidths {
            for (name, entitled) in Self.categoryEntitlementCases {
                let overlay = makeLaidOutView(width: overlayWidth + 2 * Self.bandHorizontalInset,
                                              entitled: entitled)
                let category = try segmentedControls(in: overlay).category
                XCTAssertEqual(category.numberOfSegments, NumPad.UnitConverter.Category.allCases.count)
                if entitled.count < NumPad.UnitConverter.Category.allCases.count {
                    XCTAssertTrue(titles(of: category).contains { $0.hasPrefix("🔒") },
                                  "\(name): expected a locked (🔒) category title, otherwise this case proves nothing")
                }
                assertNoTruncatedSegments(category, named: "Category (\(name))", width: overlayWidth)
            }
        }
    }

    /// Widening the category labels must not push the category row past the overlay's width.
    func testCategoryRowStaysWithinOverlayWidth() throws {
        for overlayWidth in Self.narrowOverlayWidths {
            for (name, entitled) in Self.categoryEntitlementCases {
                let overlay = makeLaidOutView(width: overlayWidth + 2 * Self.bandHorizontalInset,
                                              entitled: entitled)
                let category = try segmentedControls(in: overlay).category
                let frame = category.convert(category.bounds, to: overlay)
                XCTAssertTrue(overlay.bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame),
                              "category row \(frame) overflows the \(overlayWidth)pt overlay (\(name))")
            }
        }
    }
}

// MARK: - Harness renders for review (opt-in; not device screenshots)

extension ConversionViewLayoutTests {

    /// One band of a render: the canvas width it models, the overlay's height and horizontal inset
    /// inside that canvas, and the entitlement state shown.
    private struct RenderBand {
        let caption: String
        let canvasWidth: CGFloat
        let overlayHeight: CGFloat
        let inset: CGFloat
        let entitled: Set<NumPad.UnitConverter.Category>
    }

    private static let captionHeight: CGFloat = 22
    /// iPad default keyboard height (350pt) minus the side panel's 8pt top/bottom insets.
    private static let iPadPanelHeight: CGFloat = KeyboardHeightPreset.regular.baseHeight(idiom: .pad) - 16
    private static let renderScale: CGFloat = 2

    /// Writes PNG renders of the real `ConversionView` at review widths to `$PR15_RENDER_DIR`
    /// (pass `TEST_RUNNER_PR15_RENDER_DIR` to xcodebuild). Skipped in normal suite runs. When the
    /// test host runs in Arabic (`-testLanguage ar`), it writes the RTL render instead.
    func testRenderConverterHarnessSnapshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["PR15_RENDER_DIR"], !dir.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_PR15_RENDER_DIR to write harness renders")
        }
        let phone = KeyboardHeightPreset.regular.baseHeight(idiom: .phone) * Self.overlayBandFraction
        let phoneBands = { (width: CGFloat) -> [RenderBand] in [
            RenderBand(caption: "\(Int(width))pt band · Pro (all entitled) · Length",
                       canvasWidth: width, overlayHeight: phone, inset: Self.bandHorizontalInset,
                       entitled: Set(NumPad.UnitConverter.Category.allCases)),
            RenderBand(caption: "\(Int(width))pt band · Cooking only (3 locked) · Volume",
                       canvasWidth: width, overlayHeight: phone, inset: Self.bandHorizontalInset,
                       entitled: [.volume])
        ] }

        if Bundle.main.preferredLocalizations.first == "ar" {
            XCTAssertEqual(UIApplication.shared.userInterfaceLayoutDirection, .rightToLeft,
                           "-testLanguage ar should put the host app in a real RTL layout")
            try render(phoneBands(375), contentSize: nil, to: dir, named: "rtl-ar-harness.png")
            return
        }
        try render(phoneBands(375), contentSize: nil, to: dir, named: "iphone-375-harness.png")
        let panel = [true, false].map { pro in
            RenderBand(caption: pro ? "360pt iPad panel · Pro · Length" : "360pt iPad panel · Cooking only · Volume",
                       canvasWidth: 360 + 20, overlayHeight: Self.iPadPanelHeight, inset: 10,
                       entitled: pro ? Set(NumPad.UnitConverter.Category.allCases) : [.volume])
        }
        try render(panel, contentSize: nil, to: dir, named: "ipad-360-panel-harness.png")
        try render(phoneBands(375), contentSize: .accessibilityExtraLarge, to: dir, named: "ax-xl-harness.png")
    }

    private func render(_ bands: [RenderBand], contentSize: UIContentSizeCategory?,
                        to dir: String, named fileName: String) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "no window scene in the test host")
        let width = bands.map(\.canvasWidth).max() ?? 0
        let height = bands.reduce(CGFloat(0)) { $0 + Self.captionHeight + $1.overlayHeight + 2 * 8 }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        if let contentSize, #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = contentSize
        }
        let root = UIViewController()
        root.view.backgroundColor = .systemGray5
        window.rootViewController = root
        window.isHidden = false
        defer { window.isHidden = true }

        var y: CGFloat = 0
        var overlays: [ConversionView] = []
        for band in bands {
            let caption = UILabel(frame: CGRect(x: 10, y: y + 4, width: band.canvasWidth - 20, height: Self.captionHeight - 4))
            caption.font = .systemFont(ofSize: 11, weight: .medium)
            caption.textColor = .secondaryLabel
            caption.text = band.caption + (contentSize == nil ? "" : " · Dynamic Type AX-XL")
            root.view.addSubview(caption)
            y += Self.captionHeight + 8
            let overlay = ConversionView(frame: CGRect(x: band.inset, y: y, width: band.canvasWidth - 2 * band.inset,
                                                       height: band.overlayHeight),
                                         entitledCategories: band.entitled)
            overlay.append("12")
            root.view.addSubview(overlay)
            y += band.overlayHeight + 8
            overlays.append(overlay)
        }
        window.layoutIfNeeded()
        if let contentSize {
            // Proves the render really is at the requested size (the converter's fonts are fixed
            // point sizes, so an AX render looking identical to the default one is expected).
            for overlay in overlays {
                XCTAssertEqual(overlay.traitCollection.preferredContentSizeCategory, contentSize)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = Self.renderScale
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: dir).appendingPathComponent(fileName)
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: url)
        let attachment = XCTAttachment(image: image)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
