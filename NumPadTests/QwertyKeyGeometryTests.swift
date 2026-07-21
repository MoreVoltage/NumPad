//
//  QwertyKeyGeometryTests.swift
//  NumPadTests
//
//  Tests for the pure QWERTY key-distance model: unit-grid positions,
//  pitch distances, and adjacency.
//

import XCTest
@testable import NumPad

final class QwertyKeyGeometryTests: XCTestCase {

    func testHorizontalNeighborsAreDistanceOne() {
        XCTAssertEqual(QwertyKeyGeometry.distance("q", "w")!, 1.0, accuracy: 0.001)
        XCTAssertEqual(QwertyKeyGeometry.distance("k", "l")!, 1.0, accuracy: 0.001)
    }

    func testDiagonalNeighborsAreCloserThanTwo() {
        // e (2,0) vs d (2.5,1) → sqrt(0.25 + 1) ≈ 1.118
        XCTAssertEqual(QwertyKeyGeometry.distance("e", "d")!, 1.118, accuracy: 0.01)
    }

    func testDistantKeys() {
        // q (0,0) vs p (9,0)
        XCTAssertEqual(QwertyKeyGeometry.distance("q", "p")!, 9.0, accuracy: 0.001)
    }

    func testAdjacency() {
        XCTAssertTrue(QwertyKeyGeometry.areAdjacent("e", "r"))
        XCTAssertTrue(QwertyKeyGeometry.areAdjacent("e", "d"))   // diagonal counts
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("e", "t"))  // two apart
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("q", "m"))
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("a", "a"))  // same key is never adjacent
    }

    func testCaseInsensitiveAndUnknownSafe() {
        XCTAssertEqual(QwertyKeyGeometry.distance("Q", "W"), 1.0)
        XCTAssertNil(QwertyKeyGeometry.distance("q", "é"))
        XCTAssertNil(QwertyKeyGeometry.distance("1", "q"))
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("q", "é"))
    }

    func testSameKeyIsZero() {
        XCTAssertEqual(QwertyKeyGeometry.distance("a", "a"), 0.0)
    }
}
