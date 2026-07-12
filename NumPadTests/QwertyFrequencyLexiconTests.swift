//
//  QwertyFrequencyLexiconTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class QwertyFrequencyLexiconTests: XCTestCase {

    private var lexicon: QwertyFrequencyLexicon!

    override func setUp() {
        super.setUp()
        // encode() is the same encoder the offline tool uses — round-trip by construction.
        let data = QwertyFrequencyLexicon.encode(rankedWords: ["the", "of", "and", "hello", "world"])
        lexicon = QwertyFrequencyLexicon(data: data)
    }

    func testRankLookupReturnsCorpusOrder() {
        XCTAssertEqual(lexicon.rank(of: "the"), 0)
        XCTAssertEqual(lexicon.rank(of: "world"), 4)
        XCTAssertNil(lexicon.rank(of: "zzzz"))
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(lexicon.rank(of: "The"), 0)
        XCTAssertEqual(lexicon.rank(of: "HELLO"), 3)
    }

    func testRerankOrdersKnownByRankUnknownLastStable() {
        let out = lexicon.rerank(["world", "quix", "the", "zorp", "and"])
        XCTAssertEqual(out, ["the", "and", "world", "quix", "zorp"])  // quix/zorp keep input order
    }

    func testEmptyAndCorruptDataAreSafe() {
        XCTAssertNil(QwertyFrequencyLexicon(data: Data()).rank(of: "the"))
        XCTAssertNil(QwertyFrequencyLexicon(data: Data([0x00, 0x01])).rank(of: "the"))
    }

    /// Truncating a valid blob at every possible length exercises the record-level guards
    /// (`record(at:)`, `readUInt32`/`readUInt16`, mid-binary-search abort), not just the
    /// header validation. "the" sorts last by UTF-8 bytes, so its record straddles the end
    /// of the blob and every truncation must make its lookup miss safely.
    func testEveryTruncationLengthIsSafe() {
        let blob = QwertyFrequencyLexicon.encode(rankedWords: ["the", "of", "and"])
        for cut in 0..<blob.count {
            let truncated = QwertyFrequencyLexicon(data: blob.prefix(cut))
            XCTAssertNil(truncated.rank(of: "the"), "cut=\(cut)")
            XCTAssertLessThanOrEqual(truncated.allWords().count, 3, "cut=\(cut)")
            // Unknown words keep input order; must not trap regardless of truncation point.
            XCTAssertEqual(truncated.rerank(["zz", "qq"]), ["zz", "qq"], "cut=\(cut)")
        }
    }

    /// A structurally valid header whose offset table points outside the blob must read as
    /// safe misses, never trap: this is the corrupt-bundle case the bounds checks exist for.
    func testOutOfBoundsRecordOffsetsAreSafeMisses() {
        var blob = Data("NPLX".utf8)
        blob.append(1)                                // version
        blob.append(contentsOf: [2, 0, 0, 0])         // count = 2 (little-endian)
        blob.append(contentsOf: [200, 0, 0, 0])       // offset[0] -> past end of blob
        blob.append(contentsOf: [255, 255, 255, 127]) // offset[1] -> absurdly out of bounds
        let lexicon = QwertyFrequencyLexicon(data: blob)
        XCTAssertNil(lexicon.rank(of: "the"))
        XCTAssertEqual(lexicon.allWords(), [])
        XCTAssertEqual(lexicon.rerank(["b", "a"]), ["b", "a"])
    }

    func testWrongVersionReadsAsEmpty() {
        var blob = QwertyFrequencyLexicon.encode(rankedWords: ["the"])
        blob[4] = 2  // valid magic, unknown version
        let lexicon = QwertyFrequencyLexicon(data: blob)
        XCTAssertNil(lexicon.rank(of: "the"))
        XCTAssertEqual(lexicon.allWords(), [])
    }

    func testSingleRecordBlobLookup() {
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["hello"]))
        XCTAssertEqual(lexicon.rank(of: "hello"), 0)
        XCTAssertNil(lexicon.rank(of: "a"))  // below the only record
        XCTAssertNil(lexicon.rank(of: "z"))  // above the only record
        XCTAssertEqual(lexicon.allWords(), ["hello"])
    }

    func testEncodeDedupesCaseInsensitivelyFirstOccurrenceKeepsRank() {
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["The", "THE", "of", "the"]))
        XCTAssertEqual(lexicon.rank(of: "the"), 0)  // first occurrence wins its rank
        XCTAssertEqual(lexicon.rank(of: "of"), 1)   // duplicates don't consume ranks
        XCTAssertEqual(lexicon.allWords().count, 2)
    }

    func testWordsIteratesEveryEntryInByteOrder() {
        // encode() sorts records by UTF-8 byte order, so allWords() must return exactly that.
        XCTAssertEqual(QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["b", "a"])).allWords(),
            ["a", "b"])
    }
}
