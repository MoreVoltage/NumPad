//
//  QwertyGlideDecoderTests.swift
//  NumPadTests
//

import CoreGraphics
import XCTest
@testable import NumPad

final class QwertyGlideDecoderTests: XCTestCase {

    // MARK: - Fixtures

    /// Synthetic 3-row grid of letter-key centers at a 10pt pitch, deliberately built in-test
    /// (no row stagger, nothing from QwertyLayout): the decoder must not care where the
    /// centers come from.
    private static let gridRows: [(letters: String, y: CGFloat)] = [
        (letters: "qwertyuiop", y: 0),
        (letters: "asdfghjkl", y: 10),
        (letters: "zxcvbnm", y: 20),
    ]

    private static func gridCenters() -> [String: CGPoint] {
        var centers: [String: CGPoint] = [:]
        for row in gridRows {
            for (index, letter) in row.letters.enumerated() {
                centers[String(letter)] = CGPoint(x: CGFloat(index) * 10, y: row.y)
            }
        }
        return centers
    }

    /// Grid pitch is 10 (nearest horizontal/vertical neighbors), so the start/end pruning
    /// tolerance under test is 1.6 x 10 = 16.
    private let pitch: CGFloat = 10

    private func makeDecoder(rankedWords: [String],
                             keyCenters: [String: CGPoint] = QwertyGlideDecoderTests.gridCenters())
        -> QwertyGlideDecoder {
        let blob = QwertyFrequencyLexicon.encode(rankedWords: rankedWords)
        return QwertyGlideDecoder(keyCenters: keyCenters,
                                  lexicon: QwertyFrequencyLexicon(data: blob))
    }

    /// The word's ideal template: the polyline through its letters' key centers.
    private func idealPath(for word: String,
                           centers: [String: CGPoint] = QwertyGlideDecoderTests.gridCenters())
        -> [CGPoint] {
        word.compactMap { centers[String($0)] }
    }

    /// Applies fixed per-vertex offsets (cycled) — deterministic "jitter", no randomness.
    private func jittered(_ path: [CGPoint], by offsets: [(x: CGFloat, y: CGFloat)]) -> [CGPoint] {
        path.enumerated().map { index, point in
            let offset = offsets[index % offsets.count]
            return CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }
    }

    /// Fixed jitter within +/-0.3 key pitches (3pt on the 10pt grid) per point.
    private let jitterOffsets: [(x: CGFloat, y: CGFloat)] =
        [(2, -3), (-3, 2), (3, 1), (-2, -2), (1, 3)]

    private let helloLexicon = ["hello", "help", "hell", "held", "jello", "gel"]

    // MARK: - Ideal and jittered paths decode to their word

    func testIdealHelloPathDecodesHelloFirst() {
        let decoder = makeDecoder(rankedWords: helloLexicon)
        let candidates = decoder.decode(path: idealPath(for: "hello"))
        XCTAssertEqual(candidates.first?.word, "hello")
        // The gesture IS the template polyline, so both channels are exactly zero.
        XCTAssertEqual(candidates.first?.score ?? -1, 0, accuracy: 1e-12)
    }

    func testJitteredHelloPathStillRanksHelloFirst() {
        let decoder = makeDecoder(rankedWords: helloLexicon)
        let path = jittered(idealPath(for: "hello"), by: jitterOffsets)
        let candidates = decoder.decode(path: path)
        XCTAssertEqual(candidates.first?.word, "hello")
        XCTAssertGreaterThan(candidates.first?.score ?? -1, 0)
    }

    func testEveryWordDecodesFirstFromItsOwnIdealPath() {
        // Pruning-correctness sweep: an exact template gesture must never be dropped —
        // anchors land at distance 0 and the length ratio is exactly 1 — and its two-channel
        // score is 0, so it ranks first (fixture has no identical-geometry pairs).
        let words = ["hello", "help", "held", "world", "water", "math", "pad", "quiz"]
        let decoder = makeDecoder(rankedWords: words)
        for word in words {
            let candidates = decoder.decode(path: idealPath(for: word), maxCandidates: 10)
            XCTAssertEqual(candidates.first?.word, word, "ideal path for '\(word)' lost itself")
        }
    }

    // MARK: - Pruning

    func testStartEndPruningNeverSurfacesFarWord() {
        // c(20,20) and b(40,20) sit 2 pitches apart — beyond the 1.6-pitch anchor tolerance,
        // so a "cat" gesture must never surface "bat".
        let decoder = makeDecoder(rankedWords: ["bat", "cat"])
        let candidates = decoder.decode(path: idealPath(for: "cat"), maxCandidates: 10)
        XCTAssertEqual(candidates.first?.word, "cat")
        XCTAssertFalse(candidates.contains { $0.word == "bat" })
    }

