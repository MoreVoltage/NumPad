# Eval corpus fixtures

Committed `(typed, intended)` fixtures for the offline QWERTY typing-eval harness.
Loaded in tests by `QwertyEvalCorpus` (`NumPad/Libraries/Qwerty/QwertyEvalCorpus.swift`,
app target only) via the **NumPadTests resources phase**. These files are test
fixtures — they must never be added to the app or Keyboard extension bundles.

| File | Lines | Contents |
|------|-------|----------|
| `sentences_en.txt` | 313 | Short everyday English sentences, 5–9 words, lowercase, letters+spaces only |
| `typos_en.tsv` | 4539 | `typed<TAB>intended` single-edit typo pairs, lowercase, deduped, sorted |

## Provenance & licenses

### `sentences_en.txt` — original, public domain

Hand-written for this repository (original text, no external source), so there is
no license or attribution requirement. Constraints: 4–10 words per sentence,
`[a-z ]` only (no punctuation/apostrophes — "do not", never "don't"), common
vocabulary throughout — the harness holds out the final word and checks whether
engines predict it, so rare final words would only measure lexicon gaps.

The Tatoeba CC-BY 2.0 FR export (the plan's preferred source) was skipped: the
export is a large tarball, and hand-curation gives tighter control over
vocabulary commonness with zero license overhead.

### `typos_en.tsv` — synthetic (fallback decision)

**The GitHub Typo Corpus (https://github.com/mhagiwara/github-typo-corpus) was
evaluated and REJECTED on license grounds** (checked 2026-07-21):

- The repository has **no LICENSE file** (`GET /repos/mhagiwara/github-typo-corpus/license`
  returns 404; repo root contains only `README.md`, `overview.png`, `src/`, `.github/`).
- Its README "Terms" section states: *"The copyright and license terms of the
  individual commits and texts contained in the dataset follow the terms of the
  repositories they belong to."* — i.e. every pair inherits the license of
  whatever GitHub repository it was scraped from. That is heterogeneous and
  unverifiable per pair (GPL, proprietary, or unlicensed text may be included).

Per the task's decision rule ("unclear/restrictive or no license found → do not
use"), the fixture falls back to **synthetic-only**: pairs are fabricated from
`sentences_en.txt`'s vocabulary by the app's own seeded, QWERTY-adjacency-weighted
generator (`QwertyEvalCorpus.synthesizeTypos`). Since the generator and the eval
harness share `QwertyKeyGeometry`, the synthetic slips match the physical model
the eval measures. The harness design does not depend on which source dominates.

Generation parameters (pinned in the script below): unique words of
`sentences_en.txt` sorted alphabetically (805 words), 6 variants per word,
seed `20260721`, deduped, sorted, capped at 5000 lines (cap not reached — 4539
survive dedup, so no truncation bias).

## Regeneration

`typos_en.tsv` is fully reproducible. Save the script below as
`/tmp/make_eval_typos.swift`, then from the repo root:

```bash
swiftc -O -o /tmp/mktypos /tmp/make_eval_typos.swift \
    NumPad/Libraries/Qwerty/QwertyKeyGeometry.swift \
    NumPad/Libraries/Qwerty/QwertyEvalCorpus.swift
/tmp/mktypos tools/data/eval/sentences_en.txt tools/data/eval/typos_en.tsv
```

```swift
//
//  make_eval_typos.swift  (committed only as this fenced block)
//
//  Regenerates tools/data/eval/typos_en.tsv from the sentence fixture using the
//  app's own seeded generator, so fixture and generator can never drift apart.
//

import Foundation

@main
struct MakeEvalTypos {

    /// Pinned generation parameters — change these and you change the fixture.
    private static let variantsPerWord = 6
    private static let seed: UInt64 = 20260721
    private static let maxLines = 5000

    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(Data(
                "usage: \(arguments.first ?? "mktypos") <sentences.txt> <output.tsv>\n".utf8))
            exit(1)
        }

        let sentences: String
        do {
            sentences = try String(contentsOfFile: arguments[1], encoding: .utf8)
        } catch {
            FileHandle.standardError.write(Data("cannot read \(arguments[1]): \(error)\n".utf8))
            exit(1)
        }

        // Unique words, sorted — the input order feeds the PRNG stream, so it
        // must be deterministic for regeneration to be byte-identical.
        let words = Set(sentences.split(separator: "\n")
            .flatMap { $0.split(separator: " ") }
            .map(String.init))
            .sorted()

        let pairs = QwertyEvalCorpus.synthesizeTypos(
            words: words, perWord: variantsPerWord, seed: seed)

        var seen = Set<String>()
        var lines: [String] = []
        for pair in pairs {
            let line = "\(pair.typed)\t\(pair.intended)"
            if seen.insert(line).inserted { lines.append(line) }
        }
        lines.sort()
        let capped = Array(lines.prefix(maxLines))

        do {
            try (capped.joined(separator: "\n") + "\n")
                .write(toFile: arguments[2], atomically: true, encoding: .utf8)
        } catch {
            FileHandle.standardError.write(Data("cannot write \(arguments[2]): \(error)\n".utf8))
            exit(1)
        }
        print("wrote \(capped.count) pairs from \(words.count) words")
    }
}
```

Regeneration is byte-identical for a given `(sentences, perWord, seed)` triple:
the generator draws every choice from a local SplitMix64 through plain modulo
arithmetic — no Swift-stdlib sampling algorithms, no system RNG.
