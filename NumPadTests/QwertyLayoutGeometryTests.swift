import XCTest
@testable import NumPad

final class QwertyLayoutGeometryTests: XCTestCase {
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

    func testProductionQwertyViewConsumesCenteredContentFrameOnPad() {
        withPreference(.centered) {
            let bounds = CGRect(x: 0, y: 0, width: 1024, height: 300)
            let view = makePadKeyboardView(size: bounds.size)
            let expectedWidth = QwertyLayoutGeometry.contentWidth(
                bounds: bounds,
                mode: .centered,
                idiom: .pad
            )
            let expectedOrigin = QwertyLayoutGeometry.contentOriginX(
                bounds: bounds,
                mode: .centered,
                idiom: .pad
            )
            let contentFrame = CGRect(
                x: expectedOrigin,
                y: bounds.minY,
                width: expectedWidth,
                height: bounds.height
            )
            let keyFrames = view.subviews.compactMap { ($0 as? QwertyKeyButton)?.frame }

            XCTAssertFalse(keyFrames.isEmpty)
            XCTAssertTrue(
                keyFrames.allSatisfy { contentFrame.contains($0) },
                "the production key frames must be transformed into the centered resolver frame"
            )
            XCTAssertGreaterThan(keyFrames.map(\.minX).min() ?? 0, 100)
        }
    }

    func testProductionQwertySplitGapIsNotAKeyHitRegion() {
        withPreference(.split) {
            let view = makePadKeyboardView(size: CGSize(width: 1024, height: 300))
            let result = view.hitTest(
                CGPoint(x: view.bounds.midX, y: view.bounds.midY),
                with: nil
            )
            XCTAssertFalse(
                result is QwertyKeyButton,
                "the split thumb gap must not be expanded into a key hit region"
            )
        }
    }

}
