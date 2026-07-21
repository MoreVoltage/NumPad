//
//  QwertyNextWordPredictorTests.swift
//  NumPadTests
//
//  Unit tests for the bigram next-word predictor (Task 8 harness arm). Every
//  test runs against a small fixture lexicon built through the SAME
//  `QwertyFrequencyLexicon.encode(rankedWords:)` path production uses, and a
//  bigram blob built through `QwertyNextWordPredictor.encode(heads:)` — the
//  exact encoder `tools/make_qwerty_bigrams.swift` uses — so the predictor is
//  exercised over the real packed-blob reader, not a mock.
//

import XCTest
@testable import NumPad

final class QwertyNextWordPredictorTests: XCTestCase {

    // MARK: - Fixtures

    /// Ranks by list position: "the"=0, "cat"=1, "sat"=2, "on"=3, "mat"=4,
    /// "dog"=5, "ran"=6.
    private let fixtureWords = ["the", "cat", "sat", "on", "mat", "dog", "ran"]

    private func fixtureLexicon() -> QwertyFrequencyLexicon {
        QwertyFrequencyLexicon(data: QwertyFrequencyLexicon.encode(rankedWords: fixtureWords))
    }

    /// Rank of `word` in the fixture lexicon — fails the test on a typo in the
    /// fixture itself rather than silently encoding a wrong rank.
    private func rank(_ word: String, file: StaticString = #filePath,
                      line: UInt = #line) -> Int {
        let rank = fixtureLexicon().rank(of: word)
        XCTAssertNotNil(rank, "\(word) missing from fixture lexicon", file: file, line: line)
        return rank ?? -1
    }

    private func predictor(heads: [(headRank: Int, continuationRanks: [Int])])
        -> QwertyNextWordPredictor {
        QwertyNextWordPredictor(data: QwertyNextWordPredictor.encode(heads: heads),
                                lexicon: fixtureLexicon())
    }

    /// The standard fixture table: "the" → cat, dog, mat; "cat" → sat, ran, on, mat
    /// (four continuations, to exercise the default max of 3); "on" → the.
    private func standardPredictor() -> QwertyNextWordPredictor {
        predictor(heads: [
            (headRank: rank("the"), continuationRanks: [rank("cat"), rank("dog"), rank("mat")]),
            (headRank: rank("cat"), continuationRanks: [rank("sat"), rank("ran"),
                                                        rank("on"), rank("mat")]),
            (headRank: rank("on"), continuationRanks: [rank("the")]),
        ])
    }

    // MARK: - Lookup

    func testKnownHeadReturnsContinuationsInStoredOrder() {
        XCTAssertEqual(standardPredictor().predictions(after: "the"),
                       ["cat", "dog", "mat"])
    }

    func testHeadNotInLexiconReturnsEmpty() {
        XCTAssertEqual(standardPredictor().predictions(after: "zebra"), [])
    }

    func testHeadInLexiconButWithoutBigramsReturnsEmpty() {
        // "dog" is a lexicon word but no head record exists for it.
        XCTAssertEqual(standardPredictor().predictions(after: "dog"), [])
    }

    func testEmptyHeadReturnsEmpty() {
        XCTAssertEqual(standardPredictor().predictions(after: ""), [])
    }

    // MARK: - Max cap

    func testDefaultMaxIsThree() {
        // "cat" stores FOUR continuations; the default window returns three.
        XCTAssertEqual(standardPredictor().predictions(after: "cat"),
                       ["sat", "ran", "on"])
    }

    func testExplicitMaxCapsResults() {
        XCTAssertEqual(standardPredictor().predictions(after: "the", max: 1), ["cat"])
    }

    func testMaxLargerThanStoredReturnsAllStored() {
        XCTAssertEqual(standardPredictor().predictions(after: "on", max: 5), ["the"])
    }

    func testNonPositiveMaxReturnsEmpty() {
        XCTAssertEqual(standardPredictor().predictions(after: "the", max: 0), [])
    }

    // MARK: - Case folding

