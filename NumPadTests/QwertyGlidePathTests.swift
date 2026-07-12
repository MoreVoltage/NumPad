//
//  QwertyGlidePathTests.swift
//  NumPadTests
//

import CoreGraphics
import XCTest
@testable import NumPad

final class QwertyGlidePathTests: XCTestCase {

    // MARK: - Helpers

    private func assertPointsEqual(_ actual: [CGPoint], _ expected: [CGPoint],
                                   accuracy: CGFloat = 1e-9,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "point count mismatch", file: file, line: line)
        guard actual.count == expected.count else { return }
        for index in actual.indices {
            XCTAssertEqual(actual[index].x, expected[index].x, accuracy: accuracy,
                           "x at index \(index)", file: file, line: line)
            XCTAssertEqual(actual[index].y, expected[index].y, accuracy: accuracy,
                           "y at index \(index)", file: file, line: line)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - resample: uniform arc-length spacing

    func testResampleTwoPointSegmentYieldsUniformlySpacedPoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        let resampled = QwertyGlidePath.resample(points, to: 11)
        let expected = (0...10).map { CGPoint(x: CGFloat($0), y: 0) }
        assertPointsEqual(resampled, expected)
    }

    func testResampleDefaultCountIsSampleCount() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        let resampled = QwertyGlidePath.resample(points)
        XCTAssertEqual(resampled.count, QwertyGlidePath.sampleCount)
        // Uniform spacing along a straight segment: every consecutive gap is total/(count-1).
        let step = 10.0 / CGFloat(QwertyGlidePath.sampleCount - 1)
        for index in 1..<resampled.count {
            XCTAssertEqual(distance(resampled[index - 1], resampled[index]), step, accuracy: 1e-9,
                           "gap at index \(index)")
        }
    }

    func testResampleEndpointsMatchInputExactly() {
        // First/last output points must be the input's first/last points EXACTLY
        // (no interpolation drift) -- the decoder's start/end-key pruning depends on it.
        let points = [CGPoint(x: 0.123, y: 4.567), CGPoint(x: 3.21, y: 0.5),
                      CGPoint(x: 7.77, y: 9.99)]
        let resampled = QwertyGlidePath.resample(points, to: 7)
        XCTAssertEqual(resampled.first, points.first)
        XCTAssertEqual(resampled.last, points.last)
    }

    func testResampleInterpolatesAcrossCornerAtExactArcLengthPositions() {
        // L-path of total length 6, resampled to 4 -> targets at arc length 0, 2, 4, 6.
        // Arc position 4 is 1pt past the corner (3,0), i.e. (3,1) -- uniform ARC-LENGTH
        // spacing, not uniform per-segment spacing.
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 0), CGPoint(x: 3, y: 3)]
        let resampled = QwertyGlidePath.resample(points, to: 4)
        let expected = [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0),
                        CGPoint(x: 3, y: 1), CGPoint(x: 3, y: 3)]
        assertPointsEqual(resampled, expected)
    }

    func testResampleUniformConsecutiveDistancesOnBentPath() {
        // L-path of total length 8 resampled to 5: step 2, corner lands on a sample,
        // so every consecutive chord distance equals the arc-length step.
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 0), CGPoint(x: 4, y: 4)]
        let resampled = QwertyGlidePath.resample(points, to: 5)
        XCTAssertEqual(resampled.count, 5)
        for index in 1..<resampled.count {
            XCTAssertEqual(distance(resampled[index - 1], resampled[index]), 2, accuracy: 1e-9,
                           "gap at index \(index)")
        }
    }

    func testResampleIsIdempotentOnAlreadyUniformStraightPath() {
        let uniform = (0...4).map { CGPoint(x: CGFloat($0) * 2.5, y: 0) }
        let resampled = QwertyGlidePath.resample(uniform, to: uniform.count)
        assertPointsEqual(resampled, uniform)
    }

    func testResampleIsIdempotentOnAlreadyUniformBentPath() {
        // Vertices sit exactly at multiples of the arc-length step (5), so resampling
        // reproduces the input.
        let uniform = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0),
                       CGPoint(x: 10, y: 5), CGPoint(x: 10, y: 10)]
        let resampled = QwertyGlidePath.resample(uniform, to: uniform.count)
        assertPointsEqual(resampled, uniform)
    }

    // MARK: - resample: degenerate inputs

    func testResampleEmptyInputReturnsEmpty() {
        XCTAssertEqual(QwertyGlidePath.resample([], to: 5), [])
    }

    func testResampleSinglePointRepeatsThePoint() {
        let point = CGPoint(x: 3, y: 7)
        let resampled = QwertyGlidePath.resample([point], to: 5)
        XCTAssertEqual(resampled, Array(repeating: point, count: 5))
    }

    func testResampleZeroLengthPathRepeatsFirstPoint() {
        // All points identical: total arc length is 0 -- must not divide by zero.
        let point = CGPoint(x: 2, y: 2)
        let resampled = QwertyGlidePath.resample([point, point, point], to: 4)
        XCTAssertEqual(resampled, Array(repeating: point, count: 4))
    }

    func testResampleCountOneReturnsFirstPointOnly() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]
        XCTAssertEqual(QwertyGlidePath.resample(points, to: 1), [CGPoint(x: 1, y: 2)])
    }

    func testResampleCountZeroReturnsEmpty() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]
        XCTAssertEqual(QwertyGlidePath.resample(points, to: 0), [])
    }

    // MARK: - pathLength

    func testPathLengthOnKnownPolyline() {
        // 3-4-5 triangle leg then a vertical drop of 4: 5 + 4 = 9.
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4), CGPoint(x: 3, y: 0)]
        XCTAssertEqual(QwertyGlidePath.pathLength(points), 9, accuracy: 1e-9)
    }

    func testPathLengthEmptyAndSinglePointAreZero() {
        XCTAssertEqual(QwertyGlidePath.pathLength([]), 0)
        XCTAssertEqual(QwertyGlidePath.pathLength([CGPoint(x: 5, y: 5)]), 0)
    }

    // MARK: - normalized: SHARK2 shape channel

    func testNormalizedCentroidIsAtOrigin() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 6), CGPoint(x: 3, y: 9),
                      CGPoint(x: 8, y: 7), CGPoint(x: 6, y: 1)]
        let normalized = QwertyGlidePath.normalized(points)
        let meanX = normalized.reduce(0) { $0 + $1.x } / CGFloat(normalized.count)
        let meanY = normalized.reduce(0) { $0 + $1.y } / CGFloat(normalized.count)
        XCTAssertEqual(meanX, 0, accuracy: 1e-9)
        XCTAssertEqual(meanY, 0, accuracy: 1e-9)
    }

    func testNormalizedLargestBoundingBoxSideIsOne() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 6), CGPoint(x: 3, y: 9),
                      CGPoint(x: 8, y: 7), CGPoint(x: 6, y: 1)]
        let normalized = QwertyGlidePath.normalized(points)
        let width = normalized.map(\.x).max()! - normalized.map(\.x).min()!
        let height = normalized.map(\.y).max()! - normalized.map(\.y).min()!
        XCTAssertEqual(max(width, height), 1, accuracy: 1e-9)
    }

    func testNormalizedIsTranslationAndScaleInvariant() {
        // The shape channel must see p and (p x 3 + shift) as the same contour.
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 6), CGPoint(x: 3, y: 9),
                      CGPoint(x: 8, y: 7), CGPoint(x: 6, y: 1)]
        let transformed = points.map { CGPoint(x: $0.x * 3 + 17, y: $0.y * 3 - 4) }
        let separation = QwertyGlidePath.channelDistance(QwertyGlidePath.normalized(points),
                                                         QwertyGlidePath.normalized(transformed))
        XCTAssertEqual(separation, 0, accuracy: 1e-9)
    }

    func testNormalizedZeroExtentPathIsAllZerosWithoutNaN() {
        // All points identical: bounding box has zero extent -- must not divide by zero.
        let point = CGPoint(x: 5, y: 5)
        let normalized = QwertyGlidePath.normalized([point, point, point])
        XCTAssertEqual(normalized, Array(repeating: CGPoint.zero, count: 3))
        for value in normalized {
            XCTAssertFalse(value.x.isNaN)
            XCTAssertFalse(value.y.isNaN)
        }
    }

    func testNormalizedEmptyReturnsEmpty() {
        XCTAssertEqual(QwertyGlidePath.normalized([]), [])
    }

    // MARK: - channelDistance

    func testChannelDistanceKnownValue() {
        // Pairwise distances 5 (3-4-5 triangle) and 5 (vertical) -> mean 5.
        let a = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)]
        let b = [CGPoint(x: 3, y: 4), CGPoint(x: 0, y: 5)]
        XCTAssertEqual(QwertyGlidePath.channelDistance(a, b), 5, accuracy: 1e-9)
    }

    func testChannelDistanceIdenticalPathsIsZero() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 6), CGPoint(x: 3, y: 9)]
        XCTAssertEqual(QwertyGlidePath.channelDistance(points, points), 0)
    }

    func testChannelDistanceBothEmptyIsZero() {
        XCTAssertEqual(QwertyGlidePath.channelDistance([], []), 0)
    }

    func testChannelDistanceLengthMismatchIsGreatestFiniteMagnitude() {
        // A mismatch is a pipeline bug (both sides are resampled to the same count first);
        // it must degrade to "no match", never to a spuriously good score. The no-op
        // onMismatch suppresses the DEBUG assertion so the release-mode fallback value is
        // testable (tests run with assertions enabled).
        let a = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        let b = [CGPoint(x: 0, y: 0)]
        XCTAssertEqual(QwertyGlidePath.channelDistance(a, b, onMismatch: { _ in }),
                       .greatestFiniteMagnitude)
        XCTAssertEqual(QwertyGlidePath.channelDistance(b, a, onMismatch: { _ in }),
                       .greatestFiniteMagnitude)
        XCTAssertEqual(QwertyGlidePath.channelDistance([], b, onMismatch: { _ in }),
                       .greatestFiniteMagnitude)
    }

    func testChannelDistanceLengthMismatchReportsLoudly() {
        // The DEBUG loudness contract: a mismatch invokes onMismatch (assertionFailure by
        // default) exactly once, with both counts in the message.
        let a = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        let b = [CGPoint(x: 0, y: 0)]
        var messages: [String] = []
        _ = QwertyGlidePath.channelDistance(a, b, onMismatch: { messages.append($0) })
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].contains("2 vs 1"), "message was: \(messages)")
    }

    // MARK: - Large-input stability

    func testResampleLargePathIsStableAndUniform() {
        // 10,001-point sine wave (perf canary + large-input stability): output count is the
        // default sampleCount, endpoints are exact, every output is finite, and consecutive
        // gaps stay near-uniform (chord lengths on a smooth dense path at equal ARC steps).
        let points = (0...10_000).map { index -> CGPoint in
            let x = CGFloat(index) * 0.1
            return CGPoint(x: x, y: 10 * sin(x / 50))
        }
        let resampled = QwertyGlidePath.resample(points)
        XCTAssertEqual(resampled.count, QwertyGlidePath.sampleCount)
        XCTAssertEqual(resampled.first, points.first)
        XCTAssertEqual(resampled.last, points.last)
        for point in resampled {
            XCTAssertTrue(point.x.isFinite && point.y.isFinite)
        }
        let gaps = (1..<resampled.count).map { distance(resampled[$0 - 1], resampled[$0]) }
        let meanGap = gaps.reduce(0, +) / CGFloat(gaps.count)
        XCTAssertGreaterThan(meanGap, 0)
        for (index, gap) in gaps.enumerated() {
            XCTAssertEqual(gap, meanGap, accuracy: meanGap * 0.05,
                           "gap \(index) strays >5% from the mean")
        }
    }

    func testResampleCountTwoReturnsExactEndpointsOnly() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 0), CGPoint(x: 3, y: 3)]
        let resampled = QwertyGlidePath.resample(points, to: 2)
        XCTAssertEqual(resampled, [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 3)])
    }
}
