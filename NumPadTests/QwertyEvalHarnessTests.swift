//
//  QwertyEvalHarnessTests.swift
//  NumPadTests
//
//  Offline typing-quality measurement gate (research plan Task 5): scores six
//  candidate correction pipelines ("arms") over the committed typo corpora and
//  emits the markdown report that decides whether engine work (SymSpell/bigram)
//  happens at all — Task 6 runs this harness in full and reads that report.
//  Runs on the iOS simulator so `UITextChecker` behaves exactly as it does
//  inside the keyboard extension.
//
//  GATED OFF in normal suite runs: every test skips unless QWERTY_EVAL=1 is in
//  the environment. xcodebuild forwards TEST_RUNNER_-prefixed variables, so:
//      xcodebuild test ... TEST_RUNNER_QWERTY_EVAL=1
//
//  The harness MEASURES; it does not judge. Assertions are guards only:
//  corpora non-empty, the production lexicon actually loaded, every arm ran
//  every pair, report file written. Interpretation is Task 6's job.
//
//  HARD RULE (tools/data/eval/README.md): metrics are reported PER CORPUS,
//  never pooled — the synthetic corpus's adjacency noise model is exactly the
//  prior the spatial arm rewards, so pooling would launder that bias.
//

import UIKit
import XCTest
@testable import NumPad

final class QwertyEvalHarnessTests: XCTestCase {

    // MARK: - Tuning constants

    /// Candidate window for "top-3" accuracy and completion hit@3.
    private static let topWindow = 3

    /// Edit-distance classes reported individually; anything at or above the
    /// overflow class is folded into one "3+" bucket (wiki pairs can be far).
    private static let editDistanceOverflowClass = 3

    /// Fixed per-corpus sample size for the UNCACHED latency pass.
    private static let latencySampleTarget = 500

    /// Throwaway checker calls before any timing — UITextChecker's first calls
    /// pay one-off dictionary-load costs that would otherwise pollute p95.
    private static let warmupCallCount = 50

    private static let medianQuantile = 0.5
    private static let tailQuantile = 0.95
    private static let nanosecondsPerMillisecond = 1_000_000.0

    /// Combined-arm cost bucketing: spatial edit cost rounded to 1 decimal
    /// (multiply by 10, round) so frequency can arbitrate within a bucket.
    private static let combinedCostBucketScale = 10.0

    /// Report file name inside `FileManager.default.temporaryDirectory`.
    private static let reportFileName = "qwerty-eval-report.md"

    // MARK: - UITextChecker mirror

    /// Deliberate MIRROR of `QwertySpellChecker`
    /// (Keyboard/Libraries/QwertySpellChecker.swift). That adapter is
    /// Keyboard-target-only — an extension type this app-target test bundle
    /// cannot import — so the harness reproduces its exact `UITextChecker`
    /// call shapes: same `rangeOfMisspelledWord` arguments (`startingAt: 0`,
    /// `wrap: false`), same NSNotFound interpretation, same guesses-only-when-
    /// misspelled analyze contract, same completions range, and the same
    /// "en_US" language constant. The eval is only valid while these shapes
    /// stay byte-identical to the extension's — change the two files together.
    private final class CheckerMirror {

        /// Same value as `QwertySpellChecker.language`.
        private let language = "en_US"
        private let checker = UITextChecker()

        /// Mirrors the verdict + guesses legs of `QwertySpellChecker.analyze(word:)`
        /// (the completions leg is separate below — arms never use completions).
        func analysis(of word: String) -> (isMisspelled: Bool, guesses: [String]) {
            guard !word.isEmpty else { return (false, []) }
            let misspelled = misspelledRange(in: word)
            let guesses = misspelled.map {
                checker.guesses(forWordRange: $0, in: word, language: language) ?? []
            } ?? []
            return (misspelled != nil, guesses)
        }

        /// Mirrors `QwertySpellChecker.isMisspelled(word:)` — the verdict-only
        /// path the typo-variant repair oracle uses in production.
        func isMisspelled(word: String) -> Bool {
            guard !word.isEmpty else { return false }
            return misspelledRange(in: word) != nil
        }

        /// Mirrors the completions leg of `QwertySpellChecker.analyze(word:)`.
        func completions(for prefix: String) -> [String] {
            guard !prefix.isEmpty else { return [] }
            return checker.completions(
                forPartialWordRange: NSRange(location: 0, length: prefix.utf16.count),
                in: prefix,
                language: language) ?? []
        }

