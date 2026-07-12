//
//  QwertyTouchPersonalizationTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class QwertyTouchPersonalizationTests: XCTestCase {

    // MARK: - Warmup: no output until a key has enough samples

    func testOffsetIsNilBeforeAnyRecording() {
        let model = QwertyTouchPersonalization()
        XCTAssertNil(model.offset(forKeyCharacter: "a"))
    }

    func testOffsetIsNilDuringWarmupAndAppearsAtWarmupThreshold() {
        var model = QwertyTouchPersonalization()
        for sample in 1..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "a", normalizedOffset: (dx: 0.2, dy: -0.1))
            XCTAssertNil(model.offset(forKeyCharacter: "a"),
                         "sample \(sample) is still warmup — no output yet")
        }
        model.recordAcceptedTap(keyCharacter: "a", normalizedOffset: (dx: 0.2, dy: -0.1))
        XCTAssertNotNil(model.offset(forKeyCharacter: "a"),
                        "warmupSamples-th sample crosses the threshold")
    }

    func testWarmupIsTrackedPerKey() {
        var model = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "a", normalizedOffset: (dx: 0.1, dy: 0))
        }
        model.recordAcceptedTap(keyCharacter: "b", normalizedOffset: (dx: 0.1, dy: 0))
        XCTAssertNotNil(model.offset(forKeyCharacter: "a"))
        XCTAssertNil(model.offset(forKeyCharacter: "b"), "b has one sample — still warming up")
    }

    // MARK: - EMA behavior

    func testConstantBiasIsLearnedExactly() throws {
        var model = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "e", normalizedOffset: (dx: 0.15, dy: -0.08))
        }
        let offset = try XCTUnwrap(model.offset(forKeyCharacter: "e"))
        // The first sample seeds the EMA, and identical samples never move it.
        XCTAssertEqual(offset.dx, 0.15, accuracy: 0.000_001)
        XCTAssertEqual(offset.dy, -0.08, accuracy: 0.000_001)
    }

    func testEMAConvergesTowardConstantBiasAfterOutlier() throws {
        var model = QwertyTouchPersonalization()
        // An outlier first, then a steady habitual bias — the EMA must converge on the
        // steady bias, forgetting the outlier.
        model.recordAcceptedTap(keyCharacter: "s", normalizedOffset: (dx: 0.5, dy: 0.5))
        for _ in 0..<40 {
            model.recordAcceptedTap(keyCharacter: "s", normalizedOffset: (dx: -0.2, dy: 0.1))
        }
        let offset = try XCTUnwrap(model.offset(forKeyCharacter: "s"))
        XCTAssertEqual(offset.dx, -0.2, accuracy: 0.01)
        XCTAssertEqual(offset.dy, 0.1, accuracy: 0.01)
    }

    func testEMAStepMatchesSmoothingFactor() throws {
        var model = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "k", normalizedOffset: (dx: 0, dy: 0))
        }
        model.recordAcceptedTap(keyCharacter: "k", normalizedOffset: (dx: 1.0, dy: 0))
        let offset = try XCTUnwrap(model.offset(forKeyCharacter: "k"))
        // One EMA step from 0 toward 1 moves exactly by the smoothing alpha.
        XCTAssertEqual(offset.dx, QwertyTouchPersonalization.smoothing, accuracy: 0.000_001)
        XCTAssertEqual(offset.dy, 0, accuracy: 0.000_001)
    }

    // MARK: - Key folding & input hygiene

    func testKeyLookupIsCaseFolded() throws {
        var model = QwertyTouchPersonalization()
        // Shifted and unshifted taps of the same physical key accumulate as ONE entry.
        for index in 0..<QwertyTouchPersonalization.warmupSamples {
            let character = index.isMultiple(of: 2) ? "A" : "a"
            model.recordAcceptedTap(keyCharacter: character, normalizedOffset: (dx: 0.1, dy: 0.2))
        }
        let viaUpper = try XCTUnwrap(model.offset(forKeyCharacter: "A"))
        let viaLower = try XCTUnwrap(model.offset(forKeyCharacter: "a"))
        XCTAssertEqual(viaUpper.dx, viaLower.dx, accuracy: 0.000_001)
        XCTAssertEqual(viaUpper.dy, viaLower.dy, accuracy: 0.000_001)
    }

    func testIsPersonalizablePredicate() {
        XCTAssertTrue(QwertyTouchPersonalization.isPersonalizable("a"))
        XCTAssertTrue(QwertyTouchPersonalization.isPersonalizable("Q"))
        XCTAssertTrue(QwertyTouchPersonalization.isPersonalizable("é"))
        XCTAssertFalse(QwertyTouchPersonalization.isPersonalizable("."))
        XCTAssertFalse(QwertyTouchPersonalization.isPersonalizable("1"))
        XCTAssertFalse(QwertyTouchPersonalization.isPersonalizable(""))
        XCTAssertFalse(QwertyTouchPersonalization.isPersonalizable("ab"))
        XCTAssertFalse(QwertyTouchPersonalization.isPersonalizable(" "))
    }

    func testRejectsEmptyAndMultiCharacterKeys() {
        var model = QwertyTouchPersonalization()
        XCTAssertFalse(model.recordAcceptedTap(keyCharacter: "", normalizedOffset: (dx: 0.1, dy: 0)))
        XCTAssertFalse(model.recordAcceptedTap(keyCharacter: "ab", normalizedOffset: (dx: 0.1, dy: 0)))
        XCTAssertEqual(model, QwertyTouchPersonalization(), "rejected input must not mutate the model")
    }

    func testRejectsNonFiniteOffsets() {
        var model = QwertyTouchPersonalization()
        XCTAssertFalse(model.recordAcceptedTap(keyCharacter: "a",
                                               normalizedOffset: (dx: .nan, dy: 0)))
        XCTAssertFalse(model.recordAcceptedTap(keyCharacter: "a",
                                               normalizedOffset: (dx: 0, dy: .infinity)))
        XCTAssertEqual(model, QwertyTouchPersonalization(), "rejected input must not mutate the model")
    }

    func testClampsOffsetsIntoUnitRange() throws {
        var model = QwertyTouchPersonalization()
        // A gap-routed tap can land outside the key frame, so |offset| may exceed 0.5 —
        // but anything beyond a full key-size in either axis is junk and clamps to ±1.
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "m", normalizedOffset: (dx: 5.0, dy: -5.0))
        }
        let offset = try XCTUnwrap(model.offset(forKeyCharacter: "m"))
        XCTAssertEqual(offset.dx, 1.0, accuracy: 0.000_001)
        XCTAssertEqual(offset.dy, -1.0, accuracy: 0.000_001)
    }

    // MARK: - Codable / persistence

    func testCodableRoundTrip() throws {
        var model = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            model.recordAcceptedTap(keyCharacter: "a", normalizedOffset: (dx: 0.2, dy: -0.1))
        }
        model.recordAcceptedTap(keyCharacter: "b", normalizedOffset: (dx: -0.3, dy: 0.05))

        let data = model.encoded()
        XCTAssertFalse(data.isEmpty)
        let restored = QwertyTouchPersonalization(data: data)
        XCTAssertEqual(restored, model)

        // The restored copy behaves identically: warm key answers, cold key stays warming up.
        let offset = try XCTUnwrap(restored.offset(forKeyCharacter: "a"))
        XCTAssertEqual(offset.dx, 0.2, accuracy: 0.000_001)
        XCTAssertNil(restored.offset(forKeyCharacter: "b"))
    }

    func testEmptyDataDegradesToEmptyModel() {
        XCTAssertEqual(QwertyTouchPersonalization(data: Data()), QwertyTouchPersonalization())
    }

    func testCorruptDataDegradesToEmptyModel() {
        let corrupt = Data("not json at all".utf8)
        XCTAssertEqual(QwertyTouchPersonalization(data: corrupt), QwertyTouchPersonalization())
    }
}
