# QWERTY Typing Experience v2 — Implementation Plan

> **STATUS (2026-07-21, branch `feat/qwerty-typing-v2`): COMPLETE, with measured deviations —
> see `research/2026-07-21-eval-baseline.md` for all verdicts.** Task 2's production wiring was
> reversed by the Task-6b measurement (spatial rerank net-negative on both corpora;
> `QwertySpatialScore` is harness-only). Task 3 ships in the arbitrated augment-LAST shape
> (`rankedGuesses` = `augment(rerankKnown(guesses))`, wiki top-1 82.0%, +4.5pp over pre-branch
> production). Tasks 7–8 were built as harness arms and FAILED the pre-registered §C gates
> (SymSpell: quality + memory FAIL; bigram next-word: quality FAIL). **Task 9 wired nothing — no
> feature flags exist.** Definition of done met as amended by the recorded verdicts.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the researched-but-unbuilt typing-quality options — spatial (keyboard-geometry)
correction re-scoring, double-letter/adjacent-key typo variants, the pre-registered offline
evaluation harness, and (gated on harness results) a SymSpell-class corrector and an AOSP-derived
next-word prediction layer.

**Architecture:** Every new algorithm is a pure module in `NumPad/Libraries/Qwerty/` (compiled into
app + Keyboard targets, unit-tested in `NumPadTests`), with thin glue in
`Keyboard/Libraries/QwertyPageHost.swift`. The harness is an env-gated XCTest that scores every
candidate "arm" against a committed typo corpus and emits a report — it is the decision gate the
2026-07-05 research pre-registered before any engine adoption. `UITextChecker` stays the sole
spelling authority throughout (re-rank/augment, never replace).

**Tech Stack:** Swift/UIKit, XCTest (`NumPadTests`), CocoaPods workspace, classic pbxproj managed
via the `xcodeproj` Ruby gem (NOT synchronized groups), Hermit Dave `FrequencyWords` (already
bundled), GitHub Typo Corpus + Tatoeba (eval fixtures), Helium314 `aosp-dictionaries` (Task 8 only).

---

## Why this plan (context for an engineer with zero history)

The QWERTY page ("NumPad Type") ships a v1 accuracy stack on branch
`feat/qwerty-glide-and-accuracy` (36 commits ahead of master, unit suite 573/573 green,
never merged): frequency-lexicon re-ranking of `UITextChecker` output, a personal dictionary
with auto-correct protection, per-key touch-offset personalization, and dark flag-gated glide
typing. **The owner's on-device verdict (2026-07-16) is that typing is still "pretty awful" with
all of that active.** The incremental tweaks recommended as v1 are exhausted; what remains is
exactly what the research already scoped:

