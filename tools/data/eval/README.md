# Eval corpus fixtures

Committed `(typed, intended)` fixtures for the offline QWERTY typing-eval harness.
Loaded in tests by `QwertyEvalCorpus` (`NumPad/Libraries/Qwerty/QwertyEvalCorpus.swift`,
app target only) via the **NumPadTests resources phase**. These files are test
fixtures — they must never be added to the app or Keyboard extension bundles.

| File | Lines | Contents | Error model |
|------|-------|----------|-------------|
| `sentences_en.txt` | 313 | Short everyday English sentences, 5–9 words, lowercase, letters+spaces only | — |
| `typos_en.tsv` | 4539 | `typed<TAB>intended` single-edit typo pairs, lowercase, deduped, sorted | **Synthetic, adjacency-model** (motor slips) |
| `typos_wiki_en.tsv` | 4266 | `typed<TAB>intended` real human misspellings, lowercase, deduped, sorted | **Human cognitive/phonetic** errors |

**Corpus bias — read before interpreting eval numbers.** The synthetic corpus's
noise model (85% QWERTY-adjacent substitutions) is exactly the prior the spatial
re-ranking arm rewards, so metrics measured on `typos_en.tsv` alone are **biased
in favor of spatial scoring** — it is a corpus of fat-finger motor slips by
construction. `typos_wiki_en.tsv` is the counterweight: real human misspellings
harvested by Wikipedia editors, dominated by cognitive/phonetic errors
("recieve", "seperate", "volonteered") that adjacency priors do NOT explain.
**The harness must report metrics split per corpus, never pooled.**

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

### `typos_wiki_en.tsv` — Wikipedia common misspellings, CC BY-SA 4.0

- **Source page:** English Wikipedia, "Wikipedia:Lists of common misspellings/For machines"
  (`https://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines`).
- **Retrieved:** 2026-07-21, via `?action=raw` (see extraction commands below). The raw
  wikitext is documentation prose followed by a `==The Machine-Readable List==` marker;
  list lines follow as ` misspelling->correction` (leading space = wiki preformat), with
  comma-separated alternate corrections on some lines.
- **License: CC BY-SA 4.0** (Wikipedia text; some content also GFDL-dual-licensed).
  Attribution: contributors to "Wikipedia:Lists of common misspellings/For machines",
  English Wikipedia. Per the rule already applied in this repo, a share-alike license is
  acceptable for a **committed test fixture** — this file is loaded only by the
  NumPadTests bundle and **must never be added to the app or Keyboard extension
  bundles** (shipping it in a binary would drag the app's distribution terms into
  share-alike scope).
- **Extraction rules:** parse only after the list marker; take the FIRST comma-separated
  correction; both sides lowercased and required to match `^[a-z']+$` (drops multi-word
  rewrites like "abouta -> about a"), lengths 2–24, `typed != intended`; dedupe; sort.
  4266 pairs survive (no cap applied — the source list is ~4.3k entries).

## Regeneration

### `typos_wiki_en.tsv`

Save the python script below as `/tmp/extract_wiki_typos.py`, then from the repo root:

```bash
curl -sL "https://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines?action=raw" \
    -o /tmp/wiki_misspellings_raw.txt
python3 /tmp/extract_wiki_typos.py /tmp/wiki_misspellings_raw.txt tools/data/eval/typos_wiki_en.tsv
```

```python
#!/usr/bin/env python3
"""Extract typed<TAB>intended pairs from Wikipedia's machine-readable
misspelling list (Wikipedia:Lists of common misspellings/For machines).

Usage: extract_wiki_typos.py <raw_wikitext.txt> <output.tsv>

The page is documentation prose followed by a '==The Machine-Readable List=='
marker; list lines follow as ' misspelling->correction' (leading space = wiki
preformat; corrections may be comma-separated alternates — first one wins).
"""
import re
import sys

LIST_MARKER = "==The Machine-Readable List=="
WORD = re.compile(r"^[a-z']+$")
MIN_LEN, MAX_LEN = 2, 24


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <raw_wikitext.txt> <output.tsv>")

    with open(sys.argv[1], encoding="utf-8") as handle:
        text = handle.read()
    if LIST_MARKER not in text:
        sys.exit(f"marker {LIST_MARKER!r} not found — page format changed?")

    pairs = set()
    for line in text.split(LIST_MARKER, 1)[1].splitlines():
        if "->" not in line:
            continue
        typed, corrections = line.strip().split("->", 1)
        typed = typed.strip().lower()
        intended = corrections.split(",", 1)[0].strip().lower()
        if not (WORD.fullmatch(typed) and WORD.fullmatch(intended)):
            continue  # drops multi-word rewrites ('about a'), digits, junk
        if not (MIN_LEN <= len(typed) <= MAX_LEN and MIN_LEN <= len(intended) <= MAX_LEN):
            continue
        if typed == intended:
            continue
        pairs.add((typed, intended))

    lines = sorted(f"{typed}\t{intended}" for typed, intended in pairs)
    with open(sys.argv[2], "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} pairs")


if __name__ == "__main__":
    main()
```

Note: unlike the synthetic fixture, regeneration is only byte-identical against the
same page revision — the wiki page is live. The committed TSV is the fixture of
record; regenerate deliberately, not casually.

### `typos_en.tsv`

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
