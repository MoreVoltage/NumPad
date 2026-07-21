//
//  QwertyEvalCorpusTests.swift
//  NumPadTests
//
//  Loader + seeded synthetic-typo generator for the offline eval corpus:
//  TSV parsing, determinism, adjacency weighting, and bundled-fixture loading.
//

import XCTest
@testable import NumPad

final class QwertyEvalCorpusTests: XCTestCase {

    func testParsesTSVPairs() {
        let corpus = QwertyEvalCorpus(tsv: "teh\tthe\nrecieve\treceive\n\nbad line\n")
        XCTAssertEqual(corpus.pairs.count, 2)
        XCTAssertEqual(corpus.pairs.first?.typed, "teh")
        XCTAssertEqual(corpus.pairs.first?.intended, "the")

        // CRLF line endings and stray trailing spaces are trimmed per field —
        // fixture corruption must not leak "the\r" or "teh " into the corpus.
        let messy = QwertyEvalCorpus(tsv: "teh \tthe\r\nrecieve\t receive\r\n")
        XCTAssertEqual(messy.pairs, [.init(typed: "teh", intended: "the"),
                                     .init(typed: "recieve", intended: "receive")])

        // Extra tabs are genuinely malformed: a doubled tab's empty middle field
        // and a trailing tab's empty last field both make >2 fields — dropped.
        let extraTabs = QwertyEvalCorpus(tsv: "a\t\tb\nteh\tthe\t\nfields\tok\n")
        XCTAssertEqual(extraTabs.pairs, [.init(typed: "fields", intended: "ok")])

        // A field that trims to nothing (whitespace-only) drops its pair.
        let blankField = QwertyEvalCorpus(tsv: " \tthe\nteh\t \n")
        XCTAssertTrue(blankField.pairs.isEmpty)
    }

    func testSyntheticGeneratorIsDeterministic() {
        let a = QwertyEvalCorpus.synthesizeTypos(words: ["hello", "world"], perWord: 3, seed: 42)
        let b = QwertyEvalCorpus.synthesizeTypos(words: ["hello", "world"], perWord: 3, seed: 42)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 6)
        XCTAssertTrue(a.allSatisfy { $0.typed != $0.intended })
    }

    func testSyntheticSubstitutionsPreferAdjacentKeys() {
        let pairs = QwertyEvalCorpus.synthesizeTypos(
            words: Array(repeating: "hello", count: 50), perWord: 4, seed: 7)
        let substitutions = pairs.compactMap { pair -> (Character, Character)? in
            guard pair.typed.count == pair.intended.count else { return nil }
            let diff = zip(pair.typed, pair.intended).filter { $0 != $1 }
            return diff.count == 1 ? diff[0] : nil
        }
        XCTAssertGreaterThan(substitutions.count, 10)   // enough samples to be meaningful
        let adjacent = substitutions.filter { QwertyKeyGeometry.areAdjacent($0.0, $0.1) }
        XCTAssertGreaterThan(Double(adjacent.count), 0.7 * Double(substitutions.count))
    }

    func testBundledFixturesLoad() {
        let bundle = Bundle(for: QwertyEvalCorpusTests.self)
        let corpus = QwertyEvalCorpus(bundledTSV: "typos_en", bundle: bundle)
        XCTAssertNotNil(corpus)
        XCTAssertGreaterThan(corpus?.pairs.count ?? 0, 500)
        let sentences = QwertyEvalCorpus.sentences(bundledResource: "sentences_en", bundle: bundle)
        XCTAssertGreaterThan(sentences.count, 200)
        XCTAssertTrue(sentences.allSatisfy { $0.allSatisfy { $0.isLowercase || $0 == " " } })

        // The Wikipedia corpus carries human cognitive/phonetic errors — the
        // de-bias counterweight to the adjacency-model synthetic corpus.
        let wiki = QwertyEvalCorpus(bundledTSV: "typos_wiki_en", bundle: bundle)
        XCTAssertNotNil(wiki)
        XCTAssertGreaterThan(wiki?.pairs.count ?? 0, 2000)
        let wikiPairs = wiki?.pairs ?? []
        XCTAssertTrue(wikiPairs.contains(.init(typed: "teh", intended: "the")))
        XCTAssertTrue(wikiPairs.contains(.init(typed: "recieve", intended: "receive")))
    }
}