        /// Mirrors `QwertySpellChecker.misspelling(in:)`.
        private func misspelledRange(in word: String) -> NSRange? {
            let range = checker.rangeOfMisspelledWord(
                in: word,
                range: NSRange(location: 0, length: word.utf16.count),
                startingAt: 0,
                wrap: false,
                language: language)
            return range.location == NSNotFound ? nil : range
        }
    }

    /// One verdict + one guesses call per UNIQUE typed word, shared across all
    /// arms during accuracy tallying. `UITextChecker` is deterministic for a
    /// given (word, language), so the cache cannot change accuracy results —
    /// only wall clock. Latency is measured separately and NEVER through this
    /// cache (cached reads would fake the numbers).
    private final class CachedChecker {
        let mirror = CheckerMirror()
        private var analyses: [String: (isMisspelled: Bool, guesses: [String])] = [:]

        func analysis(of word: String) -> (isMisspelled: Bool, guesses: [String]) {
            if let cached = analyses[word] { return cached }
            let fresh = mirror.analysis(of: word)
            analyses[word] = fresh
            return fresh
        }
    }

    // MARK: - Arms

    /// The six candidate pipelines under measurement. All are built from the
    /// SAME single `UITextChecker` and the SAME loaded production lexicon.
    /// The personal-dictionary boost is deliberately part of NO arm — it is
    /// per-user state, unmeasurable offline.
    private enum Arm: String, CaseIterable {
        case floor
        case shipped
        case spatial
        case variants
        case variantsLast
        case combined

        /// One-line definition for the report's arm table.
        var definition: String {
            switch self {
            case .floor:
                return "raw UITextChecker guesses (system probability order)"
            case .shipped:
                return "`lexicon.rerankKnown(guesses)` — production before Task 2"
            case .spatial:
                return "`rerankKnown(SpatialScore.rerank(guesses))` — production after Task 2"
            case .variants:
                return "`rerankKnown(SpatialScore.rerank(TypoVariants.augment(guesses)))`"
                    + " with the verdict-only oracle — CURRENT production"
            case .variantsLast:
                return "augment applied AFTER both reranks (repair takes the head"
                    + " unconditionally) — arbitrates the Task-3 ordering question"
            case .combined:
                return "single-key sort of the augmented set: spatial cost bucketed to"
                    + " 1 decimal, then lexicon rank (unknown last), then incoming index"
                    + " — arbitrates the Task-2 composition question (harness-only experiment)"
            }
        }
    }

    /// Ranked candidates for `word` under `arm`. `analysis` supplies the shared
    /// checker outputs; `oracle` is the arm's real-word verdict closure (the
    /// caller caches it per arm — probes are part of the arm's own cost model,
    /// not shared across arms).
    private func candidates(arm: Arm,
                            word: String,
                            analysis: (isMisspelled: Bool, guesses: [String]),
                            lexicon: QwertyFrequencyLexicon,
                            oracle: (String) -> Bool) -> [String] {
        let guesses = analysis.guesses
        switch arm {
        case .floor:
            return guesses

        case .shipped:
            return lexicon.rerankKnown(guesses)

        case .spatial:
            return lexicon.rerankKnown(QwertySpatialScore.rerank(word: word, guesses: guesses))

        case .variants:
            // Faithful copy of QwertyPageHost.rankedGuesses(for:analysis:), including
            // its isMisspelled gate on the augment step, minus only the
            // personal-dictionary boost (excluded from every arm — see Arm doc).
            let augmented = analysis.isMisspelled
                ? QwertyTypoVariants.augment(guesses: guesses, word: word, isRealWord: oracle)
                : guesses
            return lexicon.rerankKnown(QwertySpatialScore.rerank(word: word, guesses: augmented))

        case .variantsLast:
            // The pinned Task-3 alternative: reranks first, augment last, so an
            // accepted doubling repair sits at index 0 unconditionally.
            let reranked = lexicon.rerankKnown(
                QwertySpatialScore.rerank(word: word, guesses: guesses))
            return analysis.isMisspelled
                ? QwertyTypoVariants.augment(guesses: reranked, word: word, isRealWord: oracle)
                : reranked

        case .combined:
            let augmented = analysis.isMisspelled
                ? QwertyTypoVariants.augment(guesses: guesses, word: word, isRealWord: oracle)
                : guesses
            return combinedSort(word: word, candidates: augmented, lexicon: lexicon)
        }
    }

