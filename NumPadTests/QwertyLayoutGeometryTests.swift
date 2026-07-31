import XCTest
@testable import NumPad

final class QwertyLayoutGeometryTests: XCTestCase {
    private struct NumpadConstraintHarness {
        let container: UIView
        let content: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint

        init(bounds: CGRect) {
            container = UIView(frame: bounds)
            content = UIView()
            container.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
            leading = content.leadingAnchor.constraint(equalTo: container.leadingAnchor)
            trailing = content.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            NSLayoutConstraint.activate([
                leading,
                trailing,
                content.topAnchor.constraint(equalTo: container.topAnchor),
                content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        @discardableResult
        func apply(_ preference: NumpadPlacement,
                   horizontalSizeClass: UIUserInterfaceSizeClass = .regular,
                   isFloating: Bool = false) -> NumpadGeometry.ConstraintLayout {
            let result = NumpadGeometry.apply(
                preference: preference,
                bounds: container.bounds,
                idiom: .pad,
                horizontalSizeClass: horizontalSizeClass,
                isFloating: isFloating,
                leadingConstraint: leading,
                trailingConstraint: trailing
            )
            container.layoutIfNeeded()
            return result
        }

        @discardableResult
        func apply(_ width: NumpadWidthSize,
                   horizontalSizeClass: UIUserInterfaceSizeClass = .regular,
                   isFloating: Bool = false) -> NumpadGeometry.ConstraintLayout {
            let result = NumpadGeometry.apply(
                width: width,
                bounds: container.bounds,
                idiom: .pad,
                horizontalSizeClass: horizontalSizeClass,
                isFloating: isFloating,
                leadingConstraint: leading,
                trailingConstraint: trailing
            )
            container.layoutIfNeeded()
            return result
        }
    }

    private func withPreference<T>(_ preference: QwertyLayoutMode,
                                   perform: () throws -> T) rethrows -> T {
        let previous = UserPrefs.qwertyLayoutMode
        UserPrefs.qwertyLayoutMode = preference
        defer { UserPrefs.qwertyLayoutMode = previous }
        return try perform()
    }

    private func makePadKeyboardView(size: CGSize) -> QwertyKeyboardView {
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

        let view = QwertyKeyboardView(frame: CGRect(origin: .zero, size: size))
        child.view.addSubview(view)
        view.configure(
            rows: QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions()),
            topStrip: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
                QwertyKey(kind: .character($0, shifted: $0), width: 1)
            }
        )
        view.layoutIfNeeded()
        return view
    }

