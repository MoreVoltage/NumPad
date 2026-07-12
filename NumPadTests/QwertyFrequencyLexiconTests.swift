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

    func testWordsIteratesEveryEntryInByteOrder() {
        XCTAssertEqual(QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["b", "a"])).allWords().sorted(),
            ["a", "b"])
    }
}