    /// The `combined` arm's sort — an EXPERIMENT implemented here on purpose,
    /// never in the Qwerty modules: primary key = spatial edit cost bucketed to
    /// 1 decimal, tiebreak = lexicon rank (unknown words rank last within their
    /// bucket), final tiebreak = incoming index (stable).
    private func combinedSort(word: String,
                              candidates: [String],
                              lexicon: QwertyFrequencyLexicon) -> [String] {
        candidates.enumerated()
            .map { entry in
                (index: entry.offset,
                 word: entry.element,
                 bucket: (QwertySpatialScore.editCost(typed: word, candidate: entry.element)
                          * Self.combinedCostBucketScale).rounded(),
                 rank: lexicon.rank(of: entry.element) ?? Int.max)
            }
            .sorted { ($0.bucket, $0.rank, $0.index) < ($1.bucket, $1.rank, $1.index) }
            .map(\.word)
    }

    // MARK: - Pair classification

    /// A corpus pair with everything the metrics need precomputed once,
    /// shared by all six arms.
    private struct ClassifiedPair {
        let typed: String
        let intended: String
        /// Plain (unit-cost) Levenshtein distance typed→intended.
        let editDistance: Int
        /// For a single-substitution pair only: whether the slipped key is
        /// physically adjacent to the intended one. nil otherwise.
        let adjacentSubstitution: Bool?
        /// Whether the intended word exists in the production lexicon — the
        /// "reachable headroom" signal for the Task-6 gate.
        let intendedInLexicon: Bool
    }

    private func classify(_ pair: QwertyEvalCorpus.Pair,
                          lexicon: QwertyFrequencyLexicon) -> ClassifiedPair {
        ClassifiedPair(typed: pair.typed,
                       intended: pair.intended,
                       editDistance: Self.levenshtein(pair.typed, pair.intended),
                       adjacentSubstitution: Self.singleSubstitutionAdjacency(
                           typed: pair.typed, intended: pair.intended),
                       intendedInLexicon: lexicon.rank(of: pair.intended) != nil)
    }