    func test_centeredCapsWidthOnPad() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 300)
        let width = QwertyLayoutGeometry.contentWidth(bounds: bounds, mode: .centered, idiom: .pad)
        XCTAssertLessThanOrEqual(width, 720)
        let origin = QwertyLayoutGeometry.contentOriginX(bounds: bounds, mode: .centered, idiom: .pad)
        XCTAssertEqual(origin, (1024 - width) / 2, accuracy: 0.5)
    }

    func test_numpadPlacement() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 350)
        let center = NumpadGeometry.contentFrame(bounds: bounds, placement: .center, idiom: .pad)
        XCTAssertLessThanOrEqual(center.width, NumpadGeometry.regularPadMaxWidth)
        let full = NumpadGeometry.contentFrame(bounds: bounds, placement: .fullWidth, idiom: .pad)
        XCTAssertEqual(full, bounds)
    }

    func testNumpadWidthResolutionUsesExactCenteredIPadFractionsWithoutChangingHeight() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 300)
        let expectations: [(NumpadWidthSize, CGRect)] = [
            (.compact, CGRect(x: 200, y: 0, width: 600, height: 300)),
            (.comfortable, CGRect(x: 150, y: 0, width: 700, height: 300)),
            (.medium, CGRect(x: 100, y: 0, width: 800, height: 300)),
            (.wide, CGRect(x: 50, y: 0, width: 900, height: 300)),
            (.full, CGRect(x: 0, y: 0, width: 1_000, height: 300)),
        ]

        for (width, expectedFrame) in expectations {
            let result = NumpadGeometry.resolve(
                width: width,
                bounds: bounds,
                idiom: .pad,
                horizontalSizeClass: .regular,
                isFloating: false
            )

            XCTAssertEqual(result.contentFrame, expectedFrame, "\(width)")
            XCTAssertEqual(result.contentFrame.height, 300, accuracy: 0.001, "\(width)")
        }
    }

    func testNumpadWidthResolutionFallsBackToAvailableBoundsWithoutChangingHeight() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 300)
        let fallbacks: [(UIUserInterfaceIdiom, UIUserInterfaceSizeClass?, CGRect, Bool)] = [
            (.phone, .compact, bounds, false),
            (.pad, .compact, bounds, false),
            (.pad, .regular, CGRect(x: 0, y: 0, width: 600, height: 300), false),
            (.pad, .regular, bounds, true),
        ]

        for (idiom, sizeClass, fallbackBounds, isFloating) in fallbacks {
            let result = NumpadGeometry.resolve(
                width: .compact,
                bounds: fallbackBounds,
                idiom: idiom,
                horizontalSizeClass: sizeClass,
                isFloating: isFloating
            )

            XCTAssertEqual(result.contentFrame, fallbackBounds)
            XCTAssertEqual(result.contentFrame.height, fallbackBounds.height, accuracy: 0.001)
        }
    }

    func testIPadStandardCompositionUsesTheEntireInputBounds() {
        let bounds = CGRect(x: 12, y: 7, width: 1_000, height: 320)

        let result = IPadKeyboardCompositionGeometry.resolve(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .standard,
            numpadSide: .right
        )

        XCTAssertEqual(result.qwertyFrame, bounds)
        XCTAssertNil(result.numpadFrame)
    }

    func testIPadFullCompositionUsesFixedQwertyShareAndMirrorsNumpadSide() throws {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 320)
        let right = IPadKeyboardCompositionGeometry.resolve(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .right
        )
        let left = IPadKeyboardCompositionGeometry.resolve(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .left
        )

        let rightNumpad = try XCTUnwrap(right.numpadFrame)
        let leftNumpad = try XCTUnwrap(left.numpadFrame)
        XCTAssertEqual(right.qwertyFrame, CGRect(x: 0, y: 0, width: 680, height: 320))
        XCTAssertEqual(rightNumpad, CGRect(x: 688, y: 0, width: 312, height: 320))
        XCTAssertEqual(leftNumpad, CGRect(x: 0, y: 0, width: 312, height: 320))
        XCTAssertEqual(left.qwertyFrame, CGRect(x: 320, y: 0, width: 680, height: 320))
        XCTAssertFalse(right.qwertyFrame.intersects(rightNumpad))
        XCTAssertFalse(left.qwertyFrame.intersects(leftNumpad))
        XCTAssertEqual(rightNumpad.minX - right.qwertyFrame.maxX, 8, accuracy: 0.001)
        XCTAssertEqual(left.qwertyFrame.minX - leftNumpad.maxX, 8, accuracy: 0.001)
        XCTAssertEqual(right.qwertyFrame.height, bounds.height, accuracy: 0.001)
        XCTAssertEqual(rightNumpad.height, bounds.height, accuracy: 0.001)
        XCTAssertEqual(left.qwertyFrame.height, bounds.height, accuracy: 0.001)
        XCTAssertEqual(leftNumpad.height, bounds.height, accuracy: 0.001)
    }

    func testIPadFullCompositionFallsBackToStandardOutsideRegularPadCanvas() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 320)
        let fallbacks: [(UIUserInterfaceIdiom, UIUserInterfaceSizeClass?, Bool)] = [
            (.phone, .compact, false),
            (.pad, .compact, false),
            (.pad, .regular, true),
        ]

        for (idiom, sizeClass, isFloating) in fallbacks {
            let result = IPadKeyboardCompositionGeometry.resolve(
                bounds: bounds,
                idiom: idiom,
                horizontalSizeClass: sizeClass,
                layout: .full,
                numpadSide: .left,
                isFloating: isFloating
            )
            XCTAssertEqual(result.qwertyFrame, bounds)
            XCTAssertNil(result.numpadFrame)
        }
    }

    func testFullKeyboardOverlaysStayInsideTheirRealNumpadPane() throws {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 320)
        let overlayKinds = ["clipboard", "snippets", "tax-tip", "pack-picker", "conversion", "tape"]

        for side in [FullKeyboardNumpadSide.left, .right] {
            let composition = IPadKeyboardCompositionGeometry.resolve(
                bounds: bounds,
                idiom: .pad,
                horizontalSizeClass: .regular,
                layout: .full,
                numpadSide: side
            )
            let numpad = try XCTUnwrap(composition.numpadFrame)

            for kind in overlayKinds {
                let overlay = try XCTUnwrap(
                    IPadKeyboardCompositionGeometry.overlayFrame(
                        for: composition,
                        verticalInset: 8
                    ),
                    "\(side) \(kind)"
                )
                XCTAssertTrue(numpad.contains(overlay), "\(side) \(kind)")
                XCTAssertFalse(overlay.intersects(composition.qwertyFrame), "\(side) \(kind)")
                XCTAssertEqual(overlay.minY, 8, accuracy: 0.001, "\(side) \(kind)")
                XCTAssertEqual(overlay.maxY, 312, accuracy: 0.001, "\(side) \(kind)")
            }
        }

        let standard = IPadKeyboardCompositionGeometry.resolve(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .standard,
            numpadSide: .right
        )
        XCTAssertNil(IPadKeyboardCompositionGeometry.overlayFrame(for: standard, verticalInset: 8))
    }

    func testAutomaticResolutionUsesPhoneLegacyCenteredPadAndNarrowFallbacks() {
        let regular = CGRect(x: 0, y: 0, width: 1024, height: 320)
        let narrow = CGRect(x: 0, y: 0, width: 390, height: 260)

        XCTAssertEqual(
            QwertyLayoutGeometry.resolvedMode(
                preference: .automatic,
                bounds: regular,
                idiom: .phone,
                horizontalSizeClass: .compact,
                isFloating: false
            ),
            .automatic
        )
        XCTAssertEqual(
            QwertyLayoutGeometry.resolvedMode(
                preference: .automatic,
                bounds: regular,
                idiom: .pad,
                horizontalSizeClass: .regular,
                isFloating: false
            ),
            .centered
        )
        XCTAssertEqual(
            QwertyLayoutGeometry.resolvedMode(
                preference: .automatic,
                bounds: narrow,
                idiom: .pad,
                horizontalSizeClass: .compact,
                isFloating: false
            ),
            .compactLeft
        )
        XCTAssertEqual(
            NumpadGeometry.resolvedPlacement(
                preference: .automatic,
                bounds: regular,
                idiom: .pad,
                horizontalSizeClass: .regular,
                isFloating: false
            ),
            .center
        )
        XCTAssertEqual(
            NumpadGeometry.resolvedPlacement(
                preference: .automatic,
                bounds: narrow,
                idiom: .pad,
                horizontalSizeClass: .compact,
                isFloating: false
            ),
            .fullWidth
        )
    }

    func testResolvedQwertyFramesCoverEveryModeAndStayInsideContent() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 320)
        let rows = [
            QwertyRow(keys: (0..<10).map {
                QwertyKey(kind: .character(String($0), shifted: String($0)), width: 1)
            }),
        ] + QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions())

        for mode in QwertyLayoutMode.allCases {
            let result = QwertyLayoutGeometry.layout(
                bounds: bounds,
                rows: rows,
                mode: mode,
                idiom: .pad,
                keyGap: 4,
                rowGap: 4
            )
            XCTAssertEqual(result.rows.count, rows.count, "\(mode)")
            XCTAssertTrue(bounds.contains(result.contentFrame), "\(mode)")
            for row in result.rows {
                XCTAssertTrue(row.frames.allSatisfy(result.contentFrame.contains), "\(mode)")
                for pair in zip(row.frames, row.frames.dropFirst()) {
                    XCTAssertLessThanOrEqual(pair.0.maxX, pair.1.minX, "\(mode)")
                }
            }
        }
    }

    func testSplitFramesLeaveAThumbGapButKeepBottomCommandRowStable() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 320)
        let rows = [
            QwertyRow(keys: (0..<10).map {
                QwertyKey(kind: .character(String($0), shifted: String($0)), width: 1)
            }),
        ] + QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions())
        let result = QwertyLayoutGeometry.layout(
            bounds: bounds,
            rows: rows,
            mode: .split,
            idiom: .pad,
            keyGap: 4,
            rowGap: 4
        )

        let gap = try! XCTUnwrap(result.splitGap)
        XCTAssertGreaterThanOrEqual(gap.width, 96)
        XCTAssertTrue(
            result.rows.dropLast().flatMap(\.frames).allSatisfy { !$0.intersects(gap) }
        )
        XCTAssertTrue(
            result.rows.last?.frames.contains(where: { $0.contains(
                CGPoint(x: bounds.midX, y: bounds.maxY - 20)
            ) }) == true,
            "the command row remains continuous across the split"
        )
    }

    func testPhoneAutomaticFramesMatchLegacyFullWidthFormulaExactly() {
        let bounds = CGRect(x: 0, y: 0, width: 375, height: 260)
        let rows = QwertyLayout.rows(layer: .letters, options: QwertyLayoutOptions())
        let result = QwertyLayoutGeometry.layout(
            bounds: bounds,
            rows: rows,
            mode: .automatic,
            idiom: .phone,
            keyGap: 4,
            rowGap: 4
        )
        let usableHeight = bounds.height - 6 - 4
        let rowSlotHeight = usableHeight / CGFloat(rows.count)
        let unitWidth = (bounds.width - 6) / CGFloat(QwertyLayout.rowUnitWidth)

        for (rowIndex, row) in rows.enumerated() {
            var cursor = row.leadingMargin
            for (keyIndex, key) in row.keys.enumerated() {
                let expected = CGRect(
                    x: 3 + CGFloat(cursor) * unitWidth + 2,
                    y: 6 + CGFloat(rowIndex) * rowSlotHeight + 2,
                    width: CGFloat(key.width) * unitWidth - 4,
                    height: rowSlotHeight - 4
                )
                XCTAssertEqual(result.rows[rowIndex].frames[keyIndex], expected)
                cursor += key.width
            }
        }
    }

    func testProductionQwertyViewUsesItsEntireStandardPaneOnPad() {
        withPreference(.centered) {
            let bounds = CGRect(x: 0, y: 0, width: 1024, height: 300)
            let view = makePadKeyboardView(size: bounds.size)
            let keyFrames = view.subviews.compactMap { ($0 as? QwertyKeyButton)?.frame }

            XCTAssertFalse(keyFrames.isEmpty)
            XCTAssertEqual(view.layoutContentFrame, bounds)
            XCTAssertTrue(
                keyFrames.allSatisfy { bounds.contains($0) },
                "the production grid must fill its host-provided Standard pane"
            )
            XCTAssertLessThan(keyFrames.map(\.minX).min() ?? .greatestFiniteMagnitude, 10)
        }
    }

    func testProductionQwertyDoesNotUseLegacySplitGeometry() {
        withPreference(.split) {
            let view = makePadKeyboardView(size: CGSize(width: 1024, height: 300))
            XCTAssertNil(view.layoutSplitGap)
            XCTAssertEqual(view.layoutContentFrame, view.bounds)
        }
    }

    func testProductionNumpadConstraintFramesCoverEveryPlacement() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 320)
        let expectations: [(NumpadPlacement, CGRect)] = [
            (.automatic, CGRect(x: 232, y: 0, width: 560, height: 320)),
            (.left, CGRect(x: 0, y: 0, width: 560, height: 320)),
            (.right, CGRect(x: 464, y: 0, width: 560, height: 320)),
            (.center, CGRect(x: 232, y: 0, width: 560, height: 320)),
            (.fullWidth, bounds),
        ]

        for (preference, expected) in expectations {
            let harness = NumpadConstraintHarness(bounds: bounds)
            let result = harness.apply(preference)
            XCTAssertEqual(result.contentFrame, expected, "\(preference)")
            XCTAssertEqual(harness.content.frame, expected, "\(preference)")
        }
    }

    func testProductionNumpadWidthConstraintsOnlyChangeHorizontalMargins() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 300)
        let expectedMargins: [(NumpadWidthSize, CGFloat)] = [
            (.compact, 200),
            (.comfortable, 150),
            (.medium, 100),
            (.wide, 50),
            (.full, 0),
        ]
        let harness = NumpadConstraintHarness(bounds: bounds)
        let originalHeight = bounds.height

        for (width, expectedMargin) in expectedMargins {
            let result = harness.apply(width)

            XCTAssertEqual(result.leadingConstant, expectedMargin, accuracy: 0.001, "\(width)")
            XCTAssertEqual(result.trailingConstant, -expectedMargin, accuracy: 0.001, "\(width)")
            XCTAssertEqual(harness.content.frame.height, originalHeight, accuracy: 0.001, "\(width)")
        }
    }

    func testProductionNumpadConstraintsRecalculateAfterBoundsChange() {
        let harness = NumpadConstraintHarness(
            bounds: CGRect(x: 0, y: 0, width: 1024, height: 320)
        )
        XCTAssertEqual(
            harness.apply(.center).contentFrame,
            CGRect(x: 232, y: 0, width: 560, height: 320)
        )

        harness.container.frame = CGRect(x: 0, y: 0, width: 1366, height: 280)
        let rotated = harness.apply(.center)
        XCTAssertEqual(rotated.contentFrame, CGRect(x: 403, y: 0, width: 560, height: 280))
        XCTAssertEqual(harness.content.frame, rotated.contentFrame)
    }

    func testProductionNumpadAutomaticFallsBackToFullWidthWhenNarrowOrFloating() {
        let narrow = NumpadConstraintHarness(
            bounds: CGRect(x: 0, y: 0, width: 600, height: 320)
        )
        let narrowResult = narrow.apply(.automatic, horizontalSizeClass: .compact)
        XCTAssertEqual(narrowResult.resolvedPlacement, .fullWidth)
        XCTAssertEqual(narrow.content.frame, narrow.container.bounds)

        let floating = NumpadConstraintHarness(
            bounds: CGRect(x: 0, y: 0, width: 1024, height: 320)
        )
        let floatingResult = floating.apply(.automatic, isFloating: true)
        XCTAssertEqual(floatingResult.resolvedPlacement, .fullWidth)
        XCTAssertEqual(floating.content.frame, floating.container.bounds)
    }

}