    func testNoSurvivorsReturnsEmpty() {
        // Gesture anchored on the z row; every lexicon word starts at h — all pruned.
        let decoder = makeDecoder(rankedWords: ["hello", "help"])
        let candidates = decoder.decode(path: [CGPoint(x: 0, y: 20), CGPoint(x: 10, y: 20)])
        XCTAssertEqual(candidates, [])
    }

    func testEmptyPathReturnsEmpty() {
        let decoder = makeDecoder(rankedWords: helloLexicon)
        XCTAssertEqual(decoder.decode(path: []), [])
    }

    func testPitchIsMinimumDistanceBetweenDistinctCenters() {
        // Pitch must be the minimum distance over DISTINCT centers: 4 (a-b), not 96 (b-c),
        // and the coincident d/a pair (distance 0) must be ignored, not collapse pitch to 0.
        // Tolerance is therefore 1.6 x 4 = 6.4: a start anchor 6pt from `a` survives, one
        // 6.5pt away does not.
        let centers: [String: CGPoint] = [
            "a": CGPoint(x: 0, y: 0),
            "b": CGPoint(x: 4, y: 0),
            "c": CGPoint(x: 100, y: 0),
            "d": CGPoint(x: 0, y: 0),
        ]
        let decoder = makeDecoder(rankedWords: ["ab"], keyCenters: centers)
        let inside = decoder.decode(path: [CGPoint(x: 6, y: 0), CGPoint(x: 4, y: 0)])
        XCTAssertEqual(inside.first?.word, "ab")
        let outside = decoder.decode(path: [CGPoint(x: 6.5, y: 0), CGPoint(x: 4, y: 0)])
        XCTAssertEqual(outside, [])
    }

    func testLengthRatioBandBoundsAreInclusive() {
        // "as" has ideal length 10. A 4pt gesture (ratio exactly 0.4) and a 22pt zigzag
        // (ratio exactly 2.2) both survive; both stay inside the 16pt anchor tolerance.
        let decoder = makeDecoder(rankedWords: ["as"])
        let shortest = decoder.decode(path: [CGPoint(x: 0, y: 10), CGPoint(x: 4, y: 10)])
        XCTAssertEqual(shortest.first?.word, "as")
        let longest = decoder.decode(path: [CGPoint(x: 0, y: 10), CGPoint(x: 13, y: 10),
                                            CGPoint(x: 4, y: 10)])
        XCTAssertEqual(longest.first?.word, "as")
    }

    func testLengthRatioBandRejectsOutsideBounds() {
        let decoder = makeDecoder(rankedWords: ["as"])
        let tooShort = decoder.decode(path: [CGPoint(x: 0, y: 10), CGPoint(x: 3.9, y: 10)])
        XCTAssertEqual(tooShort, [], "ratio 0.39 must fall below the 0.4 floor")
        let tooLong = decoder.decode(path: [CGPoint(x: 0, y: 10), CGPoint(x: 13.1, y: 10),
                                            CGPoint(x: 4, y: 10)])
        XCTAssertEqual(tooLong, [], "ratio 2.22 must exceed the 2.2 ceiling")
    }

    // MARK: - Single-letter words (degenerate zero-length templates)

    func testShortPathOnOneKeyDecodesSingleLetterWord() {
        let decoder = makeDecoder(rankedWords: ["a", "at", "i"])
        // A compact wiggle on `a` (0,10): far shorter than "at"'s ideal length band allows,
        // nowhere near `i`.
        let wiggle = [CGPoint(x: 0.5, y: 10.2), CGPoint(x: 1, y: 10.5), CGPoint(x: 0.4, y: 9.8)]
        let candidates = decoder.decode(path: wiggle, maxCandidates: 10)
        XCTAssertEqual(candidates.map(\.word), ["a"])
        // A single stationary point decodes the same way.
        let tap = decoder.decode(path: [CGPoint(x: 0, y: 10)], maxCandidates: 10)
        XCTAssertEqual(tap.map(\.word), ["a"])
    }

    func testLongScribbleOnOneKeyDecodesNothing() {
        // Documented semantics: a zero-length template skips the ratio band but requires the
        // GESTURE to be short (within the anchor tolerance). A 45pt scribble anchored at `a`
        // is not a single-letter tap — and it ends too far from `t` to be "at".
        let decoder = makeDecoder(rankedWords: ["a", "at", "i"])
        let scribble = [CGPoint(x: 0, y: 10), CGPoint(x: 15, y: 10),
                        CGPoint(x: 0, y: 10), CGPoint(x: 15, y: 10)]
        XCTAssertEqual(decoder.decode(path: scribble, maxCandidates: 10), [])
    }

    // MARK: - Frequency integration

