//
//  make_qwerty_bigrams.swift
//  NumPad tools
//
//  Offline generator for the packed QWERTY bigram next-word table. Reads an
//  AOSP-format `.combined` wordlist (see tools/data/eval/README.md, section
//  "Next-word bigram source", for the verified CC BY 4.0 source), keeps the
//  bigrams whose head AND continuation both exist in our production frequency
//  lexicon, keeps the top continuations per head by the source's own frequency
//  attribute (`f=1` marks the most frequent continuation), and packs them with
//  the exact same encoder the app uses (QwertyNextWordPredictor.encode) so the
//  on-device reader round-trips by construction.
//
//  Build & run (from the repo root):
//    swiftc -O -o /tmp/mkbigrams tools/make_qwerty_bigrams.swift \
//        NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift \
//        NumPad/Libraries/Qwerty/QwertyNextWordPredictor.swift
//    /tmp/mkbigrams <wordlist.combined> Keyboard/Resources/qwerty_lexicon_en.bin \
//        Keyboard/Resources/qwerty_bigrams_en.bin
//

import Foundation

@main
struct MakeQwertyBigrams {

    /// Continuations kept per head, best-first by the source's own frequency
    /// attribute. (The adopted source caps at 3 per head, so 8 does not bind
    /// today — it guards against a richer future source.)
    private static let maxContinuationsPerHead = 8

    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            fail("usage: \(arguments.first ?? "mkbigrams") "
                 + "<wordlist.combined> <lexicon.bin> <output.bin>")
        }
        let combinedPath = arguments[1]
        let lexiconPath = arguments[2]
        let outputPath = arguments[3]

        guard let lexiconData = FileManager.default.contents(atPath: lexiconPath) else {
            fail("error: cannot read \(lexiconPath)")
        }
        let lexicon = QwertyFrequencyLexicon(data: lexiconData)
        guard lexicon.rank(of: "the") != nil else {
            fail("error: \(lexiconPath) did not decode to a usable lexicon")
        }

        let combined: String
        do {
            combined = try String(contentsOfFile: combinedPath, encoding: .utf8)
        } catch {
            fail("error: cannot read \(combinedPath): \(error.localizedDescription)")
        }

        let table = bigramTable(fromCombined: combined, lexicon: lexicon)
        guard !table.heads.isEmpty else {
            fail("error: no usable bigrams in \(combinedPath)")
        }

        let blob = QwertyNextWordPredictor.encode(heads: table.heads)
        do {
            try blob.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            fail("error: cannot write \(outputPath): \(error.localizedDescription)")
        }

        // Round-trip self-check through the production reader.
        let predictor = QwertyNextWordPredictor(data: blob, lexicon: lexicon)
        guard !predictor.predictions(after: "the").isEmpty else {
            fail("error: round-trip self-check failed — 'the' has no predictions")
        }

        let entryCount = table.heads.reduce(0) { $0 + $1.continuationRanks.count }
        print("""
        wrote \(blob.count) bytes to \(outputPath)
        heads kept: \(table.heads.count) (of \(table.headsSeen) heads with bigrams in source)
        bigram entries kept: \(entryCount) (of \(table.bigramLinesSeen) source bigram lines)
        dropped — head not in lexicon: \(table.droppedHeadOutOfLexicon) lines; \
        continuation not in lexicon: \(table.droppedContinuationOutOfLexicon) lines
        sample: the → \(predictor.predictions(after: "the").joined(separator: ", "))
        """)
    }

    // MARK: - Parsing

    private struct BigramTable {
        var heads: [(headRank: Int, continuationRanks: [Int])] = []
        var headsSeen = 0
        var bigramLinesSeen = 0
        var droppedHeadOutOfLexicon = 0
        var droppedContinuationOutOfLexicon = 0
    }

    /// Parses the `.combined` format: ` word=<w>,f=…` opens a head block and
    /// indented `  bigram=<b>,f=<k>` lines below it are its continuations,
    /// where LOWER `f` marks a MORE frequent continuation (the generator
    /// assigns f=1 to the most frequent — verified against the source's
    /// scripts/wordlist.py). Both sides are lowercased and must exist in the
    /// lexicon; continuations are ordered by (f ascending, appearance order)
    /// and capped at `maxContinuationsPerHead`.
    private static func bigramTable(fromCombined combined: String,
                                    lexicon: QwertyFrequencyLexicon) -> BigramTable {
        var table = BigramTable()
        var currentHeadRank: Int?
        var currentHeadHadBigrams = false
        var currentContinuations: [(f: Int, order: Int, rank: Int)] = []

        func flushHead() {
            if currentHeadHadBigrams { table.headsSeen += 1 }
            if let headRank = currentHeadRank, !currentContinuations.isEmpty {
                let ranked = currentContinuations
                    .sorted { ($0.f, $0.order) < ($1.f, $1.order) }
                    .map(\.rank)
                table.heads.append((headRank: headRank,
                                    continuationRanks: Array(ranked.prefix(maxContinuationsPerHead))))
            }
            currentHeadRank = nil
            currentHeadHadBigrams = false
            currentContinuations = []
        }

        for rawLine in combined.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("word=") {
                flushHead()
                currentHeadRank = lexicon.rank(of: firstField(of: line, after: "word="))
            } else if line.hasPrefix("bigram=") {
                table.bigramLinesSeen += 1
                currentHeadHadBigrams = true
                guard currentHeadRank != nil else {
                    table.droppedHeadOutOfLexicon += 1
                    continue
                }
                guard let continuationRank = lexicon.rank(
                    of: firstField(of: line, after: "bigram=")) else {
                    table.droppedContinuationOutOfLexicon += 1
                    continue
                }
                currentContinuations.append((f: frequencyAttribute(of: line),
                                             order: currentContinuations.count,
                                             rank: continuationRank))
            }
        }
        flushHead()
        return table
    }

    /// The value between `prefix` and the next comma, lowercased.
    private static func firstField(of line: String, after prefix: String) -> String {
        String(line.dropFirst(prefix.count).prefix(while: { $0 != "," })).lowercased()
    }

    /// The line's `f=` attribute, or `Int.max` when absent/garbled (sorts last).
    private static func frequencyAttribute(of line: String) -> Int {
        for field in line.split(separator: ",").dropFirst()
            where field.hasPrefix("f=") {
            return Int(field.dropFirst(2)) ?? Int.max
        }
        return Int.max
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