    /// Plain unit-cost Levenshtein — deliberately NOT the spatial/OSA scorer:
    /// the distance CLASS split must be model-neutral.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let source = Array(a)
        let target = Array(b)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }
        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)
        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let substitution = previous[j - 1] + (source[i - 1] == target[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }

    /// For a same-length pair differing in exactly one position, whether that
    /// substitution is between physically adjacent keys; nil when the pair is
    /// not a single substitution.
    private static func singleSubstitutionAdjacency(typed: String, intended: String) -> Bool? {
        guard typed.count == intended.count else { return nil }
        let differences = zip(typed, intended).filter { $0 != $1 }
        guard differences.count == 1, let slip = differences.first else { return nil }
        return QwertyKeyGeometry.areAdjacent(slip.0, slip.1)
    }

    // MARK: - Tallying

    private struct SplitTally {
        var hits = 0
        var total = 0
        var percentText: String {
            total == 0 ? "—" : QwertyEvalHarnessTests.percentText(hits, of: total)
        }
    }

    private struct ArmTally {
        var pairCount = 0
        var top1 = 0
        var top3 = 0
        /// Keyed by min(editDistance, editDistanceOverflowClass).
        var top1ByDistanceClass: [Int: SplitTally] = [:]
        var adjacentSubstitutions = SplitTally()
        var nonAdjacentSubstitutions = SplitTally()
        var wrongTop1 = 0
        /// Of the top-1 misses, how many intended words the production lexicon
        /// KNOWS — corrections a dictionary-based engine could plausibly reach.
        var wrongTop1Reachable = 0

        mutating func record(pair: ClassifiedPair, candidates: [String]) {
            pairCount += 1
            let window = candidates.prefix(QwertyEvalHarnessTests.topWindow)
                .map { $0.lowercased() }
            let hitTop1 = window.first == pair.intended
            let hitTop3 = window.contains(pair.intended)
            if hitTop1 { top1 += 1 }
            if hitTop3 { top3 += 1 }

            let distanceClass = min(pair.editDistance,
                                    QwertyEvalHarnessTests.editDistanceOverflowClass)
            var split = top1ByDistanceClass[distanceClass, default: SplitTally()]
            split.total += 1
            if hitTop1 { split.hits += 1 }
            top1ByDistanceClass[distanceClass] = split

            if let adjacent = pair.adjacentSubstitution {
                if adjacent {
                    adjacentSubstitutions.total += 1
                    if hitTop1 { adjacentSubstitutions.hits += 1 }
                } else {
                    nonAdjacentSubstitutions.total += 1
                    if hitTop1 { nonAdjacentSubstitutions.hits += 1 }
                }
            }

            if !hitTop1 {
                wrongTop1 += 1
                if pair.intendedInLexicon { wrongTop1Reachable += 1 }
            }
        }
    }

    // MARK: - Corpus loading

    private struct Corpus {
        let name: String
        let pairs: [QwertyEvalCorpus.Pair]
    }

    /// The two committed typo corpora, loaded from the test bundle. Guards only:
    /// both must exist and be non-trivially sized.
    private func loadCorpora(bundle: Bundle) throws -> [Corpus] {
        let names = ["typos_en", "typos_wiki_en"]
        return try names.map { name in
            let corpus = QwertyEvalCorpus(bundledTSV: name, bundle: bundle)
            let pairs = try XCTUnwrap(corpus, "\(name).tsv missing from the test bundle").pairs
            XCTAssertFalse(pairs.isEmpty, "\(name).tsv parsed to zero pairs")
            return Corpus(name: name, pairs: pairs)
        }
    }

    /// Loads the REAL production lexicon blob from the test bundle and fails
    /// loudly if it degraded to empty — an empty lexicon makes every rerank the
    /// identity and would silently invalidate five of the six arms.
    private func loadProductionLexicon(bundle: Bundle) -> QwertyFrequencyLexicon {
        let lexicon = QwertyFrequencyLexicon(bundled: bundle)
        XCTAssertNotNil(lexicon.rank(of: "the"),
                        "qwerty_lexicon_en.bin absent/unreadable in the NumPadTests bundle — "
                        + "the harness must score against the production lexicon")
        return lexicon
    }

    // MARK: - Latency

    /// Deterministic fixed-size sample: an even stride across the (sorted)
    /// corpus, so the sample spans the alphabet instead of clustering at 'a'.
    private func latencySample(from pairs: [QwertyEvalCorpus.Pair]) -> [QwertyEvalCorpus.Pair] {
        guard pairs.count > Self.latencySampleTarget else { return pairs }
        let stride = pairs.count / Self.latencySampleTarget
        return (0..<Self.latencySampleTarget).map { pairs[$0 * stride] }
    }

    /// UNCACHED wall-clock per arm call over the fixed sample: every call pays
    /// the real verdict + guesses (+ the arm's own oracle probes) cost, exactly
    /// as production pays per word boundary. Runs separately from accuracy
    /// tallying — the accuracy pass's cache must never touch these numbers.
    private func measureLatency(pairs: [QwertyEvalCorpus.Pair],
                                lexicon: QwertyFrequencyLexicon,
                                mirror: CheckerMirror) -> [Arm: (p50: Double, p95: Double)] {
        let sample = latencySample(from: pairs)
        var results: [Arm: (p50: Double, p95: Double)] = [:]
        for arm in Arm.allCases {
            var durationsMs: [Double] = []
            durationsMs.reserveCapacity(sample.count)
            for pair in sample {
                let start = DispatchTime.now()
                let analysis = mirror.analysis(of: pair.typed)
                _ = candidates(arm: arm, word: pair.typed, analysis: analysis,
                               lexicon: lexicon,
                               oracle: { !mirror.isMisspelled(word: $0) })
                let end = DispatchTime.now()
                durationsMs.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
                                   / Self.nanosecondsPerMillisecond)
            }
            results[arm] = (percentile(durationsMs, Self.medianQuantile),
                            percentile(durationsMs, Self.tailQuantile))
        }
        return results
    }

    /// Percentile over an unsorted sample via linear-index rounding: picks the
    /// sorted element at `round((n−1)·q)` — not classic nearest-rank
    /// `ceil(q·n)`. Identical for arms compared against each other; only the
    /// index convention differs from textbook nearest-rank.
    private func percentile(_ values: [Double], _ quantile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * quantile).rounded())
        return sorted[index]
    }

    /// Throwaway calls so UITextChecker's one-off dictionary-load cost never
    /// lands inside a timed window.
    private func warmUp(_ mirror: CheckerMirror, pairs: [QwertyEvalCorpus.Pair]) {
        for pair in pairs.prefix(Self.warmupCallCount) {
            _ = mirror.analysis(of: pair.typed)
        }
    }

    // MARK: - Tests

    func testCorrectionArmsPerCorpus() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["QWERTY_EVAL"] == "1",
                          "Eval harness: run with TEST_RUNNER_QWERTY_EVAL=1")

        let bundle = Bundle(for: QwertyEvalHarnessTests.self)
        let lexicon = loadProductionLexicon(bundle: bundle)
        let corpora = try loadCorpora(bundle: bundle)
        let checker = CachedChecker()
        warmUp(checker.mirror, pairs: corpora[0].pairs)

        var correctionSections: [String] = []
        var latencySections: [String] = []
        var corpusSizeLines: [String] = []

        for corpus in corpora {
            corpusSizeLines.append("- `\(corpus.name)`: \(corpus.pairs.count) pairs")
            let classified = corpus.pairs.map { classify($0, lexicon: lexicon) }

            var tallies: [Arm: ArmTally] = [:]
            for arm in Arm.allCases {
                // Oracle verdicts cached per probed word WITHIN this arm only —
                // probes are part of the arm's own cost model, never shared.
                var oracleVerdicts: [String: Bool] = [:]
                let oracle: (String) -> Bool = { probe in
                    if let cached = oracleVerdicts[probe] { return cached }
                    let verdict = !checker.mirror.isMisspelled(word: probe)
                    oracleVerdicts[probe] = verdict
                    return verdict
                }
                var tally = ArmTally()
                for pair in classified {
                    let ranked = candidates(arm: arm,
                                            word: pair.typed,
                                            analysis: checker.analysis(of: pair.typed),
                                            lexicon: lexicon,
                                            oracle: oracle)
                    tally.record(pair: pair, candidates: ranked)
                }
                // Guard: every arm ran every pair of this corpus.
                XCTAssertEqual(tally.pairCount, classified.count,
                               "\(arm.rawValue) did not run every \(corpus.name) pair")
                tallies[arm] = tally
            }
            correctionSections.append(correctionTable(corpusName: corpus.name,
                                                      classified: classified,
                                                      tallies: tallies))

            let latency = measureLatency(pairs: corpus.pairs,
                                         lexicon: lexicon,
                                         mirror: checker.mirror)
            latencySections.append(latencyTable(corpusName: corpus.name,
                                                sampleSize: latencySample(from: corpus.pairs).count,
                                                latency: latency))
        }

        Self.storeSection(key: .corpora, content: corpusSizeLines.joined(separator: "\n"))
        Self.storeSection(key: .corrections,
                          content: correctionSections.joined(separator: "\n\n"))
        Self.storeSection(key: .latency, content: latencySections.joined(separator: "\n\n"))
        try flushReport()
    }

    /// Completion/KSR baseline: hold out each sentence's final word, ask the
    /// mirror for completions of every proper prefix, re-rank via the
    /// production completions path (`lexicon.rerank` — full rerank, because
    /// checker completions arrive alphabetical), and measure hit@1/hit@3 plus
    /// keystroke-savings-rate. This is the floor the future next-word arm must
    /// beat.
    func testCompletionKSRBaseline() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["QWERTY_EVAL"] == "1",
                          "Eval harness: run with TEST_RUNNER_QWERTY_EVAL=1")

        let bundle = Bundle(for: QwertyEvalHarnessTests.self)
        let lexicon = loadProductionLexicon(bundle: bundle)
        let sentences = QwertyEvalCorpus.sentences(bundledResource: "sentences_en",
                                                   bundle: bundle)
        XCTAssertFalse(sentences.isEmpty, "sentences_en.txt missing or empty")

        let mirror = CheckerMirror()
        // Warm-up on the held-out words themselves (throwaway completion calls).
        for sentence in sentences.prefix(Self.warmupCallCount) {
            if let word = sentence.split(separator: " ").last {
                _ = mirror.completions(for: String(word))
            }
        }

        var queries = 0
        var hit1 = 0
        var hit3 = 0
        var heldOutWords = 0
        var totalLetters = 0
        var savedKeystrokes = 0

        for sentence in sentences {
            let words = sentence.split(separator: " ").map(String.init)
            guard let target = words.last, !target.isEmpty else { continue }
            heldOutWords += 1
            totalLetters += target.count

            // Earliest prefix length whose top-1 completion is the target: the
            // point at which one accept-tap finishes the word.
            var earliestHit1Length: Int? = nil
            let characters = Array(target)
            // 1..<1 is empty for single-letter words — no proper prefix exists.
            for prefixLength in 1..<characters.count {
                let prefix = String(characters[..<prefixLength])
                let ranked = lexicon.rerank(mirror.completions(for: prefix))
                queries += 1
                let window = ranked.prefix(Self.topWindow).map { $0.lowercased() }
                if window.first == target {
                    hit1 += 1
                    if earliestHit1Length == nil { earliestHit1Length = prefixLength }
                }
                if window.contains(target) { hit3 += 1 }
            }
            if let length = earliestHit1Length {
                savedKeystrokes += target.count - length
            }
        }

        XCTAssertGreaterThan(queries, 0, "no completion queries ran")

        let table = """
        Corpus: `sentences_en` — \(heldOutWords) held-out final words, \
        \(queries) prefix queries (every prefix length 1..<word length).

        | metric | value |
        |---|---|
        | hit@1 (prefix queries) | \(Self.percentText(hit1, of: queries)) (\(hit1)/\(queries)) |
        | hit@3 (prefix queries) | \(Self.percentText(hit3, of: queries)) (\(hit3)/\(queries)) |
        | keystroke savings rate | \(Self.percentText(savedKeystrokes, of: totalLetters)) \
        (\(savedKeystrokes) of \(totalLetters) letters saved) |

        KSR counts, per held-out word, `word.count - k` for the EARLIEST prefix
        length `k` whose top-1 completion is the word (accepting finishes it);
        words never hit at top-1 save nothing but still count their letters in
        the denominator. Pipeline: mirror `completions(forPartialWordRange:)` →
        `lexicon.rerank` (the production completions path; personal boost
        excluded as per-user state).
        """
        Self.storeSection(key: .ksr, content: table)
        try flushReport()
    }

    // MARK: - Report assembly

    /// Report sections persist across the two gated tests (static — one
    /// process), and `flushReport()` rewrites the single markdown document
    /// after each test, so a full QWERTY_EVAL=1 run of this class ends with
    /// ONE report containing everything; a single-test run ends with that
    /// test's sections.
    private enum SectionKey: String, CaseIterable {
        case corpora
        case arms
        case corrections
        case latency
        case ksr
        case notes
    }

    private static var sections: [SectionKey: String] = [:]

    private static func storeSection(key: SectionKey, content: String) {
        sections[key] = content
    }

    private static let sectionTitles: [SectionKey: String] = [
        .corpora: "Corpora",
        .arms: "Arms",
        .corrections: "Correction accuracy (per corpus — NEVER pooled)",
        .latency: "Latency (uncached, fixed 500-pair sample per corpus)",
        .ksr: "Completion / keystroke-savings baseline",
        .notes: "Notes",
    ]

    private func flushReport() throws {
        Self.storeSection(key: .arms, content: Self.armDefinitionsMarkdown)
        Self.storeSection(key: .notes, content: Self.notesMarkdown)

        var document = "# QWERTY offline typing-quality eval\n"
        for key in SectionKey.allCases {
            guard let content = Self.sections[key], let title = Self.sectionTitles[key] else {
                continue
            }
            document += "\n## \(title)\n\n\(content)\n"
        }

        print(document)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.reportFileName)
        try document.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "report file was not written")
        print("EVAL REPORT WRITTEN: \(url.path)")
    }

    private static var armDefinitionsMarkdown: String {
        Arm.allCases.map { "- **\($0.rawValue)** — \($0.definition)" }
            .joined(separator: "\n")
        + "\n\nAll arms share one `UITextChecker` (mirroring `QwertySpellChecker`'s"
        + " exact call shapes, language en_US) and the production"
        + " `qwerty_lexicon_en.bin`. The personal-dictionary boost is part of NO"
        + " arm — per-user state, unmeasurable offline."
    }

    private static var notesMarkdown: String {
        """
        Arbitration questions these arms answer (the harness measures; Task 6 judges):

        1. **Task-3 (augment position):** `variants` (augment BEFORE the reranks —
           spatial and frequency retain final authority over the auto-apply slot;
           current production) vs `variantsLast` (augment AFTER — an accepted
           doubling repair takes the head unconditionally).
        2. **Task-2 (composition):** `spatial` (frequency fully re-sorts
           corpus-known guesses, overriding spatial order within that group;
           current production) vs `combined` (frequency only arbitrates within a
           0.1-wide spatial-cost bucket — does frequency-within-cost-bucket beat
           frequency-overrides-spatial?).

        Corpus bias (tools/data/eval/README.md): `typos_en` is synthetic with an
        85% QWERTY-adjacent substitution model — biased toward the spatial arm by
        construction. `typos_wiki_en` is real human cognitive/phonetic errors.
        Metrics are therefore reported per corpus and must never be pooled.

        "Reachable headroom" = among an arm's top-1 MISSES, the share whose
        intended word the production lexicon knows — corrections a
        dictionary-based engine (SymSpell/bigram) could plausibly reach. This is
        the Task-6 gate's key column.

        Latency figures cover ONLY the word-boundary correction path —
        production also pays a completions call per keystroke that no arm
        times. Scoring is case-insensitive, uniform across arms (comparisons
        unbiased; absolute accuracy slightly lenient).
        """
    }

    private func correctionTable(corpusName: String,
                                 classified: [ClassifiedPair],
                                 tallies: [Arm: ArmTally]) -> String {
        let distanceCounts = Dictionary(grouping: classified) {
            min($0.editDistance, Self.editDistanceOverflowClass)
        }.mapValues(\.count)
        let adjacentTotal = classified.filter { $0.adjacentSubstitution == true }.count
        let nonAdjacentTotal = classified.filter { $0.adjacentSubstitution == false }.count
        let reachableIntended = classified.filter(\.intendedInLexicon).count

        var lines: [String] = []
        lines.append("### \(corpusName)")
        lines.append("")
        lines.append("\(classified.count) pairs — ed1: \(distanceCounts[1] ?? 0), "
                     + "ed2: \(distanceCounts[2] ?? 0), "
                     + "ed3+: \(distanceCounts[Self.editDistanceOverflowClass] ?? 0); "
                     + "single-substitution adjacent: \(adjacentTotal), "
                     + "non-adjacent: \(nonAdjacentTotal); "
                     + "intended-in-lexicon: \(Self.percentText(reachableIntended, of: classified.count))")
        lines.append("")
        lines.append("| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 "
                     + "| adj-sub top-1 | non-adj-sub top-1 | reachable headroom |")
        lines.append("|---|---|---|---|---|---|---|---|---|")
        for arm in Arm.allCases {
            guard let tally = tallies[arm] else { continue }
            let headroom = tally.wrongTop1 == 0
                ? "—"
                : Self.percentText(tally.wrongTop1Reachable, of: tally.wrongTop1)
                    + " of \(tally.wrongTop1) misses"
            lines.append("| \(arm.rawValue) "
                + "| \(Self.percentText(tally.top1, of: tally.pairCount)) "
                + "| \(Self.percentText(tally.top3, of: tally.pairCount)) "
                + "| \(tally.top1ByDistanceClass[1, default: SplitTally()].percentText) "
                + "| \(tally.top1ByDistanceClass[2, default: SplitTally()].percentText) "
                + "| \(tally.top1ByDistanceClass[Self.editDistanceOverflowClass, default: SplitTally()].percentText) "
                + "| \(tally.adjacentSubstitutions.percentText) "
                + "| \(tally.nonAdjacentSubstitutions.percentText) "
                + "| \(headroom) |")
        }
        return lines.joined(separator: "\n")
    }

    private func latencyTable(corpusName: String,
                              sampleSize: Int,
                              latency: [Arm: (p50: Double, p95: Double)]) -> String {
        var lines: [String] = []
        lines.append("### \(corpusName) (n=\(sampleSize) uncached calls per arm)")
        lines.append("")
        lines.append("| arm | p50 ms | p95 ms | Δp50 vs floor | Δp95 vs floor |")
        lines.append("|---|---|---|---|---|")
        let floor = latency[.floor] ?? (p50: 0, p95: 0)
        for arm in Arm.allCases {
            guard let timing = latency[arm] else { continue }
            lines.append(String(format: "| %@ | %.3f | %.3f | %+.3f | %+.3f |",
                                arm.rawValue,
                                timing.p50, timing.p95,
                                timing.p50 - floor.p50, timing.p95 - floor.p95))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting

    private static let percentScale = 100.0

    private static func percentText(_ hits: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return String(format: "%.1f%%", Double(hits) / Double(total) * percentScale)
    }
}