    func testUppercaseHeadFoldsToLowercaseLookup() {
        XCTAssertEqual(standardPredictor().predictions(after: "The"),
                       ["cat", "dog", "mat"])
    }

    func testPredictionsAreLowercase() {
        for word in standardPredictor().predictions(after: "THE") {
            XCTAssertEqual(word, word.lowercased())
        }
    }

    // MARK: - Corrupt data never crashes (boundary discipline mirrors
    // QwertyFrequencyLexicon: any invalid blob degrades to an empty predictor)

    func testEmptyDataYieldsEmptyPredictor() {
        let sut = QwertyNextWordPredictor(data: Data(), lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testWrongMagicYieldsEmptyPredictor() {
        var blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [rank("cat")])])
        blob[blob.startIndex] = 0x58 // "X" — not "N"
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testWrongVersionYieldsEmptyPredictor() {
        var blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [rank("cat")])])
        blob[blob.startIndex + 4] = 99
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testTruncatedDataYieldsEmptyPredictor() {
        let blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [rank("cat"), rank("dog")])])
        // Chop every possible tail length — none may crash, all must miss.
        for keep in 0..<blob.count {
            let sut = QwertyNextWordPredictor(data: blob.prefix(keep),
                                              lexicon: fixtureLexicon())
            XCTAssertEqual(sut.predictions(after: "the"), [],
                           "truncation at \(keep) bytes must yield an empty predictor")
        }
    }

    func testOverstatedHeadCountYieldsEmptyPredictor() {
        var blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [rank("cat")])])
        blob[blob.startIndex + 5] = 200 // claims 200 heads; records for 1
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testGarbageDataYieldsEmptyPredictor() {
        let garbage = Data((0..<64).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) })
        let sut = QwertyNextWordPredictor(data: garbage, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testContinuationRankBeyondLexiconIsSkippedNotCrashed() {
        // Rank 6 ("ran") is the last fixture word; a blob encoded against a
        // BIGGER lexicon could carry ranks this lexicon lacks. Encode such a
        // rank manually via a head list the encoder accepts (rank fits UInt16),
        // then read it against the small lexicon.
        let blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [4000, rank("cat")])])
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), ["cat"])
    }

    // MARK: - Encoder normalization (round-trip behavior)

    func testEncoderSortsHeadsByRankForLookup() {
        // Deliberately unsorted input; lookup must still find every head.
        let sut = predictor(heads: [
            (headRank: rank("on"), continuationRanks: [rank("the")]),
            (headRank: rank("the"), continuationRanks: [rank("cat")]),
        ])
        XCTAssertEqual(sut.predictions(after: "the"), ["cat"])
        XCTAssertEqual(sut.predictions(after: "on"), ["the"])
    }

    func testEncoderDropsDuplicateHeadsFirstWins() {
        let sut = predictor(heads: [
            (headRank: rank("the"), continuationRanks: [rank("cat")]),
            (headRank: rank("the"), continuationRanks: [rank("dog")]),
        ])
        XCTAssertEqual(sut.predictions(after: "the"), ["cat"])
    }

    func testEncoderDropsHeadsWithNoEncodableContinuations() {
        // A continuation rank beyond UInt16 cannot be stored; with no valid
        // continuations left the head record itself is dropped.
        let blob = QwertyNextWordPredictor.encode(
            heads: [(headRank: rank("the"), continuationRanks: [Int(UInt16.max) + 1])])
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "the"), [])
    }

    func testEncoderDropsOutOfRangeHeadRanks() {
        let blob = QwertyNextWordPredictor.encode(heads: [
            (headRank: -1, continuationRanks: [rank("cat")]),
            (headRank: Int(UInt16.max) + 1, continuationRanks: [rank("cat")]),
            (headRank: rank("on"), continuationRanks: [rank("the")]),
        ])
        let sut = QwertyNextWordPredictor(data: blob, lexicon: fixtureLexicon())
        XCTAssertEqual(sut.predictions(after: "on"), ["the"])
    }
}