- `docs/plans/full-keyboard/research/2026-07-10-priority-dictionaries-and-key-accuracy.md`
  §3/§4 "Phase D": **keyboard-geometry-weighted edit-distance re-scoring** ("reasonable v1.5
  candidate") and **double-letter/adjacent-key confusion heuristics** ("low-effort, worth doing")
  — both explicitly deferred as follow-ons, never built. → Tasks 1–3.
- `docs/plans/full-keyboard/2026-07-05-oss-prediction-options.md` §"Test harness design": an
  **offline evaluation corpus + metrics** as the *pre-registered decision gate* before adopting
  any OSS engine ("Run the offline harness (A) first, cheaply, before writing any Swift").
  Never built. → Tasks 4–6.
- Same doc, candidates #2/#3: **SymSpell** (MIT — correction quality) and **AOSP
  dictionaries/bigrams** (Apache-2.0 code / CC BY 4.0 data — the only real *next-word*
  prediction option that fits memory). Both gated on the harness clearing the pre-registered
  thresholds. → Tasks 7–9.

Decision gates (pre-registered in the 2026-07-05 research — do not re-negotiate after seeing
results): engine adoption requires **+15pp absolute top-1** over the current stack (or equivalent
KSR gain), **≤15MB resident delta**, **≤16ms p95 per keystroke**, and **no GPL/AGPL code** ever.

**Base branch:** `feat/qwerty-glide-and-accuracy` (NOT master, NOT `feat/onboarding-2` — the
QWERTY code only exists on that branch). Legal note: glide stays dark (Cerence patent gate —
a written FTO opinion on the keyboard family is required, no re-check date; see
`2026-08-04-glide-legal-gate.md`); nothing in this plan touches glide.

**House rules that bite here** (from `CLAUDE.md` + memory):
- Always `pod install` before first build on a fresh checkout; open `NumPad.xcworkspace`.
- New files must be added to the pbxproj via the `xcodeproj` Ruby gem (see Task 1 Step 4 —
  reuse that exact pattern for every task).
- The Keyboard extension has a ~50–70MB Jetsam ceiling and **no analytics/Firebase** — never add
  telemetry, export, or sync paths for typing data (hard privacy constraint from
  `2026-07-05-rules-and-structure.md`).
- `@UserDefault` removes keys on nil writes; follow the existing `Constants` +
  `UserDefaults.group` pattern for any new key.

**Verify command** (fast path, used throughout; long runs: detach via `nohup … &` and tail):

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=QA-iPhone17' \
  -only-testing:NumPadTests 2>&1 | tail -30
```

---

## Task 0: Branch + green baseline

**Step 1:** Create the working branch off the real head of QWERTY work:

```bash
git checkout feat/qwerty-glide-and-accuracy
git pull origin feat/qwerty-glide-and-accuracy
git checkout -b feat/qwerty-typing-v2
pod install
```

**Step 2:** Run the unit suite (command above). Expected: **all green** (573 tests as of
2026-07-16). If `[CP] Check Pods Manifest.lock` fails, run `pod install` again — known
fresh-machine gotcha.

**Step 3:** No commit (nothing changed).

---

## Task 1: `QwertyKeyGeometry` — pure key-distance model

Foundation for Tasks 2–4: where letters physically sit, and how far apart two letters are.
Hardcoded standard-QWERTY unit grid (same approach as MaxHalford/clavier, the research's
implementation reference) — deliberately NOT derived from `QwertyLayout` at runtime, so the
module stays dependency-free and usable in the offline harness.

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyKeyGeometry.swift`
- Test: `NumPadTests/QwertyKeyGeometryTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import NumPad

final class QwertyKeyGeometryTests: XCTestCase {

    func testHorizontalNeighborsAreDistanceOne() {
        XCTAssertEqual(QwertyKeyGeometry.distance("q", "w"), 1.0, accuracy: 0.001)
        XCTAssertEqual(QwertyKeyGeometry.distance("k", "l"), 1.0, accuracy: 0.001)
    }

    func testDiagonalNeighborsAreCloserThanTwo() {
        // e (2,0) vs d (2.5,1) → sqrt(0.25 + 1) ≈ 1.118
        XCTAssertEqual(QwertyKeyGeometry.distance("e", "d")!, 1.118, accuracy: 0.01)
    }

    func testDistantKeys() {
        // q (0,0) vs p (9,0)
        XCTAssertEqual(QwertyKeyGeometry.distance("q", "p"), 9.0, accuracy: 0.001)
    }

    func testAdjacency() {
        XCTAssertTrue(QwertyKeyGeometry.areAdjacent("e", "r"))
        XCTAssertTrue(QwertyKeyGeometry.areAdjacent("e", "d"))   // diagonal counts
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("e", "t"))  // two apart
        XCTAssertFalse(QwertyKeyGeometry.areAdjacent("q", "m"))
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
```

**Step 2: Run it — verify FAIL** (build error: type doesn't exist).

**Step 3: Implement** `QwertyKeyGeometry.swift` — pure, Foundation-only:

```swift
import Foundation

/// Physical positions of letters on a standard QWERTY grid, in "key pitch" units
/// (1.0 = the horizontal distance between two neighboring keys). Row stagger matches
/// the rendered keyboard: home row +0.5, bottom row +1.5. Hardcoded on purpose —
/// see plan §Task 1 (clavier-style; keeps the module pure and harness-usable).
enum QwertyKeyGeometry {

    static let adjacencyThreshold = 1.2   // covers horizontal (1.0) + diagonal (~1.118)

    private static let unitCenters: [Character: (x: Double, y: Double)] = {
        var centers: [Character: (Double, Double)] = [:]
        let rows: [(letters: String, xOffset: Double, y: Double)] = [
            ("qwertyuiop", 0.0, 0.0),
            ("asdfghjkl", 0.5, 1.0),
            ("zxcvbnm", 1.5, 2.0),
        ]
        for row in rows {
            for (index, letter) in row.letters.enumerated() {
                centers[letter] = (row.xOffset + Double(index), row.y)
            }
        }
        return centers
    }()

    /// Euclidean distance in key-pitch units; nil when either character is not a letter key.
    static func distance(_ a: Character, _ b: Character) -> Double? {
        guard let ca = unitCenters[Character(a.lowercased())],
              let cb = unitCenters[Character(b.lowercased())] else { return nil }
        return ((ca.x - cb.x) * (ca.x - cb.x) + (ca.y - cb.y) * (ca.y - cb.y)).squareRoot()
    }

    static func areAdjacent(_ a: Character, _ b: Character) -> Bool {
        guard let d = distance(a, b) else { return false }
        return d > 0 && d <= adjacencyThreshold
    }
}
```

**Step 4: Add files to the Xcode project** (classic pbxproj — the gem; this is the reusable
pattern for every subsequent task):

```bash
gem list xcodeproj || sudo gem install xcodeproj
ruby - <<'RUBY'
require 'xcodeproj'
project = Xcodeproj::Project.open('NumPad.xcodeproj')
app   = project.targets.find { |t| t.name == 'NumPad' }
kb    = project.targets.find { |t| t.name == 'Keyboard' }
tests = project.targets.find { |t| t.name == 'NumPadTests' }
qwerty = project.main_group.find_subpath('NumPad/Libraries/Qwerty', false)
f = qwerty.new_file('QwertyKeyGeometry.swift')
[app, kb].each { |t| t.source_build_phase.add_file_reference(f) }
tg = project.main_group.find_subpath('NumPadTests', false)
tf = tg.new_file('QwertyKeyGeometryTests.swift')
tests.source_build_phase.add_file_reference(tf)
project.save
RUBY
```

**Step 5: Run tests — verify PASS.**

**Step 6: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyKeyGeometry.swift NumPadTests/QwertyKeyGeometryTests.swift NumPad.xcodeproj
git commit -m "feat: pure QWERTY key-geometry model (pitch distances, adjacency)"
```

---

## Task 2: `QwertySpatialScore` — geometry-weighted correction re-ranking

The research's "v1.5 candidate": a substitution between adjacent keys ("hrllo"→"hello", r≈e) is
far more likely than one between distant keys ("hrllo"→"hallo", r↛a), but `UITextChecker` ranks
by flat edit likelihood. This module scores typed→candidate pairs with a Damerau-Levenshtein
distance whose substitution cost scales with physical key distance, then re-orders guesses.
**Policy (mirrors the shipped `rerankKnown` philosophy): spatial score refines ordering among
the checker's own guesses; it never invents candidates and never overrides the checker's
misspelling verdict.** Because `QwertyAutocorrect.decide()` auto-replaces with `guesses.first`,
this directly improves which word auto-correct picks.

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertySpatialScore.swift`
- Test: `NumPadTests/QwertySpatialScoreTests.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift` (2 call sites, see Step 6)

**Step 1: Write the failing test**

```swift
import XCTest
@testable import NumPad

final class QwertySpatialScoreTests: XCTestCase {

    func testAdjacentSubstitutionCostsLessThanDistant() {
        let near = QwertySpatialScore.editCost(typed: "hrllo", candidate: "hello") // r→e adjacent
        let far  = QwertySpatialScore.editCost(typed: "hrllo", candidate: "hallo") // r→a distant
        XCTAssertLessThan(near, far)
    }

    func testTranspositionIsSingleFlatCost() {
        let cost = QwertySpatialScore.editCost(typed: "teh", candidate: "the")
        XCTAssertEqual(cost, QwertySpatialScore.transpositionCost, accuracy: 0.001)
    }

    func testInsertionAndDeletionAreFlatCost() {
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "helo", candidate: "hello"),
                       QwertySpatialScore.insertDeleteCost, accuracy: 0.001)
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "helllo", candidate: "hello"),
                       QwertySpatialScore.insertDeleteCost, accuracy: 0.001)
    }

    func testIdenticalWordsCostZero() {
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "hello", candidate: "hello"), 0)
    }

    func testRerankPrefersSpatiallyPlausibleGuess() {
        let out = QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hello"])
        XCTAssertEqual(out, ["hello", "hallo"])
    }

    func testRerankIsStableForEqualCosts() {
        // Two candidates the same distance away keep the checker's order.
        let out = QwertySpatialScore.rerank(word: "cst", guesses: ["cast", "cost"])
        XCTAssertEqual(out, ["cast", "cost"])
    }

    func testRerankToleratesNonLetterAndCaseInput() {
        XCTAssertEqual(QwertySpatialScore.rerank(word: "Hrllo", guesses: ["Hello"]), ["Hello"])
        XCTAssertEqual(QwertySpatialScore.rerank(word: "it's", guesses: ["its"]), ["its"])
        XCTAssertEqual(QwertySpatialScore.rerank(word: "", guesses: ["a"]), ["a"])
    }
}
```

**Step 2: Run — verify FAIL.**

**Step 3: Implement** `QwertySpatialScore.swift`. Contract:

- `static let insertDeleteCost = 1.0`, `transpositionCost = 0.9`, and substitution cost
  `= min(1.3, 0.4 + 0.3 × keyDistance)` — adjacent (distance ≤1.2) lands ≈0.7–0.76, distant keys
  approach the 1.3 cap, non-letter/unknown pairs use 1.0 (flat). Named `Tuning` statics.
- `static func editCost(typed:candidate:) -> Double` — classic Damerau-Levenshtein DP over
  lowercased characters (two-row + previous-row implementation, O(m×n)); substitution cost from
  the formula above via `QwertyKeyGeometry.distance`.
- `static func rerank(word:guesses:) -> [String]` — stable sort by
  `(editCost rounded to 3 decimals, incoming index)`; empty word or empty guesses → guesses
  unchanged. Costs are compared *rounded* so float noise can't break stability.
- Guard: words longer than 24 chars return guesses unchanged (skip the DP — same length cap the
  lexicon uses).

**Step 4: Run — verify PASS.** Add both files to pbxproj (gem pattern from Task 1 Step 4;
module → app+kb targets, test → NumPadTests).

**Step 5: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertySpatialScore.swift NumPadTests/QwertySpatialScoreTests.swift NumPad.xcodeproj
git commit -m "feat: geometry-weighted edit-distance scoring of correction guesses"
```

**Step 6: Wire into `QwertyPageHost`** — guesses flow through spatial re-rank FIRST, then the
existing frequency/personal steps (spatial fixes gross implausibility; frequency then refines
among the plausible):

- `applyPendingCorrection()` (~line 328): change
  `guesses: frequencyLexicon.rerankKnown(analysis.guesses)` to
  `guesses: frequencyLexicon.rerankKnown(QwertySpatialScore.rerank(word: word, guesses: analysis.guesses))`
- `refreshSuggestions()` (~line 520): same wrap inside the existing
  `rankCandidates(frequencyLexicon.rerankKnown(...))` chain.

**Step 7: Extend `NumPadTests/QwertyAutocorrectTests.swift`** with one integration-shaped case
proving the pipe order (pure, no host needed):

```swift
func testSpatialRerankFeedsDecide() {
    let guesses = QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hello"])
    let decision = QwertyAutocorrect.decide(word: "hrllo", isMisspelled: true,
                                            guesses: guesses, userRejected: [])
    XCTAssertEqual(decision, .replace(with: "hello"))
}
```

**Step 8: Run the FULL unit suite — verify green** (the existing autocorrect/host tests are the
regression net). **Commit**

```bash
git add Keyboard/Libraries/QwertyPageHost.swift NumPadTests/QwertyAutocorrectTests.swift
git commit -m "feat: spatially plausible corrections outrank distant ones in decide/suggestions"
```

---

## Task 3: `QwertyTypoVariants` — double-letter + adjacent-key variant repair

Second Phase-D follow-on. Two narrow, well-known failure modes `UITextChecker` handles poorly:
under/over-doubled letters ("acommodate", "helllo") and adjacent-key slips the guess list misses
entirely. Generate targeted variants of the misspelled word, keep only real words (validity
judged by the caller — the host passes a `UITextChecker`-backed closure, tests pass a fixture
set), and put the best variant at the head of the guess list. **Augments guesses; the misspelling
verdict itself is untouched.**

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyTypoVariants.swift`
- Test: `NumPadTests/QwertyTypoVariantsTests.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift` (same 2 call sites as Task 2)

**Step 1: Write the failing test**

```swift
import XCTest
@testable import NumPad

final class QwertyTypoVariantsTests: XCTestCase {

    private let dictionary: Set<String> = ["accommodate", "hello", "the", "about", "cat"]
    private func isReal(_ w: String) -> Bool { dictionary.contains(w) }

    func testMissingDoubledLetterIsRepaired() {
        // "acommodate" +c → "accommodate" is 2 doublings away; test the single step first:
        XCTAssertEqual(QwertyTypoVariants.repair(word: "accomodate", isRealWord: isReal),
                       "accommodate")
    }

    func testExtraTripledLetterIsCollapsed() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "helllo", isRealWord: isReal), "hello")
    }

    func testExtraDoubledLetterIsCollapsed() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "aabout", isRealWord: isReal), "about")
    }

    func testNoValidVariantReturnsNil() {
        XCTAssertNil(QwertyTypoVariants.repair(word: "xyzzy", isRealWord: isReal))
        XCTAssertNil(QwertyTypoVariants.repair(word: "teh", isRealWord: isReal)) // transposition ≠ doubling
    }

    func testRealWordReturnsNilFastPathIsCallerResponsibility() {
        // The module doesn't check "is the input already real" — decide() only runs it on
        // misspelled words. Document via behavior: it may still return a different real word.
        XCTAssertEqual(QwertyTypoVariants.repair(word: "helo", isRealWord: isReal), "hello")
    }

    func testAugmentPutsRepairFirstWithoutDuplicating() {
        let out = QwertyTypoVariants.augment(guesses: ["held", "hello"],
                                             word: "helllo", isRealWord: isReal)
        XCTAssertEqual(out, ["hello", "held"])   // promoted, not duplicated
        let out2 = QwertyTypoVariants.augment(guesses: ["held"],
                                              word: "helllo", isRealWord: isReal)
        XCTAssertEqual(out2, ["hello", "held"])  // inserted when absent
        let out3 = QwertyTypoVariants.augment(guesses: ["held"],
                                              word: "teh", isRealWord: isReal)
        XCTAssertEqual(out3, ["held"])           // no repair → unchanged
    }
}
```

**Step 2: Run — verify FAIL.**

**Step 3: Implement.** Contract:

- `static func repair(word:isRealWord:) -> String?` — lowercased input; generate, in order:
  (a) collapse each run of ≥2 identical letters by one (`helllo→hello`, `aabout→about`),
  (b) double each letter once (`accomodate→accommodate`), capped at words ≤24 chars and ≤48
  generated variants; return the FIRST variant that `isRealWord` accepts, preserving the typed
  word's case via the same leading-capital convention `QwertyAutocorrect.matchCase` uses
  (make `matchCase` internal-visible or replicate the 3-line helper — prefer exposing the
  existing one; it's already `private static` in `QwertyAutocorrect`, change to `static`).
- `static func augment(guesses:word:isRealWord:) -> [String]` — `repair` result moves to index 0
  (case-insensitive dedupe against existing guesses); nil repair → guesses unchanged.

**Step 4: Run — verify PASS.** Add to pbxproj (gem pattern).

**Step 5: Wire into `QwertyPageHost`** at both call sites, INSIDE the Task-2 wrap (variants
augment before spatial/frequency ordering):

```swift
let repaired = QwertyTypoVariants.augment(
    guesses: analysis.guesses, word: word,
    isRealWord: { spellChecker.analyze(word: $0).isMisspelled == false })
// then: frequencyLexicon.rerankKnown(QwertySpatialScore.rerank(word: word, guesses: repaired))
```

Note: `analyze(word:)` calls `UITextChecker` — the validity closure runs at most ~48 times per
misspelled boundary word, each a <1ms in-process check; acceptable at word-boundary cadence
(NOT per keystroke — confirm the call site only fires in `applyPendingCorrection` and
`refreshSuggestions`' misspelled branch).

**Step 6: Run FULL suite — verify green. Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyTypoVariants.swift NumPadTests/QwertyTypoVariantsTests.swift \
        Keyboard/Libraries/QwertyPageHost.swift NumPad.xcodeproj
git commit -m "feat: double-letter/adjacent-slip typo repair augments correction guesses"
```

---

## Task 4: Eval corpus — committed fixtures + loader + synthetic generator

The harness (Task 5) needs a reproducible `(typed, intended)` pair set. Two sources per the
research: real typos (GitHub Typo Corpus, English word-level extraction) and a seeded synthetic
generator (QWERTY-adjacency-weighted edits over a small sentence set) for volume.

**Files:**
- Create: `tools/data/eval/README.md` (provenance + licenses + regeneration commands)
- Create: `tools/data/eval/typos_en.tsv` (extracted real-typo pairs, target 3–5k lines)
- Create: `tools/data/eval/sentences_en.txt` (~300 short sentences)
- Create: `NumPad/Libraries/Qwerty/QwertyEvalCorpus.swift`
- Test: `NumPadTests/QwertyEvalCorpusTests.swift`

**Step 1: Fetch + extract the real-typo pairs.** GitHub Typo Corpus
(https://github.com/mhagiwara/github-typo-corpus — dataset released for research use; **verify
the license file at download time and record it in the README**; if its terms are unclear for
a commercial repo, fall back to synthetic-only and note that in the README — the harness design
does not depend on which source dominates):

```bash
mkdir -p tools/data/eval
# ~850MB full corpus — extract en word-level single-token edits only, then DELETE the download.
# jq filter: lang=="eng", single-word src/tgt, letters-only, length 2–24, src != tgt.
# Emit "typed<TAB>intended", dedupe, cap at 5000 lines → tools/data/eval/typos_en.tsv
```

Write the exact jq/python extraction inline in `tools/data/eval/README.md` so it's reproducible.
For `sentences_en.txt`: take ~300 short (4–10 word) English sentences from Tatoeba's CC-BY 2.0 FR
export (attribution line in README + Task 10 credits), lowercase, letters+spaces only.

**Step 2: Write the failing loader/generator test**

```swift
import XCTest
@testable import NumPad

final class QwertyEvalCorpusTests: XCTestCase {

    func testParsesTSVPairs() {
        let corpus = QwertyEvalCorpus(tsv: "teh\tthe\nrecieve\treceive\n\nbad line\n")
        XCTAssertEqual(corpus.pairs.count, 2)
        XCTAssertEqual(corpus.pairs.first?.typed, "teh")
        XCTAssertEqual(corpus.pairs.first?.intended, "the")
    }

    func testSyntheticGeneratorIsDeterministic() {
        let a = QwertyEvalCorpus.synthesizeTypos(words: ["hello", "world"], perWord: 3, seed: 42)
        let b = QwertyEvalCorpus.synthesizeTypos(words: ["hello", "world"], perWord: 3, seed: 42)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 6)
        XCTAssertTrue(a.allSatisfy { $0.typed != $0.intended })
    }

    func testSyntheticSubstitutionsPreferAdjacentKeys() {
        let pairs = QwertyEvalCorpus.synthesizeTypos(words: Array(repeating: "hello", count: 50)
            .enumerated().map { _, w in w }, perWord: 4, seed: 7)
        let substitutions = pairs.compactMap { pair -> (Character, Character)? in
            guard pair.typed.count == pair.intended.count else { return nil }
            let diff = zip(pair.typed, pair.intended).filter { $0 != $1 }
            return diff.count == 1 ? diff[0] : nil
        }
        let adjacent = substitutions.filter { QwertyKeyGeometry.areAdjacent($0.0, $0.1) }
        XCTAssertGreaterThan(Double(adjacent.count), 0.7 * Double(substitutions.count))
    }
}
```

**Step 3: Run — verify FAIL. Implement.** Contract:

- `struct QwertyEvalCorpus { struct Pair: Equatable { let typed, intended: String } ... }`
- `init(tsv: String)` — split lines, tab-split, drop malformed, lowercase.
- `init?(bundledResource name: String, bundle: Bundle)` — loads the TSV from test-bundle
  resources.
- `static func synthesizeTypos(words:perWord:seed:) -> [Pair]` — **seeded SplitMix64/LCG**
  (no `SystemRandomNumberGenerator` — determinism is the point; also `Date()`/`Math.random`-free
  by construction). Per word, one random edit: substitution (60%, target key chosen
  adjacency-weighted via `QwertyKeyGeometry`), transposition (15%), deletion (12.5%),
  insertion (12.5%, inserted char adjacent to a neighbor).

**Step 4: Add module+test to pbxproj (gem)**, and add `typos_en.tsv` + `sentences_en.txt` as
**NumPadTests resources** (`tests.resources_build_phase.add_file_reference(...)`).

**Step 5: Run — verify PASS. Commit**

```bash
git add tools/data/eval NumPad/Libraries/Qwerty/QwertyEvalCorpus.swift \
        NumPadTests/QwertyEvalCorpusTests.swift NumPad.xcodeproj
git commit -m "feat: eval corpus — real-typo fixtures + seeded adjacency-weighted generator"
```

---

## Task 5: `QwertyEvalHarness` — the measurement gate

An env-gated XCTest (runs on the iOS simulator so `UITextChecker` behaves exactly as in the
extension) that scores every arm over the same corpus and prints/writes a markdown report.
This is deliberately a test, not a tool binary: it reuses the exact modules the keyboard ships.

**Files:**
- Create: `NumPadTests/QwertyEvalHarnessTests.swift`

**Step 1: Write the harness** (no TDD red/green here — the harness IS the measurement
instrument; its "test" assertions only guard corpus loading):

```swift
import XCTest
@testable import NumPad

/// Offline typing-quality harness (research 2026-07-05 §Test harness A).
/// Skipped unless QWERTY_EVAL=1 — run explicitly:
///   xcodebuild test ... -only-testing:NumPadTests/QwertyEvalHarnessTests \
///     TEST_RUNNER_QWERTY_EVAL=1
final class QwertyEvalHarnessTests: XCTestCase {

    struct ArmResult { var top1 = 0; var top3 = 0; var total = 0; var p95LatencyMs = 0.0 }

    func testCorrectionArms() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["QWERTY_EVAL"] == "1")
        // Arms, each: (typed, intended) -> ranked candidates
        //  floor      — raw UITextChecker guesses
        //  shipped    — floor + frequency rerankKnown (current production path)
        //  spatial    — shipped + QwertySpatialScore.rerank (Task 2)
        //  variants   — spatial + QwertyTypoVariants.augment (Task 3)
        // Later arms (Tasks 7–8) append here: symspell, nextword-KSR.
        // For each arm over corpus (real TSV + 5k synthetic, seed 42):
        //   top-1 / top-3 accuracy, split by edit distance (1 vs 2) and adjacency;
        //   p50/p95 wall-clock per call (mach_absolute_time around the arm closure).
        // Emit: markdown table via print() AND write to
        //   FileManager.default.temporaryDirectory/"qwerty-eval-report.md"
        // Assert only: corpus non-empty, every arm ran the full corpus.
    }
}
```

Implementation notes for the executor:
- Build each arm as `(String) -> [String]` closures sharing ONE `UITextChecker` instance;
  replicate the extension's exact call shapes (`rangeOfMisspelledWord` + `guesses(forWordRange:)`
  — copy from `Keyboard/Libraries/QwertySpellChecker.swift`, which cannot be imported directly
  since it's Keyboard-target-only; a 15-line local mirror in the harness file is acceptable and
  should say so in a comment).
- Frequency lexicon: load the real bundled `qwerty_lexicon_en.bin` — add it to NumPadTests
  resources too (gem, resources phase) so the harness measures production ranking.
- Latency: report per-arm added latency vs floor; the ≤16ms p95 gate applies to the DELTA.
- Completions/KSR arm: hold out the final word of each `sentences_en.txt` sentence, feed the
  first 1–N prefix chars, count hits@1/@3 and keystrokes saved — this is the baseline the Task-8
  next-word arm must beat.

**Step 2: Add to pbxproj (gem) + run skipped-path** (normal suite run — verify the new test
SKIPS, suite stays green).

**Step 3: Run the harness for real:**

```bash
nohup xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=QA-iPhone17' \
  -only-testing:NumPadTests/QwertyEvalHarnessTests \
  TEST_RUNNER_QWERTY_EVAL=1 > /tmp/qwerty-eval.log 2>&1 &
# tail -f /tmp/qwerty-eval.log ; report lands in the sim container's tmp — grep the log for
# "qwerty-eval-report.md" path printed by the harness.
```

**Step 4: Commit**

```bash
git add NumPadTests/QwertyEvalHarnessTests.swift NumPad.xcodeproj
git commit -m "feat: offline typing-quality harness (floor/shipped/spatial/variants arms)"
```

---

## Task 6: Baseline report + DECISION CHECKPOINT

**Step 1:** Copy the harness report into
`docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md`, annotated with: corpus sizes,
arm definitions, and the three pre-registered gates restated up top.

**Step 2:** Interpret against the gates (from `2026-07-05-oss-prediction-options.md` §C —
**pre-registered, do not adjust after seeing numbers**):

- If **spatial+variants** (Tasks 2–3) already moved top-1 meaningfully: ship them regardless
  (they're free — no memory, no latency); note the gain.
- **Proceed to Tasks 7–9 ONLY IF** the report shows the floor/shipped arms leaving ≥15pp top-1
  (or equivalent KSR) on the table that a dictionary-based arm could plausibly close — i.e.,
  intended words that ARE in the 50k lexicon but the checker never surfaced. The report must
  include this "reachable headroom" number (intended-word-in-lexicon-but-missed rate).
- If headroom < 15pp: STOP after Task 6, commit the report, and surface to the owner that the
  research's own gate says engine work isn't worth it — the remaining lever would be the touch
  model (covariance/hit-region, explicitly not recommended without device evidence) or product-
  level changes (key sizes, layout), which are out of this plan's scope.

**Step 3: Commit**

```bash
git add docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md
git commit -m "docs: typing-quality eval baseline + gate verdict"
```

---

## Task 7 (GATED on Task 6): `QwertySymSpellCorrector` — symmetric-delete correction arm

SymSpell algorithm (MIT — algorithm reimplemented in pure Swift over OUR lexicon; no code
vendored) as a harness arm first. It generates candidates `UITextChecker` misses and scores
them by (edit distance, frequency rank, spatial cost).

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertySymSpellCorrector.swift`
- Test: `NumPadTests/QwertySymSpellCorrectorTests.swift`
- Modify: `NumPadTests/QwertyEvalHarnessTests.swift` (new arm)

**Step 1: Failing tests** — fixture lexicon (~20 words via
`QwertyFrequencyLexicon.encode(rankedWords:)`):
lookup finds edit-distance-1 and -2 corrections; ranking = distance first, then frequency rank,
then `QwertySpatialScore.editCost` as tiebreak; unknown garbage → `[]`; index build over the
fixture is deterministic.

**Step 2–3: Implement.** Contract:

- `init(lexicon: QwertyFrequencyLexicon, maxEditDistance: Int = 2, prefixLength: Int = 7)` —
  builds the delete-variant index (`[String: [Int]]` mapping deleted-prefix-forms → lexicon
  ranks) **lazily on first lookup, off the main thread** in extension use; measure build time
  and index size in the harness (research expectation: low-single-digit MB, sub-second — if it
  breaches ~10MB resident, precompute offline into a second `.bin` via
  `tools/make_qwerty_lexicon.swift` extension — decide from measurements, not up front).
- `func corrections(for word: String, max: Int = 5) -> [String]`.

**Step 4: Add the harness arm; re-run the harness** (Task 5 Step 3 command). The arm must clear
the +15pp gate **and** the ≤16ms p95 delta gate on corpus before any extension wiring.

**Step 5: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertySymSpellCorrector.swift \
        NumPadTests/QwertySymSpellCorrectorTests.swift NumPadTests/QwertyEvalHarnessTests.swift NumPad.xcodeproj
git commit -m "feat: SymSpell-class corrector over the bundled lexicon (harness arm)"
```

---

## Task 8 (GATED on Task 6): AOSP bigram next-word arm

The only researched option that adds genuine *next-word* prediction (empty-input suggestions
after a boundary — a capability the keyboard currently lacks entirely).

**Files:**
- Create: `tools/make_qwerty_bigrams.swift` + `tools/data/README` update
- Create: `Keyboard/Resources/qwerty_bigrams_en.bin`
- Create: `NumPad/Libraries/Qwerty/QwertyNextWordPredictor.swift`
- Test: `NumPadTests/QwertyNextWordPredictorTests.swift`
- Modify: `NumPadTests/QwertyEvalHarnessTests.swift` (KSR arm)

**Step 1: Offline pipeline.** Download Helium314 `aosp-dictionaries` English wordlist
(`.combined` text format — **CC BY 4.0, verify the repo's license/README at download and add the
attribution line in Task 10**). `tools/make_qwerty_bigrams.swift` parses `bigram=` entries,
keeps top-8 continuations per head word **restricted to words present in our 50k lexicon**,
packs: `"NPBG" | version | count | offsets | records(head-rank UInt16, [cont-rank UInt16 × n])`
— referencing lexicon RANKS not strings keeps it small (target ≤1.5MB; measure and record).

**Step 2: Failing tests** — fixture-encoded bigram data: `predictions(after: "the") -> [String]`
returns continuations in stored order; unknown head → `[]`; corrupt data → empty predictor
(same boundary-validation discipline as `QwertyFrequencyLexicon`).

**Step 3: Implement** `QwertyNextWordPredictor` (pure; `init(data:lexicon:)`, binary-search on
head rank). Add harness KSR arm: after each held-out sentence prefix boundary, does the intended
next word appear @1/@3; compare against the Task-5 completion baseline.

**Step 4: Re-run harness; gates:** KSR gain per the +15pp-equivalent gate, resident delta ≤15MB
(will be far under), added latency ≤16ms p95.

**Step 5: Commit**

```bash
git add tools/make_qwerty_bigrams.swift tools/data Keyboard/Resources/qwerty_bigrams_en.bin \
        NumPad/Libraries/Qwerty/QwertyNextWordPredictor.swift \
        NumPadTests/QwertyNextWordPredictorTests.swift NumPadTests/QwertyEvalHarnessTests.swift NumPad.xcodeproj
git commit -m "feat: AOSP-derived bigram next-word predictor + packed data pipeline (harness arm)"
```

---

## Task 9 (GATED on Tasks 7–8 clearing their gates): flag-gated extension wiring

Follow the exact dark-flag pattern of glide (Task 5 of the 2026-07-12 plan): two Bool flag pairs
(NOT an enum switcher — Bool rows are the established `FeatureFlags` UI pattern and the two
features are independent):

**Files:**
- Modify: `NumPad/Libraries/SharedExtensions.swift` — `Constants.ffQwertySymSpell` /
  `qwertySymSpellRemoteEnabled` + `Constants.ffQwertyNextWord` / `qwertyNextWordRemoteEnabled`;
  `FeatureFlags` stored flags via `effective()` (forces OFF in App Store builds), remote mirrors
  defaulting `true`, pure combinators + Beta rows in `FeatureFlags.all`.
- Modify: `RemoteConfigManager.configureDefaults()` — `qwerty_symspell_enabled`,
  `qwerty_nextword_enabled` defaults + mirror steps (copy the glide pair exactly).
- Test: extend `NumPadTests/QwertyGatingTests.swift` — both combinator truth tables.
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`:
  - SymSpell ON: merge `symSpell.corrections(for: word)` into the guess stream AFTER
    `analysis.guesses`, before the Task-3 augment (dedupe case-insensitively) — checker guesses
    keep priority; SymSpell fills gaps.
  - NextWord ON: in `refreshSuggestions()`, when `currentWord` is nil (just after a boundary)
    and the predictor has candidates for the previous word, show
    `[.candidate(p1), .candidate(p2), .candidate(p3)]` instead of clearing the bar; chip tap
    inserts word + space via the existing insertion path; feeds the personal dictionary like
    any typed word. No prediction when the previous word isn't in the lexicon.
- Modify: `NumPad/Controllers/QwertySetupViewController.swift` — nothing (personalization reset
  already covers new state? — the predictor is static data, no per-user state: confirm nothing
  to reset).

TDD the combinators; wire; run FULL suite green. Manual sim pass (flags ON, DEBUG): corrections
appear for checker-missed typos; next-word chips appear after space; flag OFF = byte-for-byte
current behavior.

**Commit**

```bash
git commit -am "feat: symspell + next-word arms wired dark behind flag pairs (local OFF + RC kill)"
```

---

## Task 10: Full verification + docs + memory

1. FULL unit suite green (detached run, tail log).
2. Release build both targets:
   `xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` (detached).
3. `QwertyTypeSmokeTests` E2E on QA-iPhone17 (all new flags dark — proves zero regression):
   `-only-testing:NumPadUITests/QwertyTypeSmokeTests`.
4. Attribution sweep in `NumPad/Settings.bundle/Root.plist` (Hermit Dave line already exists —
   do NOT drop it): add AOSP-dictionaries CC BY 4.0 line (if Task 8 ran) + eval-corpus credits
   in `tools/data/eval/README.md` only (fixtures aren't shipped in the app binary — no
   user-facing credit needed unless a corpus license demands it; re-check at Task 4).
5. Memory-ceiling spot check (if Tasks 7–8 wired): DEBUG build on device, type on the QWERTY
   page with flags ON, confirm no Jetsam (memory notes: `builtByDeveloper` distinguishes dev
   builds; version strings do NOT).
6. `graphify update .`; update `~/.claude/.../memory/full-keyboard-implementation.md` (branch
   state, harness results, gate verdicts); push branch.

**Definition of done:** Tasks 1–3 active unconditionally on the QWERTY page (they're
re-rankers — no flag needed, mirroring how Phases A–C shipped); harness + baseline report
committed with an explicit gate verdict; Tasks 7–9 either cleared their gates and are wired
dark, or were explicitly skipped with the verdict recorded; suite green; flag-off E2E proven;
no new Full Access requirement; no GPL/AGPL code anywhere.
