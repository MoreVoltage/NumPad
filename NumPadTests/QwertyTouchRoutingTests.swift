//
//  QwertyTouchRoutingTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class QwertyTouchRoutingTests: XCTestCase {

    // MARK: - Fixtures

    /// Two 40x40 keys side by side with a 10pt gap between them (x: 40...50), inside a
    /// 0...100 x 0...40 bounds. Mirrors the shape of the real gap problem: `QwertyKeyboardView`
    /// leaves a small margin between adjacent key frames.
    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 40)
    private let key0 = CGRect(x: 0, y: 0, width: 40, height: 40)
    private let key1 = CGRect(x: 50, y: 0, width: 40, height: 40)
    private var twoKeyFrames: [CGRect] { [key0, key1] }

    // MARK: - Direct hits always win

    func testDirectHitInsideKeyAlwaysWins() {
        let point = CGPoint(x: 20, y: 20) // inside key0
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds)
        XCTAssertEqual(index, 0)
    }

    func testDirectHitWinsEvenWithMaxBiasOnNeighbor() {
        let point = CGPoint(x: 70, y: 20) // inside key1
        // Max bias on key0, the neighbor -- must not steal a point that's a direct hit on key1.
        let bias: [Int: CGFloat] = [0: 1.0]
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds, bias: bias)
        XCTAssertEqual(index, 1)
    }

    // MARK: - Gap resolution: nearest key wins

    func testGapPointRoutesToNearestKey() {
        // x = 43 is 3pt from key0's right edge (x=40) and 7pt from key1's left edge (x=50).
        let point = CGPoint(x: 43, y: 20)
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds)
        XCTAssertEqual(index, 0)
    }

    func testGapPointRoutesToNearestKeyOtherSide() {
        // x = 47 is 7pt from key0's right edge and 3pt from key1's left edge.
        let point = CGPoint(x: 47, y: 20)
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds)
        XCTAssertEqual(index, 1)
    }

    func testGapResolutionUsesNearestEdgeNotCenter() {
        // A short, narrow key0 (e.g. a top-row letter key) and a tall key1 right beside it
        // (e.g. shift, which spans the whole row column). The touch point sits level with
        // key0's row, just past key0's right edge.
        //
        // By nearest-edge distance, key1 wins (0.1pt away) over key0 (1.9pt away) -- but if
        // routing used distance-to-*center* instead, key0's center (10, 5) is only 11.9pt away
        // while key1's center (32, 50) is 46.1pt away, so a center-based algorithm would wrongly
        // pick key0. This is exactly the "tall/wide keys behave naturally" requirement.
        let shortKey = CGRect(x: 0, y: 0, width: 20, height: 10)
        let tallKey = CGRect(x: 22, y: 0, width: 20, height: 100)
        let point = CGPoint(x: 21.9, y: 5)
        let frames = [shortKey, tallKey]
        let wideBounds = CGRect(x: 0, y: 0, width: 50, height: 100)
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: frames, in: wideBounds)
        XCTAssertEqual(index, 1, "nearest-edge distance should route to the tall key, not the short one")
    }

    // MARK: - Bias flips ambiguous gap points

    func testBiasFlipsWinnerForEquidistantGapPoint() {
        // x = 45 is exactly 5pt from both keys' facing edges.
        let point = CGPoint(x: 45, y: 20)

        let unbiasedIndex = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds)
        XCTAssertEqual(unbiasedIndex, 0, "with no bias, a tie resolves to the first (lowest index) key")

        let biasedIndex = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds,
                                                       bias: [1: 1.0])
        XCTAssertEqual(biasedIndex, 1, "max bias on key1 should flip the equidistant tie in its favor")
    }

    // MARK: - Cap prevents a distant biased key from stealing

    func testCapPreventsDistantBiasedKeyFromStealingClosePoint() {
        // key0 is close (distance 2); a distant key2 sits far away but has max bias 1.0. Even
        // fully biased, key2's effective distance is 0.7x its raw distance -- nowhere near
        // enough to beat a key that is genuinely much closer.
        let closeKey = CGRect(x: 0, y: 0, width: 40, height: 40)   // point is 2pt from its right edge
        let farKey = CGRect(x: 200, y: 0, width: 40, height: 40)   // ~158pt away
        let point = CGPoint(x: 42, y: 20)
        let frames = [closeKey, farKey]
        let wideBounds = CGRect(x: 0, y: 0, width: 300, height: 40)

        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: frames, in: wideBounds,
                                                bias: [1: 1.0])
        XCTAssertEqual(index, 0, "the cap must stop a max-biased far key from stealing a clearly closer touch")
    }

    // MARK: - Full-bounds tiling: every point maps to a key

    func testFullBoundsTilingNeverReturnsNil() {
        // A small realistic grid: 3 rows x 4 columns of keys with gaps between them and
        // around the edges, similar in spirit to QwertyKeyboardView's row/key gaps.
        let gridBounds = CGRect(x: 0, y: 0, width: 120, height: 90)
        var frames: [CGRect] = []
        for row in 0..<3 {
            for col in 0..<4 {
                let x = 3 + CGFloat(col) * 30 + 3
                let y = 3 + CGFloat(row) * 30 + 3
                frames.append(CGRect(x: x, y: y, width: 24, height: 24))
            }
        }

        var sampledAnyGap = false
        var sampleX: CGFloat = 0
        while sampleX <= gridBounds.width {
            var sampleY: CGFloat = 0
            while sampleY <= gridBounds.height {
                let point = CGPoint(x: sampleX, y: sampleY)
                let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: frames, in: gridBounds)
                XCTAssertNotNil(index, "every point inside bounds must route to some key")
                if let index = index {
                    XCTAssertTrue((0..<frames.count).contains(index))
                    if !frames[index].contains(point) { sampledAnyGap = true }
                }
                sampleY += 2.5
            }
            sampleX += 2.5
        }
        XCTAssertTrue(sampledAnyGap, "the sampling grid should have actually exercised gap points")
    }

    func testEmptyKeyFramesReturnsNil() {
        let index = QwertyTouchRouting.keyIndex(at: CGPoint(x: 10, y: 10), keyFrames: [], in: bounds)
        XCTAssertNil(index)
    }

    func testOutOfBoundsPointStillRoutesViaClamping() {
        // A touch reported a hair outside the view (can happen with real touch events) should
        // still resolve sanely rather than crashing or misbehaving.
        let point = CGPoint(x: -50, y: -50)
        let index = QwertyTouchRouting.keyIndex(at: point, keyFrames: twoKeyFrames, in: bounds)
        XCTAssertEqual(index, 0, "clamped into bounds, this lands directly on key0's top-left corner")
    }

    // MARK: - Bias derivation from completions

    func testBiasDerivationPrefixMatchingRankWeightingAndNormalization() {
        // currentWord "hel", completions rank-ordered "hello" (l), "help" (p), "held" (d).
        let completions = ["hello", "help", "held"]
        let keyOutputs: [Int: String] = [0: "l", 1: "p", 2: "d", 3: "q"]
        let bias = QwertyTouchRouting.bias(forCompletions: completions, currentWord: "hel", keyOutputs: keyOutputs)

        // Weights: rank0 = 1, rank1 = 1/2, rank2 = 1/3. Max is rank0's vote (key 0), so
        // normalized bias for key0 is 1.0; key1 is 0.5; key2 is 1/3.
        XCTAssertEqual(bias[0] ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(bias[1] ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(bias[2] ?? -1, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertNil(bias[3], "a key with no matching votes should not appear in the map")
    }

    func testBiasDerivationIsCaseInsensitiveOnPrefixAndOutput() {
        let bias = QwertyTouchRouting.bias(forCompletions: ["Hello"], currentWord: "HEL",
                                           keyOutputs: [5: "L"])
        XCTAssertEqual(bias[5] ?? -1, 1.0, accuracy: 0.0001)
    }

    func testBiasDerivationSumsVotesForSameKeyAcrossCompletions() {
        // Both completions continue "ap" with a "p" next-character -- key1's vote should be
        // the sum of both weighted votes, which then normalizes to 1.0 as the only key voted.
        let completions = ["apple", "apply"]
        let keyOutputs: [Int: String] = [1: "p"]
        let bias = QwertyTouchRouting.bias(forCompletions: completions, currentWord: "ap", keyOutputs: keyOutputs)
        XCTAssertEqual(bias[1] ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(bias.count, 1)
    }

    func testBiasDerivationIgnoresCompletionsNotContinuingCurrentWord() {
        let completions = ["banana"] // does not have "hel" as a prefix
        let keyOutputs: [Int: String] = [0: "l"]
        let bias = QwertyTouchRouting.bias(forCompletions: completions, currentWord: "hel", keyOutputs: keyOutputs)
        XCTAssertTrue(bias.isEmpty)
    }

    func testBiasDerivationIgnoresCompletionEqualToCurrentWord() {
        // "hel" itself has no character after the prefix -- must not vote or crash.
        let completions = ["hel"]
        let keyOutputs: [Int: String] = [0: "l"]
        let bias = QwertyTouchRouting.bias(forCompletions: completions, currentWord: "hel", keyOutputs: keyOutputs)
        XCTAssertTrue(bias.isEmpty)
    }

    func testBiasDerivationIgnoresMultiCharacterKeyOutputs() {
        // A key whose output is a multi-character token (e.g. a date/time token or "return")
        // must never receive a vote even if its first character would match.
        let completions = ["hello"]
        let keyOutputs: [Int: String] = [0: "lo"] // starts with "l" but isn't single-character
        let bias = QwertyTouchRouting.bias(forCompletions: completions, currentWord: "hel", keyOutputs: keyOutputs)
        XCTAssertTrue(bias.isEmpty)
    }

    func testBiasDerivationEmptyCurrentWordReturnsEmpty() {
        let bias = QwertyTouchRouting.bias(forCompletions: ["hello"], currentWord: "",
                                           keyOutputs: [0: "h"])
        XCTAssertTrue(bias.isEmpty)
    }

    func testBiasDerivationNoCompletionsReturnsEmpty() {
        let bias = QwertyTouchRouting.bias(forCompletions: [], currentWord: "hel",
                                           keyOutputs: [0: "l"])
        XCTAssertTrue(bias.isEmpty)
    }
}
