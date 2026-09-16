import XCTest
@testable import NumPad

final class QwertyCalibratedRoutingTests: XCTestCase {
    private let frames = [CGRect(x: 0, y: 0, width: 40, height: 50),
                          CGRect(x: 42, y: 0, width: 40, height: 50),
                          CGRect(x: 84, y: 0, width: 60, height: 50)]
    private let bounds = CGRect(x: 0, y: 0, width: 144, height: 50)

    func testCalibrationCanRecoverANeighborEdgeTap() {
        let point = CGPoint(x: 43, y: 25)
        XCTAssertEqual(QwertyTouchRouting.keyIndex(at: point, keyFrames: frames, in: bounds), 1)
        XCTAssertEqual(QwertyTouchRouting.calibratedKeyIndex(
            at: point, keyFrames: frames, in: bounds, characterIndices: [0, 1],
            offsets: [0: CGVector(dx: 12, dy: 0), 1: CGVector(dx: 12, dy: 0)]), 0)
    }

    func testCentralTapAndControlCannotBeStolen() {
        let offsets = [0: CGVector(dx: 1000, dy: 0), 1: CGVector(dx: -1000, dy: 0)]
        XCTAssertEqual(QwertyTouchRouting.calibratedKeyIndex(
            at: CGPoint(x: 20, y: 25), keyFrames: frames, in: bounds,
            characterIndices: [0, 1], offsets: offsets), 0)
        XCTAssertEqual(QwertyTouchRouting.calibratedKeyIndex(
            at: CGPoint(x: 85, y: 25), keyFrames: frames, in: bounds,
            characterIndices: [0, 1], offsets: offsets), 2)
    }

    func testNoProfileExactlyPreservesBaselineAcrossTheGrid() {
        for x in stride(from: CGFloat(-4), through: 148, by: 1) {
            let point = CGPoint(x: x, y: 24)
            XCTAssertEqual(QwertyTouchRouting.calibratedKeyIndex(
                at: point, keyFrames: frames, in: bounds, characterIndices: [0, 1], offsets: [:]),
                QwertyTouchRouting.keyIndex(at: point, keyFrames: frames, in: bounds))
        }
    }

    func testNonfiniteTouchFailsClosed() {
        XCTAssertNil(QwertyTouchRouting.calibratedKeyIndex(
            at: CGPoint(x: CGFloat.nan, y: 25), keyFrames: frames, in: bounds,
            characterIndices: [0, 1], offsets: [:]))
    }
}