    func testFrequencyBreaksTieOnIdenticalKeySequencePair() {
        // "to" and "too" trace IDENTICAL templates (the repeated o adds zero arc length), so
        // shape and location scores are equal on any gesture — only frequency can split them.
        // A slightly off-template gesture keeps the combined distance nonzero so the
        // multiplier has something to scale.
        let path = [CGPoint(x: 41, y: 1), CGPoint(x: 60, y: -2), CGPoint(x: 79, y: 2)]

        let toFirst = makeDecoder(rankedWords: ["to", "too"]).decode(path: path)
        XCTAssertEqual(toFirst.map(\.word), ["to", "too"])

        let tooFirst = makeDecoder(rankedWords: ["too", "to"]).decode(path: path)
        XCTAssertEqual(tooFirst.map(\.word), ["too", "to"])
    }

    func testFrequencyMultiplierFormula() {
        // score = combined x (0.7 + 0.6 x rank/50k): rank 0 pays x0.7, rank 50k pays x1.3 —
        // a ~1.86x advantage for the top-ranked word.
        XCTAssertEqual(QwertyGlideDecoder.frequencyMultiplier(rank: 0), 0.7, accuracy: 1e-12)
        XCTAssertEqual(QwertyGlideDecoder.frequencyMultiplier(rank: 50_000), 1.3, accuracy: 1e-9)
        let advantage = QwertyGlideDecoder.frequencyMultiplier(rank: 50_000)
            / QwertyGlideDecoder.frequencyMultiplier(rank: 0)
        XCTAssertEqual(advantage, 1.857, accuracy: 0.01)
    }

    // MARK: - Output contract

    func testMaxCandidatesCapsAndOrdersResults() {
        let decoder = makeDecoder(rankedWords: helloLexicon)
        let path = idealPath(for: "hello")

        let all = decoder.decode(path: path, maxCandidates: 10)
        XCTAssertGreaterThanOrEqual(all.count, 4, "fixture should keep several survivors")
        for index in 1..<all.count {
            XCTAssertLessThanOrEqual(all[index - 1].score, all[index].score,
                                     "candidates must be sorted by ascending score")
        }

        XCTAssertEqual(decoder.decode(path: path, maxCandidates: 2).count, 2)
        XCTAssertEqual(decoder.decode(path: path, maxCandidates: 0), [])
    }

    func testDecodeIsDeterministic() {
        let path = jittered(idealPath(for: "hello"), by: jitterOffsets)
        let decoder = makeDecoder(rankedWords: helloLexicon)
        let first = decoder.decode(path: path, maxCandidates: 10)
        let second = decoder.decode(path: path, maxCandidates: 10)
        XCTAssertEqual(first, second)
        // A freshly built decoder over the same fixture agrees bit-for-bit.
        let rebuilt = makeDecoder(rankedWords: helloLexicon).decode(path: path, maxCandidates: 10)
        XCTAssertEqual(first, rebuilt)
    }

    // MARK: - Lexicon filtering and degenerate layouts

    func testWordsWithUnmappedLettersAreDroppedAtInit() {
        // Apostrophe/hyphen words have no key center on the letters layer: they must be
        // filtered during init, never crash, never surface.
        let decoder = makeDecoder(rankedWords: ["can't", "cat", "co-op"])
        let candidates = decoder.decode(path: idealPath(for: "cat"), maxCandidates: 10)
        XCTAssertEqual(candidates.first?.word, "cat")
        XCTAssertFalse(candidates.contains { $0.word == "can't" || $0.word == "co-op" })
    }

    func testFewerThanTwoDistinctCentersDecodesNothing() {
        // With no second distinct center there is no pitch, so decode degrades to empty
        // rather than dividing by zero.
        let decoder = makeDecoder(rankedWords: ["a"], keyCenters: ["a": CGPoint(x: 0, y: 10)])
        XCTAssertEqual(decoder.decode(path: [CGPoint(x: 0, y: 10)]), [])
    }

    // MARK: - Realistic-scale smoke

    func testRealisticLexiconDecodesTargetWord() {
        // ~1k synthetic 4-letter words (base-26 encoding of 0..<1000, generation order =
        // rank order). Functional perf sanity: init filters the lot, decode prunes and still
        // lands the exact-template target first. No timing assertions — determinism only.
        let words = (0..<1000).map { Self.base26Word($0, length: 4) }
        XCTAssertEqual(words[731], "abcd", "fixture self-check")
        let decoder = makeDecoder(rankedWords: words)
        let candidates = decoder.decode(path: idealPath(for: "abcd"))
        XCTAssertEqual(candidates.first?.word, "abcd")
        XCTAssertLessThanOrEqual(candidates.count, 3)
    }

    private static func base26Word(_ value: Int, length: Int) -> String {
        var digits: [Int] = []
        var remaining = value
        for _ in 0..<length {
            digits.append(remaining % 26)
            remaining /= 26
        }
        return String(digits.reversed().map { Character(UnicodeScalar(97 + $0)!) })
    }
}
