//
//  QwertyGlideCaptureTests.swift
//  NumPadTests
//
//  Pure tap-vs-glide upgrade thresholds (glide-and-accuracy design §4.1) — written
//  test-first per the glide-capture pass.
//

import CoreGraphics
import XCTest
@testable import NumPad

final class QwertyGlideCaptureTests: XCTestCase {

    // MARK: - Helpers

    /// Synthetic one-row geometry: 30pt-wide keys, so key index == column. Q sits at
    /// index 0 (center x 15), W at 1 (45), E at 2 (75), R at 3 (105), T at 4 (135).
    private func keyIndex(forX x: CGFloat) -> Int {
        Int(x / 30)
    }

    private func recordedState(_ samples: [(point: CGPoint, keyIndex: Int?)])
        -> QwertyGlideCapture.State {
        var state = QwertyGlideCapture.State()
        for sample in samples {
            state.record(point: sample.point, keyIndex: sample.keyIndex)
        }
        return state
    }

    // MARK: - Never upgrades

    func testEmptyStateDoesNotUpgrade() {
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: QwertyGlideCapture.State()))
    }

    func testShortWiggleInsideOneKeyNeverUpgrades() {
        // A finger settling on Q: sub-key jitter, always resolving to the same key.
        var state = QwertyGlideCapture.State()
        let wiggle: [CGPoint] = [
            CGPoint(x: 15, y: 20), CGPoint(x: 18, y: 22), CGPoint(x: 13, y: 19),
            CGPoint(x: 16, y: 24), CGPoint(x: 14, y: 18), CGPoint(x: 17, y: 21),
        ]
        for point in wiggle {
            state.record(point: point, keyIndex: 0)
            XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state),
                           "wiggle inside one key must never upgrade (point \(point))")
        }
    }

    func testDistanceWithoutSecondKeyDoesNotUpgrade() {
        // 40pt of travel that never leaves key 0 (a tall key, or gap points routed back to
        // it): distance alone must not upgrade.
        let state = recordedState([
            (CGPoint(x: 15, y: 20), 0),
            (CGPoint(x: 15, y: 40), 0),
            (CGPoint(x: 15, y: 60), 0),
        ])
        XCTAssertGreaterThanOrEqual(state.maxDisplacement, QwertyGlideCapture.minimumDistance)
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    func testMultiKeyWiggleBelowDistanceThresholdDoesNotUpgrade() {
        // Straddling the Q/W boundary (x = 30): two distinct keys but only ~10pt of travel.
        let state = recordedState([
            (CGPoint(x: 28, y: 20), 0),
            (CGPoint(x: 33, y: 20), 1),
            (CGPoint(x: 27, y: 20), 0),
            (CGPoint(x: 32, y: 20), 1),
        ])
        XCTAssertEqual(state.visitedKeyIndices.count, 2)
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    func testGapPointsWithNilKeyIndexNeverCountAsKeys() {
        // Far travel whose samples all miss key resolution (nil) except the origin: one
        // distinct key, no upgrade.
        let state = recordedState([
            (CGPoint(x: 15, y: 20), 0),
            (CGPoint(x: 55, y: 20), nil),
            (CGPoint(x: 95, y: 20), nil),
        ])
        XCTAssertEqual(state.visitedKeyIndices, [0])
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    func testLeavingAndReenteringSameKeyCountsOneDistinctKey() {
        // Q → off-grid → back to Q with plenty of distance: re-entering the origin key
        // must not double-count it, so the distinct-keys threshold still blocks upgrade.
        let state = recordedState([
            (CGPoint(x: 15, y: 20), 0),
            (CGPoint(x: 15, y: 55), nil),
            (CGPoint(x: 15, y: 20), 0),
        ])
        XCTAssertEqual(state.visitedKeyIndices, [0])
        XCTAssertGreaterThanOrEqual(state.maxDisplacement, QwertyGlideCapture.minimumDistance)
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    // MARK: - Upgrades

    func testQToTDragUpgradesExactlyWhenBothThresholdsPass() {
        // Rightward drag from Q's center in 6pt steps. The second key (W) is visited at
        // x = 33 (displacement 18 — still short), and the 24pt distance threshold passes
        // exactly at x = 39. Upgrade must flip at that sample and not one before.
        var state = QwertyGlideCapture.State()
        let xs: [CGFloat] = [15, 21, 27, 33, 39, 45, 75, 105, 135]
        for x in xs {
            state.record(point: CGPoint(x: x, y: 20), keyIndex: keyIndex(forX: x))
            let expected = x >= 39
            XCTAssertEqual(QwertyGlideCapture.shouldUpgrade(state: state), expected,
                           "at x = \(x) upgrade should be \(expected)")
        }
    }

    func testExactThresholdBoundaryUpgrades() {
        // Displacement of exactly minimumDistance with exactly minimumDistinctKeys keys:
        // thresholds are inclusive.
        let state = recordedState([
            (CGPoint(x: 15, y: 20), 0),
            (CGPoint(x: 15 + QwertyGlideCapture.minimumDistance, y: 20), 1),
        ])
        XCTAssertEqual(state.maxDisplacement, QwertyGlideCapture.minimumDistance)
        XCTAssertEqual(state.visitedKeyIndices.count, QwertyGlideCapture.minimumDistinctKeys)
        XCTAssertTrue(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    func testDisplacementIsMeasuredFromOriginNotPathLength() {
        // A tight zig-zag: 60pt of accumulated arc length but the finger never strays more
        // than 12pt from where it landed. Path-length semantics would upgrade here; the
        // documented max-displacement choice must not.
        var samples: [(point: CGPoint, keyIndex: Int?)] = [(CGPoint(x: 27, y: 20), 0)]
        for step in 1...10 {
            let x: CGFloat = step.isMultiple(of: 2) ? 27 : 33
            samples.append((CGPoint(x: x, y: 20), keyIndex(forX: x)))
        }
        let state = recordedState(samples)
        XCTAssertEqual(state.visitedKeyIndices.count, 2)
        XCTAssertLessThan(state.maxDisplacement, QwertyGlideCapture.minimumDistance)
        XCTAssertFalse(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    func testReturningTowardOriginKeepsMaxDisplacement() {
        // Out 30pt through W, then back to the origin: max displacement is retained, so
        // the upgrade decision cannot flap back to false as the finger curls around.
        let state = recordedState([
            (CGPoint(x: 15, y: 20), 0),
            (CGPoint(x: 45, y: 20), 1),
            (CGPoint(x: 16, y: 20), 0),
        ])
        XCTAssertEqual(state.maxDisplacement, 30)
        XCTAssertTrue(QwertyGlideCapture.shouldUpgrade(state: state))
    }

    // MARK: - State bookkeeping

    func testPointsAccumulateInRecordedOrder() {
        let points = [CGPoint(x: 15, y: 20), CGPoint(x: 45, y: 21), CGPoint(x: 75, y: 22)]
        let state = recordedState(points.map { ($0, nil) })
        XCTAssertEqual(state.points, points)
    }

    func testThresholdConstantsMatchDesign() {
        // Pinned by the plan (§4.1): 24pt of travel and 2 distinct keys.
        XCTAssertEqual(QwertyGlideCapture.minimumDistance, 24)
        XCTAssertEqual(QwertyGlideCapture.minimumDistinctKeys, 2)
    }
}
